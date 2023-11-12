# Stage 1: Base
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04 as base

ARG WEBUI_VERSION=v1.6.0
ARG DREAMBOOTH_COMMIT=cf086c536b141fc522ff11f6cffc8b7b12da04b9
ARG KOHYA_VERSION=v22.1.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Bangkok \
    PYTHONUNBUFFERED=1 \
    SHELL=/bin/bash
#ENV TORCH_COMMAND="pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118"

# Create workspace working directory
WORKDIR /

# Install Ubuntu packages
RUN apt update && \
    apt -y upgrade && \
    apt install -y --no-install-recommends \
        build-essential \
        software-properties-common \
        python3.10-venv \
        python3-pip \
        python3-tk \
        python3-dev \
        nodejs \
        npm \
        bash \
        dos2unix \
        git \
        git-lfs \
        ncdu \
        nginx \
        net-tools \
        inetutils-ping \
        openssh-server \
        libglib2.0-0 \
        libsm6 \
        libgl1 \
        libxrender1 \
        libxext6 \
        ffmpeg \
        wget \
        curl \
        psmisc \
        rsync \
        vim \
        zip \
        unzip \
        p7zip-full \
        htop \
        pkg-config \
        plocate \
        libcairo2-dev \
        libgoogle-perftools4 \
        libtcmalloc-minimal4 \
        apt-transport-https \
        ca-certificates && \
    update-ca-certificates && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen

# Set Python
RUN ln -s /usr/bin/python3.10 /usr/bin/python

# Install Torch, xformers and tensorrt
RUN  pip3 install --no-cache-dir torch==2.0.1 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118 && \
     pip3 install --no-cache-dir xformers==0.0.22 tensorrt


# Stage 2: Install applications
FROM base as setup

RUN mkdir -p /sd-models

# Add SDXL models and VAE
# These need to already have been downloaded:
#   wget https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors
#   wget https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0.safetensors
#   wget https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors
# COPY sd_xl_base_1.0.safetensors /sd-models/sd_xl_base_1.0.safetensors
# COPY sd_xl_refiner_1.0.safetensors /sd-models/sd_xl_refiner_1.0.safetensors
# COPY sdxl_vae.safetensors /sd-models/sdxl_vae.safetensors

# Clone the git repo of the Stable Diffusion Web UI by Automatic1111
# and set version
WORKDIR /
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd /stable-diffusion-webui 
    #git checkout tags/${WEBUI_VERSION}

WORKDIR /stable-diffusion-webui
RUN python3 -m venv --system-site-packages /venv && \
    source /venv/bin/activate && \
    pip install --no-cache-dir torch==2.0.1 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118 && \
    pip install --no-cache-dir xformers && \
    pip install httpx==0.24.0 && \
    pip install onnxruntime-gpu && \
    deactivate

# Install the dependencies for the Automatic1111 Stable Diffusion Web UI
COPY a1111/requirements.txt a1111/requirements_versions.txt ./
COPY a1111/cache-sd-model.py a1111/install-automatic.py ./
RUN source /venv/bin/activate && \
    python -m install-automatic --skip-torch-cuda-test && \
    deactivate

# Cache the Stable Diffusion Models
# SDXL models result in OOM kills with 8GB system memory, probably need 12GB+ to cache these
#RUN source /venv/bin/activate && \
    #python3 cache-sd-model.py --use-cpu=all --ckpt /sd-models/sd_xl_base_1.0.safetensors && \
    #python3 cache-sd-model.py --use-cpu=all --ckpt /sd-models/sd_xl_refiner_1.0.safetensors && \
    #deactivate

Run git clone https://huggingface.co/embed/negative embeddings/negative && \
    git clone https://huggingface.co/embed/lora models/Lora/positive

# Clone the Automatic1111 Extensions
RUN git clone --depth=1 https://github.com/Mikubill/sd-webui-controlnet.git extensions/sd-webui-controlnet && \
    git clone --depth=1 https://github.com/Gourieff/sd-webui-reactor.git extensions/sd-webui-reactor && \
    git clone --depth=1 https://github.com/zanllp/sd-webui-infinite-image-browsing.git extensions/infinite-image-browsing && \
    git clone --depth=1 https://github.com/Bing-su/adetailer.git extensions/adetailer && \
    #git clone --depth=1 https://github.com/civitai/sd_civitai_extension.git extensions/sd_civitai_extension && \
    git clone --depth=1 https://github.com/Coyote-A/ultimate-upscale-for-automatic1111 extensions/ultimate-upscale-for-automatic1111 && \
    git clone --depth=1 https://github.com/richrobber2/canvas-zoom extensions/canvas-zoom && \
    git clone --depth=1 https://github.com/yankooliveira/sd-webui-photopea-embed extensions/sd-webui-photopea-embed && \
    git clone --depth=1 https://github.com/etherealxx/batchlinks-webui extensions/batchlinks-webui && \
    git clone --depth=1 https://github.com/continue-revolution/sd-webui-animatediff extensions/sd-webui-animatediff
    

RUN cd /stable-diffusion-webui/extensions/sd-webui-animatediff/model && \
    wget https://civitai.com/api/download/models/159987 --content-disposition && \
    cd /stable-diffusion-webui/models/Stable-diffusion && \
    wget https://civitai.com/api/download/models/148087 --content-disposition && \
    wget https://civitai.com/api/download/models/179525 --content-disposition && \
    cd /stable-diffusion-webui/models/Lora && \
    wget https://civitai.com/api/download/models/132876 --content-disposition && \
    mkdir -p /stable-diffusion-webui/models/ESRGAN && \
    cd /stable-diffusion-webui/models/ESRGAN && \
    wget https://huggingface.co/embed/upscale/resolve/main/4x-UltraSharp.pth 

#Extension dependancies
RUN source /venv/bin/activate && \
    cd /stable-diffusion-webui/extensions/sd-webui-controlnet && \
    pip3 install -r requirements.txt && \
    cd /stable-diffusion-webui/extensions/sd-webui-reactor && \
    pip3 install -r requirements.txt && \
    cd /stable-diffusion-webui/extensions/infinite-image-browsing && \
    pip3 install -r requirements.txt && \
    cd /stable-diffusion-webui/extensions/adetailer && \
    python -m install && \
    #cd /stable-diffusion-webui/extensions/sd_civitai_extension && \
    #pip3 install -r requirements.txt && \
    deactivate


# Add inswapper model for the ReActor extension
RUN mkdir -p /stable-diffusion-webui/models/insightface && \
    cd /stable-diffusion-webui/models/insightface && \
    wget https://huggingface.co/ezioruan/inswapper_128.onnx/resolve/main/inswapper_128.onnx

#Controlnet models
WORKDIR /stable-diffusion-webui/extensions/sd-webui-controlnet/models
RUN wget https://huggingface.co/ckpt/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny_fp16.safetensors && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/raw/main/control_v11p_sd15_canny_fp16.yaml && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/resolve/main/control_v11f1p_sd15_depth_fp16.safetensors && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/raw/main/control_v11f1p_sd15_depth_fp16.yaml && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/resolve/main/control_v11p_sd15_normalbae_fp16.safetensors && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/raw/main/control_v11p_sd15_normalbae_fp16.yaml && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/resolve/main/control_v11p_sd15_mlsd_fp16.safetensors && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/raw/main/control_v11p_sd15_mlsd_fp16.yaml && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/resolve/main/control_v11p_sd15_openpose_fp16.safetensors && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/raw/main/control_v11p_sd15_openpose_fp16.yaml && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/resolve/main/control_v11p_sd15_lineart_fp16.safetensors && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/resolve/main/control_v11p_sd15s2_lineart_anime_fp16.safetensors && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/raw/main/control_v11p_sd15_lineart_fp16.yaml && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/raw/main/control_v11p_sd15s2_lineart_anime_fp16.yaml && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/resolve/main/control_v11p_sd15_inpaint_fp16.safetensors && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/raw/main/control_v11p_sd15_inpaint_fp16.yaml && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/resolve/main/control_v11p_sd15_scribble_fp16.safetensors && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/raw/main/control_v11p_sd15_scribble_fp16.yaml && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/resolve/main/control_v11p_sd15_softedge_fp16.safetensors && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/raw/main/control_v11p_sd15_softedge_fp16.yaml && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/resolve/main/control_v11f1e_sd15_tile_fp16.safetensors && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/raw/main/control_v11f1e_sd15_tile_fp16.yaml && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/resolve/main/control_v11e_sd15_shuffle_fp16.safetensors && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/raw/main/control_v11e_sd15_shuffle_fp16.yaml && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/resolve/main/control_v11e_sd15_ip2p_fp16.safetensors && \
    wget https://huggingface.co/ckpt/ControlNet-v1-1/raw/main/control_v11e_sd15_ip2p_fp16.yaml && \
    wget https://huggingface.co/monster-labs/control_v1p_sd15_qrcode_monster/resolve/main/control_v1p_sd15_qrcode_monster.safetensors && \
    wget https://huggingface.co/monster-labs/control_v1p_sd15_qrcode_monster/resolve/main/control_v1p_sd15_qrcode_monster.yaml && \
    wget https://huggingface.co/lllyasviel/sd_control_collection/resolve/main/ip-adapter_sd15.pth && \
    wget https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter-plus-face_sd15.bin && \
    wget https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter-plus_sd15.bin 

# Fix Tensorboard
RUN source /venv/bin/activate && \
    pip3 uninstall -y tensorboard tb-nightly && \
    pip3 install tensorboard tensorflow && \
    pip3 cache purge && \
    deactivate

# Install Kohya_ss
RUN git clone https://github.com/bmaltais/kohya_ss.git /kohya_ss
WORKDIR /kohya_ss
COPY kohya_ss/requirements* ./
RUN git checkout ${KOHYA_VERSION} && \
    python3 -m venv --system-site-packages venv && \
    source venv/bin/activate && \
    pip3 install --no-cache-dir torch==2.0.1 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118 && \
    pip3 install --no-cache-dir xformers==0.0.22 \
        bitsandbytes==0.41.1 \
        tensorboard==2.14.1 \
        tensorflow==2.14.0 \
        wheel \
        scipy \
        tensorrt && \
    pip3 install -r requirements.txt && \
    pip3 install . && \
    pip3 cache purge && \
    deactivate

# Install ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /ComfyUI
WORKDIR /ComfyUI
RUN python3 -m venv --system-site-packages venv && \
    source venv/bin/activate && \
    pip3 install --no-cache-dir torch==2.0.1 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118 && \
    pip3 install --no-cache-dir xformers==0.0.22 && \
    pip3 install -r requirements.txt && \
    deactivate

# Install ComfyUI Custom Nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager && \
    cd custom_nodes/ComfyUI-Manager && \
    source /ComfyUI/venv/bin/activate && \
    pip3 install -r requirements.txt && \
    pip3 cache purge && \
    deactivate

# Install Application Manager
WORKDIR /
RUN git clone https://github.com/ashleykleynhans/app-manager.git /app-manager && \
    cd /app-manager && \
    npm install

# Install Jupyter
WORKDIR /
RUN pip3 install -U --no-cache-dir jupyterlab \
        jupyterlab_widgets \
        ipykernel \
        ipywidgets \
        gdown

# Install rclone
RUN curl https://rclone.org/install.sh | bash

# Install runpodctl
RUN wget https://github.com/runpod/runpodctl/releases/download/v1.10.0/runpodctl-linux-amd -O runpodctl && \
    chmod a+x runpodctl && \
    mv runpodctl /usr/local/bin

# Install croc
RUN curl https://getcroc.schollz.com | bash

# Install speedtest CLI
RUN curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash && \
    apt install speedtest

# Install CivitAI Model Downloader
#RUN git clone --depth=1 https://github.com/ashleykleynhans/civitai-downloader.git && \
    #mv civitai-downloader/download.sh /usr/local/bin/download-model && \
    #chmod +x /usr/local/bin/download-model

# Copy Stable Diffusion Web UI config files
COPY a1111/relauncher.py a1111/webui-user.sh a1111/config.json a1111/ui-config.json /stable-diffusion-webui/

# ADD SDXL styles.csv
ADD https://raw.githubusercontent.com/Douleb/SDXL-750-Styles-GPT4-/main/styles.csv /stable-diffusion-webui/styles.csv

# Copy ComfyUI Extra Model Paths (to share models with A1111)
COPY comfyui/extra_model_paths.yaml /ComfyUI/

# NGINX Proxy
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/502.html /usr/share/nginx/html/502.html
COPY nginx/README.md /usr/share/nginx/html/README.md

WORKDIR /

# Copy the scripts
COPY --chmod=755 scripts/* ./

# Copy the accelerate configuration
COPY kohya_ss/accelerate.yaml ./

# Start the container
SHELL ["/bin/bash", "--login", "-c"]
CMD [ "/start.sh" ]
