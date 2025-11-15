# UniGarmentManip in Docker

This repository provides a fully containerized environment to run the [UniGarmentManip](https://github.com/luhr2003/UniGarmentManip) project on any modern Linux system (tested on Ubuntu 24.04), with full GPU acceleration and GUI support for the simulator.

The goal is to solve the significant dependency hell.


### Demo

Here's the fling task running on Ubuntu 24.04 with an NVIDIA RTX 4060, all from within the Docker container.

<div align="center">
  <video src="https://github.com/user-attachments/assets/0d362ae7-6159-42ff-81b9-cae7e22fe238" width="640" height="360" controls>
  </video>
</div>

### The "Why": The Core Problem

Running this project natively on a modern system is nearly impossible due to a cascade of version conflicts. This Docker setup solves them.

*   **OS Mismatch:** The project assumes an Ubuntu 18.04/20.04 environment, but my host was 24.04, leading to `glibc` and compiler incompatibilities.
*   **Mutually Exclusive CUDA Requirements:** This is the killer issue. The project's components require two different CUDA toolkits:
    *   **PyFlex (Physics Simulator):** Hard-coded dependency on **CUDA 9.2**.
    *   **PointNet++ & PyTorch:** Requires **CUDA 11.0**.
*   **Compiler Incompatibility:** CUDA 11.0 requires GCC 9 or older. Modern systems have GCC 12/13+, which will fail to compile the CUDA code.
*   **GPU Architecture:** The project's old PyTorch version doesn't recognize modern GPUs (like the RTX 40-series) when used with TORCH_CUDA_ARCH bigger than 7.5. The build process needs to be told to compile for an older, compatible architecture (`compute_75`).

This repository encapsulates the entire complex solution in a simple-to-use package.

### Prerequisites

You only need three things on your host machine.

1.  **Docker:** [Install Docker Engine](https://docs.docker.com/engine/install/ubuntu/).
2.  **NVIDIA Container Toolkit:** To give Docker access to your GPU. [Installation Guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).
3.  **Allow X Server Connections:** For the GUI simulator to display on your screen. Run this once per session (or add it to your `.bashrc`):
    ```bash
    xhost +local:docker
    ```
4.  **Verify Setup:** Check that Docker can see your GPU.
    ```bash
    docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi
    ```
    If that command works, go to next step.

---

### Quick Start (Recommended)

This method uses the pre-built image from Docker Hub. It's the fastest way to get started.

1.  **Clone this repository:**
    ```bash
    git clone https://github.com/dabaspark/unigarmentmanip-docker.git
    cd unigarmentmanip-docker
    ```

2.  **Make the script executable:**
    ```bash
    chmod +x image/run_image.sh
    ```

3.  **Run it!**
    ```bash
	xhost +local:docker
	
    ./image/run_image.sh
    ```
This will pull the `dabaspark/unigarmentmanip:latest` image and drop you into a `bash` shell inside the container, ready to go.

Note: if you want to run this again, make sure to delete the container `docker rm unigarment_container`

4.  **Test** (When you are inside the docker environment)
    ```bash
    source /opt/conda/etc/profile.d/conda.sh

	conda activate UniGarmentManip

	python -m task.fling.double_fling_from_deform \
		--current_cloth ./garmentgym/tops \
		--model_path ./checkpoint/tops.pth \
		--demonstration ./demonstration/tops/fling/00044.pkl \
		--mesh_id 00037
    ```

### Option 2: Build from Source

If you want to modify the environment or build the image yourself from scratch.

1.  **Clone this repository:**
    ```bash
    git clone https://github.com/dabaspark/unigarmentmanip-docker.git
    cd unigarmentmanip-docker
    ```
	
2.  **Make the build script executable:**
    ```bash
    chmod +x unigarment.sh
    ```
3.  **Build and run:**
    ```bash
    ./unigarment.sh
    ```
    The script will first clone the `UniGarmentManip` project and its dependencies into a local sub-directory. Then, it will build the Docker image and launch a container. This will take a long time on the first run.

---

### How to Use the Container

Once you are inside the container's shell (using either script):

*   The code is located at `/workspace/UniGarmentManip`.
*   All custom libraries (PyFlex, PointNet++) are compiled and ready.

#### Example: Running the Fling Task

To run one of the project's main tasks, you just need to execute the Python script. The container has all the necessary environment variables set.

```bash
xhost +local:docker

docker run --rm --gpus all -it \
-e NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics \
-e __GLX_VENDOR_LIBRARY_NAME=nvidia \
-v /tmp/.X11-unix:/tmp/.X11-unix \
-e DISPLAY=$DISPLAY \
unigarment \
/bin/bash -c "conda run -n UniGarmentManip python -m task.fling.double_fling_from_deform \
--current_cloth /workspace/garmentgym/tops \
--model_path /workspace/checkpoint/tops.pth \
--demonstration /workspace/demonstration/tops/fling/00044.pkl \
--mesh_id 00037"

```

A simulation window should appear on your screen.

#### Opening Additional Terminals

If you need another shell into the same running container (very useful for projects that use this as baseline), open a new terminal **on your host machine** and run:
```bash
docker exec -it unigarment_container bash
```

### Session Management

*   **Resuming Work:** If you exited, the container is stopped. To restart it without losing the work (e.g., downloaded datasets, new files):
    ```bash
    docker start unigarment_container
    docker exec -it unigarment_container bash
    ```
*   **Starting Fresh:** If you want a clean slate, remove the old container before running the script again:
    ```bash
    docker rm unigarment_container
    ./image/run_image.sh
    ```

### The Nitty-Gritty: How It Works

This solution uses a **multi-stage Docker build** to resolve the CUDA version conflict.

1.  **Stage 1 (`pyflex-builder`):**
    *   Starts from an `nvidia/cuda:9.2-devel-ubuntu18.04` image.
    *   Installs the bare minimum build tools and graphics libraries.
    *   Compiles **PyFlex** against CUDA 9.2. This produces a `pyflex.so` library file.

2.  **Stage 2 (Final Image):**
    *   Starts from a clean `nvidia/cuda:11.0.3-devel-ubuntu20.04` image.
    *   Installs the full dependency stack (Conda, Python 3.8, system libs).
    *   **Copies the `pyflex.so` file** from the first stage into the correct location.
    *   Compiles **PointNet++** against CUDA 11.0, ensuring it's compatible with PyTorch.
    *   The final image contains everything needed, with each component compiled in its ideal environment.

### Acknowledgments
*   This project provides an environment for the original **UniGarmentManip** paper and code. Please cite their work if you use it.
    *   [Original GitHub Repository](https://github.com/luhr2003/UniGarmentManip)
    *   [Paper](https://arxiv.org/abs/2405.06903)

For any issues with this Docker setup, feel free to contact me: `m.abdulwahab.daba@gmail.com`