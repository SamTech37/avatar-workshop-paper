#!/bin/bash
set -e

# Benchmarking script for text-to-animation pipeline
# This script runs multiple iterations for statistical analysis

# ===CONFIGURATION===

# Number of iterations for 95% confidence interval
NUM_ITERATIONS=10

# Default text prompt
DEFAULT_PROMPT="A person is breakdancing"
text_prompt="${1:-$DEFAULT_PROMPT}"

# Directories
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
anim_script="$script_dir/run_text_to_anim.sh"
log_dir="$script_dir/log"
benchmark_dir="$script_dir/benchmark"

# Create benchmark directory
mkdir -p "$benchmark_dir"

# Benchmark session info
benchmark_timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
benchmark_log="$benchmark_dir/benchmark_${benchmark_timestamp}.log"
timing_data_file="$benchmark_dir/timing_data_${benchmark_timestamp}.csv"

# ===HELPER FUNCTIONS===

log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message"
    echo "$message" >> "$benchmark_log"
}

error() {
    local message="[ERROR] $1"
    echo "$message" >&2
    echo "$message" >> "$benchmark_log"
    exit 1
}

# ===VALIDATION===

# Check if animation script exists
[ -f "$anim_script" ] || error "Animation script not found: $anim_script"

# ===BENCHMARKING===

log "Starting benchmarking session"
log "Text prompt: $text_prompt"
log "Number of iterations: $NUM_ITERATIONS"
log "Animation script: $anim_script"
log "Results will be saved to: $timing_data_file"

# Create CSV header
echo "Iteration,Total_Time_s,Stage1_Time_s,Stage2_Time_s,Stage3_Time_s,Stage4_Time_s,Timestamp,Status" > "$timing_data_file"

benchmark_start=$(date +%s)

# Run iterations
for i in $(seq 1 $NUM_ITERATIONS); do
    log "Starting iteration $i/$NUM_ITERATIONS"
    iteration_start=$(date +%s)
    
    # Run the animation script and capture its log file
    if bash "$anim_script" "$text_prompt"; then
        # Find the most recent log file (should be the one we just created)
        latest_log=$(ls -1t "$log_dir"/*.log | head -n1)
        
        if [ -f "$latest_log" ]; then
            # Extract timing data from the log file
            total_time=$(grep "TIMING_DATA: Total=" "$latest_log" | sed 's/.*Total=\([0-9]*\)s/\1/' || echo "0")
            stage1_time=$(grep "TIMING_DATA: Stage1=" "$latest_log" | sed 's/.*Stage1=\([0-9]*\)s/\1/' || echo "0")
            stage2_time=$(grep "TIMING_DATA: Stage2=" "$latest_log" | sed 's/.*Stage2=\([0-9]*\)s/\1/' || echo "0")
            stage3_time=$(grep "TIMING_DATA: Stage3=" "$latest_log" | sed 's/.*Stage3=\([0-9]*\)s/\1/' || echo "0")
            stage4_time=$(grep "TIMING_DATA: Stage4=" "$latest_log" | sed 's/.*Stage4=\([0-9]*\)s/\1/' || echo "0")
            
            iteration_end=$(date +%s)
            iteration_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            
            # Save to CSV
            echo "$i,$total_time,$stage1_time,$stage2_time,$stage3_time,$stage4_time,$iteration_timestamp,SUCCESS" >> "$timing_data_file"
            
            log "Iteration $i completed successfully - Total: ${total_time}s, Stage1: ${stage1_time}s, Stage2: ${stage2_time}s, Stage3: ${stage3_time}s, Stage4: ${stage4_time}s"
        else
            log "Warning: Could not find log file for iteration $i"
        echo "$i,0,0,0,0,0,$(date '+%Y-%m-%d %H:%M:%S'),LOG_NOT_FOUND" >> "$timing_data_file"
        fi
    else
        log "Iteration $i failed"
        echo "$i,0,0,0,0,0,$(date '+%Y-%m-%d %H:%M:%S'),FAILED" >> "$timing_data_file"
    fi
    
    # Small delay between iterations
    sleep 2
done

benchmark_end=$(date +%s)
total_benchmark_time=$((benchmark_end - benchmark_start))

log "Benchmarking completed!"
log "Total benchmark time: ${total_benchmark_time}s"
log "Results saved to: $timing_data_file"

echo ""
echo "🎉 Benchmark complete!"
echo "📊 Timing data saved to: $timing_data_file"
echo "📋 Benchmark log: $benchmark_log"
echo ""
echo "📈 To analyze results, open benchmark_analysis.ipynb and run the cells"
echo "💡 The notebook will automatically load data from: $timing_data_file"