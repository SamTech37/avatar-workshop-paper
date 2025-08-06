#!/bin/bash
set -e

# ===ENV==

# set to available GPU, id = 0,1,2,3
export CUDA_VISIBLE_DEVICES=0


# ===input variables===

# DO NOT output at the same directory as the script
# the mdm script will wipe the output directory clean
# so we need to set a different output directory, e.g. a subdirectory /output

main_dir="$(pwd)"
result_dir="$(pwd)/output" 

motion_model_name="humanml_enc_512_50steps/"
motion_model_dir="save/${motion_model_name}"

avatar_name="lab-2025-07-16_08-01-21"
avatar_model_dir="../ml-hugs/avatars/${avatar_name}"
avatar_output_file="anim_neuman_ours_final.mp4"

# change this to input argument 
text_prompt="A person is doing cartwheels"



# ===main program===

echo "Starting pipeline... in $(pwd)"

echo "copying scripts"
cp "./scripts/pick_sample.py" "../motion-diffusion-model/visualize/pick_sample.py"
cp "./scripts/hugs_animate.py" "../ml-hugs/scripts/hugs_animate.py"

cd "../motion-diffusion-model"
echo "Activating mdm environment for SMPL motion generation... in $(pwd)"

# get the model file in the directory
motion_model_file="$(ls -1v ${motion_model_dir}/model*.pt | tail -n1)" 
echo "full path = ${motion_model_file}"

# generate the SMPL motion
echo "conda running task"
conda run -n mdm python -m sample.generate \
    --model_path "${motion_model_file}" \
    --output_dir "${result_dir}" \
    --text_prompt "${text_prompt}" \
    --num_samples 1  \
    --num_repetitions 1 \
    --motion_length 9.8


conda run -n mdm python -m visualize.pick_sample \
    --npy_path "${result_dir}/results.npy" \
    --sample_id 0 \
    --rep_id 0 \
    --output_dir  "${result_dir}" 

echo "SMPL motion generation complete."

# convert the motion npy file to SMPL format conforming to HUGS

cd "${main_dir}"
conda run -n hugs python "./scripts/inspect_smpl.py" \
    "${result_dir}/smpl_params.npy" 



# run the animation script
echo "Activating hugs environment for animation..."

cd "../ml-hugs"


#...


echo "Pipeline complete."