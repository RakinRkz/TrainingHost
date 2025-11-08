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
    
    # Navigate to the GLASS-new folder
    cd /root/GLASS-new
    
    # Create virtual environment
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Creating virtual environment..."
    python3 -m venv .venv
    
    # Activate virtual environment
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Activating virtual environment..."
    source .venv/bin/activate
    
    # Install Python requirements
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Installing Python requirements..."
    pip install -r requirements.txt
    
    # Run preprocessing
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Running preprocessing for $CLASS_NAME..."
    python preprocessing/orchestrator.py \
        --source raw-data/$CLASS_NAME/good-images \
        --dataset custom \
        --class_name $CLASS_NAME
    
    # Make shell scripts executable
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Making shell scripts executable..."
    chmod +x ./shell/*
    
    # Run the training script
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [REMOTE] Starting training for $CLASS_NAME..."
    ./shell/run-custom-training.sh "$CLASS_NAME"
    
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