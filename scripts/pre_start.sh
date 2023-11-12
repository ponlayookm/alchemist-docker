#!/usr/bin/env bash
export PYTHONUNBUFFERED=1

echo "Container is running"

# Sync venv to workspace to support Network volumes
echo "Syncing venv to workspace, please wait..."
rsync -au /venv/ /venv/
rm -rf /venv

# Sync Web UI to workspace to support Network volumes
echo "Syncing Stable Diffusion Web UI to workspace, please wait..."
rsync -au /stable-diffusion-webui/ /stable-diffusion-webui/
rm -rf /stable-diffusion-webui

# Sync Kohya_ss to workspace to support Network volumes
echo "Syncing Kohya_ss to workspace, please wait..."
rsync -au /kohya_ss/ /kohya_ss/
rm -rf /kohya_ss

# Sync ComfyUI to workspace to support Network volumes
echo "Syncing ComfyUI to workspace, please wait..."
rsync -au /ComfyUI/ /ComfyUI/
rm -rf /ComfyUI

# Sync Application Manager to workspace to support Network volumes
echo "Syncing Application Manager to workspace, please wait..."
rsync -au /app-manager/ /app-manager/
rm -rf /app-manager

# Fix the venvs to make them work from /workspace
echo "Fixing Stable Diffusion Web UI venv..."
/fix_venv.sh /venv /venv

echo "Fixing Kohya_ss venv..."
/fix_venv.sh /kohya_ss/venv /kohya_ss/venv

echo "Fixing ComfyUI venv..."
/fix_venv.sh /ComfyUI/venv /ComfyUI/venv

# Link models and VAE if they are not already linked
if [[ ! -L /stable-diffusion-webui/models/Stable-diffusion/sd_xl_base_1.0.safetensors ]]; then
    ln -s /sd-models/sd_xl_base_1.0.safetensors /stable-diffusion-webui/models/Stable-diffusion/sd_xl_base_1.0.safetensors
fi

if [[ ! -L /stable-diffusion-webui/models/Stable-diffusion/sd_xl_refiner_1.0.safetensors ]]; then
    ln -s /sd-models/sd_xl_refiner_1.0.safetensors /stable-diffusion-webui/models/Stable-diffusion/sd_xl_refiner_1.0.safetensors
fi

if [[ ! -L /stable-diffusion-webui/models/VAE/sdxl_vae.safetensors ]]; then
    ln -s /sd-models/sdxl_vae.safetensors /stable-diffusion-webui/models/VAE/sdxl_vae.safetensors
fi

# Configure accelerate
echo "Configuring accelerate..."
mkdir -p /root/.cache/huggingface/accelerate
mv /accelerate.yaml /root/.cache/huggingface/accelerate/default_config.yaml

# Create logs directory
mkdir -p /logs

# Start application manager
cd /app-manager
npm start > /logs/app-manager.log 2>&1 &

if [[ ${DISABLE_AUTOLAUNCH} ]]
then
    echo "Auto launching is disabled so the applications will not be started automatically"
    echo "You can launch them manually using the launcher scripts:"
    echo ""
    echo "   Stable Diffusion Web UI:"
    echo "   ---------------------------------------------"
    echo "   /start_a1111.sh"
    echo ""
    echo "   Kohya_ss"
    echo "   ---------------------------------------------"
    echo "   /start_kohya.sh"
    echo ""
    echo "   ComfyUI"
    echo "   ---------------------------------------------"
    echo "   /start_comfyui.sh"
else
    /start_a1111.sh
    /start_kohya.sh
    /start_comfyui.sh
fi

if [ ${ENABLE_TENSORBOARD} ];
then
    /start_tensorboard.sh
fi

echo "All services have been started"
