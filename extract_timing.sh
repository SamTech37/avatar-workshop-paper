#!/bin/bash

# Extract timing data from log files
# Usage: ./extract_timing.sh [log_directory] [output_file]

# ===CONFIGURATION===

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log_dir="${1:-$script_dir/log}"
output_file="${2:-$script_dir/extracted_timing_$(date '+%Y-%m-%d_%H-%M-%S').csv}"

# ===HELPER FUNCTIONS===

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# ===VALIDATION===

[ -d "$log_dir" ] || error "Log directory not found: $log_dir"

# ===EXTRACTION===

log "Extracting timing data from log files"
log "Log directory: $log_dir"
log "Output file: $output_file"

# Create CSV header
echo "Log_File,Total_Time_s,Stage1_Time_s,Stage2_Time_s,Stage3_Time_s,Timestamp,Text_Prompt" > "$output_file"

# Counter for processed files
processed=0
total_files=$(find "$log_dir" -name "*.log" | wc -l)

# Process each log file
for log_file in "$log_dir"/*.log; do
    if [ -f "$log_file" ]; then
        log_basename=$(basename "$log_file")
        
        # Extract timing data
        total_time=$(grep "TIMING_DATA: Total=" "$log_file" 2>/dev/null | sed 's/.*Total=\([0-9]*\)s/\1/' || echo "0")
        stage1_time=$(grep "TIMING_DATA: Stage1=" "$log_file" 2>/dev/null | sed 's/.*Stage1=\([0-9]*\)s/\1/' || echo "0")
        stage2_time=$(grep "TIMING_DATA: Stage2=" "$log_file" 2>/dev/null | sed 's/.*Stage2=\([0-9]*\)s/\1/' || echo "0")
        stage3_time=$(grep "TIMING_DATA: Stage3=" "$log_file" 2>/dev/null | sed 's/.*Stage3=\([0-9]*\)s/\1/' || echo "0")
        
        # Extract timestamp from filename or content
        file_timestamp=$(echo "$log_basename" | sed 's/\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_[0-9]\{2\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/' | tr '_' ' ' | tr '-' ':' || echo "unknown")
        
        # Extract text prompt from log content
        text_prompt=$(grep "Text prompt:" "$log_file" 2>/dev/null | head -n1 | sed 's/.*Text prompt: //' || echo "unknown")
        
        # Only add row if we found some timing data
        if [ "$total_time" != "0" ] || [ "$stage1_time" != "0" ] || [ "$stage2_time" != "0" ] || [ "$stage3_time" != "0" ]; then
            echo "$log_basename,$total_time,$stage1_time,$stage2_time,$stage3_time,$file_timestamp,$text_prompt" >> "$output_file"
            processed=$((processed + 1))
        fi
    fi
done

log "Extraction completed!"
log "Processed $processed out of $total_files log files"
log "Results saved to: $output_file"

# Generate basic statistics if we have data
if [ $processed -gt 0 ]; then
    log "Generating basic statistics..."
    
    python3 - << EOF
import pandas as pd
import numpy as np

try:
    df = pd.read_csv('$output_file')
    
    # Filter out rows with all zero timing data
    valid_data = df[(df['Total_Time_s'] > 0) | (df['Stage1_Time_s'] > 0) | (df['Stage2_Time_s'] > 0) | (df['Stage3_Time_s'] > 0)]
    
    if len(valid_data) == 0:
        print("No valid timing data found")
    else:
        print(f"\\nBasic Statistics from {len(valid_data)} log files:\\n")
        
        for column in ['Total_Time_s', 'Stage1_Time_s', 'Stage2_Time_s', 'Stage3_Time_s']:
            if column in valid_data.columns:
                data = valid_data[column][valid_data[column] > 0]  # Exclude zero values
                if len(data) > 0:
                    stage_name = column.replace('_Time_s', '').replace('_', ' ')
                    print(f"{stage_name}:")
                    print(f"  Count: {len(data)}")
                    print(f"  Mean: {data.mean():.2f}s")
                    print(f"  Std: {data.std():.2f}s")
                    print(f"  Min: {data.min():.2f}s")
                    print(f"  Max: {data.max():.2f}s")
                    print()
        
        # Show unique prompts
        unique_prompts = valid_data['Text_Prompt'].unique()
        print(f"Unique text prompts found: {len(unique_prompts)}")
        for prompt in unique_prompts:
            count = len(valid_data[valid_data['Text_Prompt'] == prompt])
            print(f"  '{prompt}': {count} runs")
            
except Exception as e:
    print(f"Error analyzing data: {e}")
EOF
    
    echo ""
    echo "📊 Extracted data saved to: $output_file"
else
    log "No timing data found in log files"
fi