"""
a script to check what is inside a .npy file of SMPL pose sequences
and convert it to the format expected by HUGS (like NeuMan dataset)
"""

import numpy as np
import torch
from pytorch3d import transforms
import sys
import os

# Check command line arguments
if len(sys.argv) != 2:
    print("Usage: python inspect_smpl.py <path_to_npy_file>")
    sys.exit(1)

# Load the .npy file
motion_file = sys.argv[1]
if not os.path.exists(motion_file):
    print(f"Error: File '{motion_file}' not found")
    sys.exit(1)
else:
    print(f"Loading motion data from: {motion_file}")
data = np.load(motion_file, allow_pickle=True).item()

print("Loaded data keys:", data.keys())

for key in data.keys():
    print(f"{key}: {data[key].shape if isinstance(data[key], np.ndarray) else type(data[key])}")


print("\n=== Testing transformations ===")

# For thetas: (24, 6, frames) -> need (frames, joints*3)
thetas = data['thetas']  # (24, 6, frames)
print(f"Original thetas shape: {thetas.shape}")

# Transpose to (frames, joints, components) then reshape
thetas_transposed = thetas.transpose(2, 0, 1)  # (frames, 24, 6)
print(f"After transpose: {thetas_transposed.shape}")


print("\n=== Converting 6D to axis-angle ===")

# Convert to PyTorch tensor
thetas_tensor = torch.from_numpy(thetas_transposed).float()  # (frames, 24, 6)

# Reshape to (frames*joints, 6) for batch processing
frames, joints, components = thetas_tensor.shape
thetas_flat = thetas_tensor.reshape(-1, 6)  # (frames*24, 6)

# Convert 6D to rotation matrix
rot_matrices = transforms.rotation_6d_to_matrix(thetas_flat)  # (frames*24, 3, 3)

# Convert rotation matrix to axis-angle (SMPL expects axis-angle format)
axis_angles = transforms.matrix_to_axis_angle(rot_matrices)  # (frames*24, 3)

# Reshape back to (frames, joints, 3)
axis_angles_reshaped = axis_angles.reshape(frames, joints, 3)  # (frames, 24, 3)

# Finally reshape to (frames, joints*3) for SMPL
poses_converted = axis_angles_reshaped.reshape(frames, -1)  # (frames, 72)
print(f"Final poses shape: {poses_converted.shape}")

# Convert back to numpy if needed
poses_numpy = poses_converted.numpy()


# For root_translation: (3, frames) -> (frames, 3)
root_trans = data['root_translation']  # (3, frames)
print(f"\nOriginal root_translation shape: {root_trans.shape}")

# Transpose to (frames, xyz)
transl = root_trans.T  # (frames, 3)
print(f"Final transl shape: {transl.shape}")

print(f"\nBoth formats ready for SMPL:")
print(f"poses: {poses_numpy.shape}")
print(f"transl: {transl.shape}")

# Test a few values to make sure they look reasonable
print(f"\nSample axis-angle values (should be reasonable rotation angles):")
print(f"First joint, first frame: {poses_numpy[0, :3]}")
print(f"Magnitudes: {np.linalg.norm(poses_numpy[0, :3])}")

# Save in .npz format expected by NeuMan dataset
print("\n=== Saving to .npz format ===")

# The NeuMan dataset expects:
# - 'poses': (frames, 72) - body pose parameters in axis-angle format
# - 'trans': (frames, 3) - root translation

# Generate output filename based on input filename
input_name = os.path.splitext(os.path.basename(motion_file))[0]
output_file = f'./{input_name}_formated.npz'
np.savez(output_file, 
         poses=poses_numpy,  # (frames, 72)
         trans=transl        # (frames, 3)
)

print(f"Saved to {output_file}")
print(f"Contains:")
print(f"  poses: {poses_numpy.shape}")
print(f"  trans: {transl.shape}")

# Verify the saved file
print("\n=== Verifying saved file ===")
saved_data = np.load(output_file)
print(f"Loaded keys: {list(saved_data.keys())}")
print(f"poses shape: {saved_data['poses'].shape}")
print(f"trans shape: {saved_data['trans'].shape}")

print("\nFile ready for HUGS animation!")