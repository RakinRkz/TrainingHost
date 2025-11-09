#!/bin/bash

# Script to deploy GPU droplet via Terraform and manage lifecycle
# Usage: ./train.sh <CLASS_NAME>

# Get class name from parameter
CLASS_NAME="${1}"

# Validate that class name was provided
if [ -z "$CLASS_NAME" ]; then
    echo "❌ Error: Class name not provided!"
    echo "Usage: ./train.sh <CLASS_NAME>"
    echo "Example: ./train.sh batch_20251101T223547Z"
    exit 1
fi

# Set up log file FIRST before changing directory
LOG_FILE="/root/TrainingHost/host_app/training_log_${CLASS_NAME}.txt"

# Redirect ALL output (stdout and stderr) to log file AND terminal
# This line makes all subsequent output go to both places
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

cd ../training

# Use class-specific terraform working directory to support concurrent deployments
TERRAFORM_DIR="../training/${CLASS_NAME}_terraform"
mkdir -p "$TERRAFORM_DIR"

# Initialize Terraform in class-specific directory
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Initializing Terraform..."
cd "$TERRAFORM_DIR"
terraform init

# Apply the configuration
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating GPU droplet..."
terraform apply -auto-approve

# Get the droplet IP
DROPLET_IP=$(terraform output -raw droplet_ip)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Droplet IP: $DROPLET_IP"

# Wait for SSH to be ready
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for SSH to be ready..."
while ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ~/.ssh/id_rsa_do_controller root@$DROPLET_IP exit; do
    sleep 10
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Still waiting for SSH..."
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] SSH ready. Syncing GLASS-new folder..."

# Rsync the GLASS-new folder to the droplet, excluding other class data
# Important: rsync processes filter patterns in order, first match wins
rsync -avz \
    --exclude='.git' \
    --exclude='.venv' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.pytest_cache' \
    --exclude='.mypy_cache' \
    --exclude='*.egg-info' \
    --include='raw-data/'"$CLASS_NAME"'/' \
    --include='raw-data/'"$CLASS_NAME"'/**' \
    --exclude='raw-data/*' \
    --include='datasets/custom/'"$CLASS_NAME"'/' \
    --include='datasets/custom/'"$CLASS_NAME"'/**' \
    --exclude='datasets/custom/*' \
    --exclude='results/*' \
    -e "ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_do_controller" \
    /root/TrainingHost/GLASS-new root@$DROPLET_IP:~/

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Folder synced. Setting up environment..."

# SSH into droplet and set up environment
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Connecting to droplet for setup..."
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_do_controller root@$DROPLET_IP << EOF
    # Update system
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Updating system packages..."
    apt-get update -y
    
    # Install required system packages
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Installing system packages..."
    apt-get install -y python3-pip python3-venv git wget unzip
    
    # Verify and initialize CUDA
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Checking CUDA and GPU availability..."
    if command -v nvidia-smi &> /dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] ✓ nvidia-smi found"
        nvidia-smi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] ⚠ nvidia-smi not found, installing CUDA drivers..."
        apt-get install -y nvidia-driver-550 nvidia-utils
        modprobe nvidia
    fi
    
    # Verify CUDA libraries are accessible
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Verifying CUDA library paths..."
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH
    export CUDA_HOME=/usr/local/cuda
    export PATH=\$CUDA_HOME/bin:\$PATH
    
    # Navigate to the GLASS-new folder
    cd /root/GLASS-new
    
    # Set CUDA environment BEFORE creating venv
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH
    export CUDA_HOME=/usr/local/cuda
    export PATH=\$CUDA_HOME/bin:\$PATH
    export CUDA_LAUNCH_BLOCKING=1
    
    # Verify CUDA is accessible before venv creation
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Verifying CUDA accessibility..."
    ls -la /usr/local/cuda/lib64/ | head -5
    
    # Create virtual environment
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Creating virtual environment..."
    python3 -m venv .venv
    
    # Activate virtual environment
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Activating virtual environment..."
    source .venv/bin/activate
    
    # Reinstall CUDA environment variables in activated venv
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH
    export CUDA_HOME=/usr/local/cuda
    export PATH=\$CUDA_HOME/bin:\$PATH
    export CUDA_LAUNCH_BLOCKING=1
    
    # Upgrade pip and install wheel
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Upgrading pip and installing build tools..."
    pip install --upgrade pip setuptools wheel
    
    # Install Python requirements with explicit CUDA 12.1 support
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Installing Python requirements with CUDA 12.1 PyTorch..."
    pip install torch==2.1.2 torchvision==0.16.2 --index-url https://download.pytorch.org/whl/cu121
    pip install -r requirements.txt --no-deps
    
    # Install remaining requirements without forcing torch versions
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Installing remaining dependencies..."
    pip install click numpy pandas scipy tqdm opencv-python pillow scikit-image imgaug scikit-learn timm onnx onnxruntime-gpu onnxsim matplotlib tensorboard openpyxl pyserial psutil reportlab cuda-python
    
    # Run preprocessing
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Running preprocessing for $CLASS_NAME..."
    python preprocessing/orchestrator.py \
        --source raw-data/$CLASS_NAME/good-images \
        --dataset custom \
        --class_name $CLASS_NAME
    
    # Make shell scripts executable
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Making shell scripts executable..."
    chmod +x ./shell/*
    
    # Ensure CUDA environment is set up before training
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64:\$LD_LIBRARY_PATH
    export CUDA_HOME=/usr/local/cuda
    export PATH=\$CUDA_HOME/bin:\$PATH
    export CUDA_LAUNCH_BLOCKING=1
    
    # Detailed CUDA verification before training
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Detailed CUDA verification before training..."
    python << 'PYTHON_EOF'
import sys
import os
print(f"Python executable: {sys.executable}")
print(f"Python version: {sys.version}")
print(f"CUDA_HOME: {os.environ.get('CUDA_HOME', 'NOT SET')}")
print(f"LD_LIBRARY_PATH: {os.environ.get('LD_LIBRARY_PATH', 'NOT SET')}")

try:
    import torch
    print(f"PyTorch version: {torch.__version__}")
    print(f"PyTorch CUDA available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"CUDA device count: {torch.cuda.device_count()}")
        print(f"CUDA device name: {torch.cuda.get_device_name(0)}")
        print(f"CUDA device capability: {torch.cuda.get_device_capability(0)}")
        print("✓ CUDA is properly configured!")
    else:
        print("✗ CUDA not detected. This may cause training to fail.")
except Exception as e:
    print(f"✗ Error during CUDA verification: {e}")
    sys.exit(1)
PYTHON_EOF
    
    # Run the training script with library preload
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Starting training for $CLASS_NAME..."
    LD_PRELOAD=/usr/local/cuda/lib64/libcudart.so.12 ./shell/run-custom-training.sh "$CLASS_NAME"
    
    # Check training exit status
    if [ \$? -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Training completed successfully!"
        echo "TRAINING_SUCCESS" > /tmp/training_status.txt
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Training failed!"
        echo "TRAINING_FAILED" > /tmp/training_status.txt
    fi
EOF

# Sync training logs from droplet back to host
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Syncing training logs from droplet..."
rsync -avz \
    -e "ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_do_controller" \
    root@$DROPLET_IP:~/GLASS-new/results/training/$CLASS_NAME/ \
    /root/TrainingHost/GLASS-new/results/training/$CLASS_NAME/ 2>/dev/null || true

# Check training status
TRAINING_STATUS=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_do_controller root@$DROPLET_IP 'cat /tmp/training_status.txt 2>/dev/null || echo "TRAINING_FAILED"')

if [ "$TRAINING_STATUS" = "TRAINING_SUCCESS" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Training complete. Syncing results back..."
    
    # Rsync the GLASS-new folder back from the droplet (excluding venv and cache)
    rsync -avz --exclude='.venv/' --exclude='__pycache__/' --exclude='*.pyc' --exclude='.pytest_cache/' --exclude='.mypy_cache/' \
        -e "ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_do_controller" \
        root@$DROPLET_IP:~/GLASS-new/ /root/TrainingHost/GLASS-new/
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Results synced successfully. Destroying droplet..."
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Training failed! Check logs for details. Destroying droplet..."
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Training failed. No results to sync back."
fi

# Destroy Terraform infrastructure (from class-specific directory)
cd "$TERRAFORM_DIR"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Destroying Terraform infrastructure..."
terraform destroy -auto-approve

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleanup complete."