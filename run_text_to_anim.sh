#!/bin/bash
set -e

# Usage: ./run_text_to_anim.sh ["text prompt"]
# Examples:
#   ./run_text_to_anim.sh
#   ./run_text_to_anim.sh "A person is walking"

# ===CONFIGURATION===

# GPU selection
export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0}

# Command line arguments with defaults
text_prompt="${1:-A person is doing cartwheels}"

total_stages=3

# Directories (relative to script location)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
main_dir="$script_dir"
result_dir="$script_dir/output"
mdm_dir="$script_dir/../motion-diffusion-model"
hugs_dir="$script_dir/../ml-hugs"

# Model configuration
motion_model_name="humanml_enc_512_50steps"
motion_model_dir="$mdm_dir/save/$motion_model_name"

avatar_name="lab-2025-07-16_08-01-21"
avatar_model_dir="$hugs_dir/avatars/$avatar_name"
avatar_output_file="anim_neuman_ours_final.mp4"

motion_length="9.8"

# Conda environments
mdm_env="mdm"
hugs_env="hugs"

# ===HELPER FUNCTIONS===

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Benchmarking functions
start_timer() {
    timer_start=$(date +%s)
}

end_timer() {
    timer_end=$(date +%s)
    elapsed=$((timer_end - timer_start))
    echo "⏱️  Stage completed in ${elapsed}s ($(date -u -d @${elapsed} +%H:%M:%S))"
}

# ===VALIDATION===

# Validate directories exist
[ -d "$mdm_dir" ] || error "Motion diffusion model directory not found: $mdm_dir"
[ -d "$hugs_dir" ] || error "HUGS directory not found: $hugs_dir"
[ -d "$motion_model_dir" ] || error "Motion model directory not found: $motion_model_dir"
[ -d "$avatar_model_dir" ] || error "Avatar directory not found: $avatar_model_dir"

# ===MAIN PIPELINE===
# Track total pipeline time
pipeline_start=$(date +%s)

log "Starting text-to-animation pipeline"
log "Text prompt: $text_prompt"
log "Avatar: $avatar_name"
log "Motion length: ${motion_length}s"
log "GPU: $CUDA_VISIBLE_DEVICES"

# Create output directory
mkdir -p "$result_dir"

# Copy required scripts
log "Copying scripts"
cp "$script_dir/scripts/pick_sample.py" "$mdm_dir/visualize/pick_sample.py" || error "Failed to copy pick_sample.py"
cp "$script_dir/scripts/hugs_animate.py" "$hugs_dir/scripts/hugs_animate.py" || error "Failed to copy hugs_animate.py"

# Step 1: Generate SMPL motion
start_timer
log "Step 1/$total_stages: Generating SMPL motion"
cd "$mdm_dir"

# Find the latest model file
motion_model_file="$(ls -1v "$motion_model_dir"/model*.pt 2>/dev/null | tail -n1)"
[ -f "$motion_model_file" ] || error "No model file found in $motion_model_dir"
log "Using model: $motion_model_file"

# Generate motion
log "Running motion generation..."
conda run -n "$mdm_env" python -m sample.generate \
    --model_path "$motion_model_file" \
    --output_dir "$result_dir" \
    --text_prompt "$text_prompt" \
    --num_samples 1 \
    --num_repetitions 1 \
    --motion_length "$motion_length" || error "Motion generation failed"

# Extract sample
log "Extracting motion sample..."
conda run -n "$mdm_env" python -m visualize.pick_sample \
    --npy_path "$result_dir/results.npy" \
    --sample_id 0 \
    --rep_id 0 \
    --output_dir "$result_dir" || error "Sample extraction failed"

log "SMPL motion generation complete"
end_timer

# Step 2: Convert motion format
start_timer
log "Step 2/$total_stages: Converting motion format for HUGS"
cd "$main_dir"

smpl_npy="$result_dir/smpl_params.npy"
[ -f "$smpl_npy" ] || error "SMPL parameters file not found: $smpl_npy"

conda run -n "$hugs_env" python "$script_dir/scripts/inspect_smpl.py" "$smpl_npy" || error "Motion conversion failed"

# Find and copy the generated npz file
npz_file="$(ls -1v "$result_dir"/*.npz 2>/dev/null | tail -n1)"
[ -f "$npz_file" ] || error "No NPZ file found in $result_dir"
log "Using NPZ file: $npz_file"

cp "$npz_file" "$hugs_dir/smpl_params.npz" || error "Failed to copy NPZ file"
end_timer

# Step 3: Run HUGS animation
start_timer
log "Step 3/$total_stages: Running HUGS animation (this may take a while)"
cd "$hugs_dir"

conda run -n "$hugs_env" python scripts/hugs_animate.py \
    -o "$avatar_model_dir" || error "HUGS animation failed"

# Copy final output with sanitized filename
output_video="$avatar_model_dir/$avatar_output_file"
if [ -f "$output_video" ]; then
    # Sanitize text prompt for filename (replace spaces with underscores, remove special chars)
    sanitized_prompt=$(echo "$text_prompt" | sed 's/[^a-zA-Z0-9 ]//g' | tr ' ' '_')
    final_output="${result_dir}_video/${sanitized_prompt}.mp4"

    mkdir -p "$(dirname "$final_output")"

    cp "$output_video" "$final_output"
    log "Animation complete! Final video: $final_output"
else
    log "Animation completed but output video not found at expected location: $output_video"
fi

end_timer

pipeline_end=$(date +%s)
total_elapsed=$((pipeline_end - pipeline_start))

log "Pipeline complete!"
log "Results saved in: $result_dir"
echo "🏁 Total pipeline time: ${total_elapsed}s ($(date -u -d @${total_elapsed} +%H:%M:%S))"