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
default_prompt="A person is breakdancing"
text_prompt="${1:-$default_prompt}"

total_stages=3

# Directories (relative to script location)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
main_dir="$script_dir"
result_dir="$script_dir/output"
mdm_dir="$script_dir/../motion-diffusion-model"
hugs_dir="$script_dir/../ml-hugs"
log_dir="$script_dir/log"

# Logging setup
timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
log_file="$log_dir/${timestamp}-log.log"
mkdir -p "$log_dir"

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
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message"
    echo "$message" >> "$log_file"
}

error() {
    local message="[ERROR] $1"
    echo "$message" >&2
    echo "$message" >> "$log_file"
    exit 1
}

# Benchmarking functions
start_timer() {
    timer_start=$(date +%s)
}

end_timer() {
    timer_end=$(date +%s)
    elapsed=$((timer_end - timer_start))
    local message="⏱️  Stage completed in ${elapsed}s ($(date -u -d @${elapsed} +%H:%M:%S))"
    echo "$message"
    echo "$message" >> "$log_file"
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
stage1_start=$(date +%s)
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
stage1_end=$(date +%s)
stage1_elapsed=$((stage1_end - stage1_start))
end_timer

# Step 2: Convert motion format
start_timer
stage2_start=$(date +%s)
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
stage2_end=$(date +%s)
stage2_elapsed=$((stage2_end - stage2_start))
end_timer

# Step 3: Run HUGS animation
start_timer
stage3_start=$(date +%s)
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

stage3_end=$(date +%s)
stage3_elapsed=$((stage3_end - stage3_start))
end_timer

pipeline_end=$(date +%s)
total_elapsed=$((pipeline_end - pipeline_start))

log "Pipeline complete!"
log "Results saved in: ${result_dir} and ${result_dir}_video"
total_time_message="🏁 Total pipeline time: ${total_elapsed}s ($(date -u -d @${total_elapsed} +%H:%M:%S))"
echo "$total_time_message"
echo "$total_time_message" >> "$log_file"

# Save timing data for benchmarking
echo "TIMING_DATA: Total=${total_elapsed}s" >> "$log_file"
echo "TIMING_DATA: Stage1=${stage1_elapsed}s" >> "$log_file"
echo "TIMING_DATA: Stage2=${stage2_elapsed}s" >> "$log_file"
echo "TIMING_DATA: Stage3=${stage3_elapsed}s" >> "$log_file"