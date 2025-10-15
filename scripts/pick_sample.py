
# modified from render_mesh.py to pick a sample from results.npy
# doesn't render the mesh, but saves the SMPL parameters and obj files for a specific sample and repetition

# put this script into motion-diffusion-model/visualize/pick_sample.py

import argparse
import os
from visualize import vis_utils
from tqdm import tqdm

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--npy_path", type=str, required=True, help='Path to results.npy file')
    parser.add_argument("--sample_id", type=int, required=True, help='Sample ID to render')
    parser.add_argument("--rep_id", type=int, required=True, help='Repetition ID to render')
    parser.add_argument("--output_dir", type=str, required=True, help='Output directory for mesh files')
    parser.add_argument("--cuda", type=bool, default=True, help='')
    parser.add_argument("--device", type=int, default=0, help='')
    params = parser.parse_args()

    assert os.path.exists(params.npy_path)
    
    if os.path.exists(params.output_dir):
        # please don't use shutil.rmtree here
        # as it will delete the entire directory without caution
        print(f"Warning: Output directory {params.output_dir} already exists. Files may be overwritten.")
    else:
        os.makedirs(params.output_dir)

    npy2obj = vis_utils.npy2obj(params.npy_path, params.sample_id, params.rep_id,
                                device=params.device, cuda=params.cuda)

    #comment out this part to skip the mesh rendering
    print('Saving obj files to [{}]'.format(os.path.abspath(params.output_dir)))
    mesh_dir = os.path.join(params.output_dir, 'mesh')
    os.makedirs(mesh_dir, exist_ok=True)
    for frame_i in tqdm(range(npy2obj.real_num_frames)):
        npy2obj.save_obj(os.path.join(mesh_dir, 'frame{:03d}.obj'.format(frame_i)), frame_i)

    # save the SMPL parameters
    out_npy_path = os.path.join(params.output_dir, 'smpl_params.npy')
    print('Saving SMPL params to [{}]'.format(os.path.abspath(out_npy_path)))
    npy2obj.save_npy(out_npy_path)