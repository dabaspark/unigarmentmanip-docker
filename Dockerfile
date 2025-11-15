# Use an older image that has CUDA 9.2 and a compatible OS (Ubuntu 18.04)
FROM nvcr.io/nvidia/cuda:9.2-devel-ubuntu18.04 AS pyflex-builder

# The base image has outdated NVIDIA apt repos. Remove them to prevent apt-get update from failing.
RUN rm /etc/apt/sources.list.d/cuda.list /etc/apt/sources.list.d/nvidia-ml.list



# Install build essentials, Python, pybind11, AND graphics libraries
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    python3.8 \
    python3.8-dev \
    python3-pip \
    libegl1-mesa-dev \
    libgl1-mesa-dev \
    freeglut3-dev \
	ninja-build \
    && rm -rf /var/lib/apt/lists/*
	
	
RUN pip3 install pybind11

# Copy only the PyFlex source and compile it
WORKDIR /build
COPY garmentgym/PyFlex /build/garmentgym/PyFlex

# Set the PYFLEXROOT environment variable so CMake can find the source files
ENV PYFLEXROOT=/build/garmentgym/PyFlex

WORKDIR /build/garmentgym/PyFlex/bindings
RUN rm -rf build && mkdir build && cd build && \
    cmake -DPYBIND11_PYTHON_VERSION=3.8 \
          -Dpybind11_DIR=$(python3 -c "import pybind11; print(pybind11.get_cmake_dir())") \
          .. && \
    make -j


# --- STAGE 2: Final Application Image using CUDA 11.0 ---
FROM nvidia/cuda:11.0.3-devel-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies for the main application
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    python3.8 \
    python3.8-dev \
    python3-pip \
    libegl1-mesa-dev \
    libgl1-mesa-dev \
    libx11-dev \
    freeglut3-dev \
	ninja-build \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda
ENV CONDA_DIR=/opt/conda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-py38_23.11.0-2-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    /bin/bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh
ENV PATH=$CONDA_DIR/bin:$PATH

WORKDIR /workspace

# Accept ToS and update conda
#RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
#    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r && \
#    conda update -n base -c defaults conda -y

# Copy and create environment (using the modified environment.yml without cudatoolkit)
COPY environment.yml .
RUN conda env create -f environment.yml && \
    conda install -n UniGarmentManip -c conda-forge pybind11 -y

# Set the conda shell
SHELL ["conda", "run", "-n", "UniGarmentManip", "/bin/bash", "-c"]

# --- Install mesh_raycast from source ---
COPY ./python-mesh-raycast /workspace/python-mesh-raycast
WORKDIR /workspace/python-mesh-raycast
RUN pip install glm numpy && \
    python setup.py install
WORKDIR /workspace


# Copy the rest of the project source code
COPY . .

# --- Final Assembly ---

# Copy the pre-compiled PyFlex library from the builder stage
COPY --from=pyflex-builder /build/garmentgym/PyFlex/bindings/build/pyflex.*.so /workspace/garmentgym/PyFlex/bindings/build/

# Compile PointNet++ using the CUDA 11.0 environment
ENV TORCH_CUDA_ARCH_LIST="7.5"
COPY ./Pointnet2_PyTorch /workspace/Pointnet2_PyTorch
WORKDIR /workspace/Pointnet2_PyTorch
RUN pip install -r requirements.txt && \
    pip install -e .
WORKDIR /workspace

# Set final environment variables
ENV PYFLEXROOT=/workspace/garmentgym/PyFlex
ENV PYTHONPATH="${PYFLEXROOT}/bindings/build:${PYTHONPATH:-}"
ENV LD_LIBRARY_PATH="${PYFLEXROOT}/external/SDL2-2.0.4/lib/x64:${LD_LIBRARY_PATH:-}"