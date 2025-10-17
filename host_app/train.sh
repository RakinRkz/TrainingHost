#!/bin/bash

# Script to deploy GPU droplet via Terraform and manage lifecycle

# Load environment variables
if [ -f "../host_app/.env" ]; then
    export $(grep -v '^#' ../host_app/.env | xargs)
fi

cd ../training

# Initialize Terraform
echo "Initializing Terraform..." > ../host_app/progress.txt
terraform init

# Apply the configuration
echo "Creating GPU droplet..." > ../host_app/progress.txt
terraform apply -auto-approve

# Get the droplet IP
DROPLET_IP=$(terraform output -raw droplet_ip)
echo "Droplet IP: $DROPLET_IP" >> ../host_app/progress.txt

# Wait for SSH to be ready
echo "Waiting for SSH to be ready..." > ../host_app/progress.txt
while ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ~/.ssh/id_rsa_do_controller root@$DROPLET_IP exit; do
    sleep 10
    echo "Still waiting for SSH..." >> ../host_app/progress.txt
done

echo "SSH ready. Syncing GLASS-new folder..." > ../host_app/progress.txt

# Rsync the GLASS-new folder to the droplet
rsync -av -e "ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_do_controller" /root/TrainingHost/GLASS-new root@$DROPLET_IP:~/

echo "Folder synced. Setting up environment..." > ../host_app/progress.txt

# SSH into droplet and set up environment
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_do_controller root@$DROPLET_IP << 'EOF'
    # Update system
    apt-get update -y
    
    # Install required system packages
    apt-get install -y python3-pip python3-venv git wget unzip
    
    # Navigate to the GLASS-new folder
    cd /root/GLASS-new
    
    # Create virtual environment
    echo "Creating virtual environment..."
    python3 -m venv .venv
    
    # Activate virtual environment
    echo "Activating virtual environment..."
    source .venv/bin/activate
    
    # Install Python requirements
    echo "Installing Python requirements..."
    pip install -r requirements.txt
    
    # Run preprocessing
    # echo "Running preprocessing..."
    # python preprocessing/orchestrator.py \
    #     --source raw-data/mvt2/good-images \
    #     --dataset custom \
    #     --class_name mvt2
    
    # Make shell scripts executable
    echo "Making shell scripts executable..."
    chmod +x ./shell/*
    
    # Run the training script
    echo "Starting training..."
    ./shell/run-custom-training.sh
    
    # Check training exit status
    if [ $? -eq 0 ]; then
        echo "TRAINING_SUCCESS" > /tmp/training_status.txt
    else
        echo "TRAINING_FAILED" > /tmp/training_status.txt
    fi
EOF

# Check training status
TRAINING_STATUS=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_do_controller root@$DROPLET_IP 'cat /tmp/training_status.txt 2>/dev/null || echo "TRAINING_FAILED"')

if [ "$TRAINING_STATUS" = "TRAINING_SUCCESS" ]; then
    echo "Training complete. Syncing results back..." > ../host_app/progress.txt
    
    # Rsync the GLASS-new folder back from the droplet (excluding venv and cache)
    rsync -av --exclude='.venv/' --exclude='__pycache__/' --exclude='*.pyc' --exclude='.pytest_cache/' --exclude='.mypy_cache/' \
        -e "ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_do_controller" \
        root@$DROPLET_IP:~/GLASS-new/ /root/TrainingHost/GLASS-new/
    
    echo "Results synced successfully. Destroying droplet..." > ../host_app/progress.txt
else
    echo "❌ Training failed! Check logs for details. Destroying droplet..." > ../host_app/progress.txt
    echo "Training failed. No results to sync back." >> ../host_app/progress.txt
fi
terraform destroy -auto-approve

echo "Cleanup complete." > ../host_app/progress.txt