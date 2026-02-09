# Text-to-Animation Pipeline (run_text_to_anim.sh)

This folder provides a single script to run a text prompt through a motion diffusion model, convert the motion format, and render an avatar animation with HUGS.

## What the script does

The script [run_text_to_anim.sh](run_text_to_anim.sh) runs three stages:

1. Generate SMPL motion from a text prompt using Motion Diffusion Model (MDM).
2. Convert the motion output into an NPZ format compatible with HUGS.
3. Run HUGS animation to render the avatar video.

## Tools and repositories used

- Motion Diffusion Model (MDM): text-to-motion generation. Expected at ../motion-diffusion-model.
- HUGS: avatar animation and rendering. Use https://github.com/SamTech37/ml-hugs (branch `avatar-testing`). Expected at ../ml-hugs.
- Conda: runs stage-specific Python environments (`mdm` and `hugs`).
- Helper scripts in this repo:
  - scripts/pick_sample.py (copied into MDM visualize/ to extract a sample of SMPL)
  - scripts/inspect_smpl.py (converts SMPL NPY to NPZ)
  - scripts/hugs_animate.py (copied into HUGS scripts/ to run animation)

## Prerequisites

- Linux with a CUDA-capable GPU.
- Conda environments created and working:
  - `mdm` for Motion Diffusion Model
  - `hugs` for HUGS
- MDM and HUGS repositories cloned and set up.
- A trained HUGS avatar available under ml-hugs/avatars/.

## Expected directory layout

This script assumes the following structure (relative to this README):

```
avatar-workshop-paper/
	run_text_to_anim.sh
	scripts/
		pick_sample.py
		inspect_smpl.py
		hugs_animate.py
motion-diffusion-model/
	save/
		humanml_enc_512_50steps/
			model*.pt
ml-hugs/
	avatars/
		lab-2025-07-16_08-01-21/
```

## Configuration knobs

Edit [run_text_to_anim.sh](run_text_to_anim.sh) to change defaults:

- `CUDA_VISIBLE_DEVICES` for GPU selection.
- `text_prompt` default prompt.
- `motion_model_name` and `motion_model_dir`.
- `avatar_name`, `avatar_model_dir`, `avatar_output_file`.
- `motion_length` in seconds.
- Conda env names `mdm_env` and `hugs_env`.

## Usage

From this folder:

```bash
./run_text_to_anim.sh
./run_text_to_anim.sh "A person is walking"
```

Outputs:

- Motion artifacts under output/ (results.npy, smpl_params.npy, etc.)
- Final video under output_video/ with the prompt as the filename

## Troubleshooting

- Missing motion generation model file: ensure a model\*.pt exists in motion-diffusion-model/save/<model_name>/.
- Missing 3DGS avatar: ensure the avatar directory exists in ml-hugs/avatars/<avatar_name>/.
- Conda errors: verify the `mdm` and `hugs` envs are created and dependencies installed, ensure both project themselves can be run successfully.

## Notes

- The script copies helper scripts into the MDM and HUGS repos at runtime.
- Stage timings are printed to help profile the pipeline.
