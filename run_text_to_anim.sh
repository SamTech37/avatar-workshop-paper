#!/bin/bash

set -e

# ===ENV==

# set to available GPU, id = 0,1,2,3
export CUDA_VISIBLE_DEVICES=0



# ===variables===
MOTION_MODEL_DIR=""
AVATAR_MODEL_DIR=""
RESULT_DIR=""


# ===main program===

echo "Starting pipeline..."

# generate the SMPL motion
echo "Activating mdm environment for SMPL motion generation..."
conda activate mdm

#...


echo "SMPL motion generation complete."

# run the animation script
echo "Activating hugs environment for animation..."
conda activate hugs

#...


echo "Pipeline complete."