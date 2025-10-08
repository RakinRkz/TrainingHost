#!/bin/bash

# Script to deploy GPU droplet via Terraform and manage lifecycle

# Function to log to both files
log_message() {
    echo "$1" > ../host_app/progress.txt
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> ../host_app/training_log.txt
}

# Load environment variables
if [ -f "../host_app/.env" ]; then
    export $(grep -v '^#' ../host_app/.env | xargs)
    log_message "Environment variables loaded"
else
    log_message "ERROR: No .env file found"
    exit 1
fi

cd ../training

# Initialize Terraform
log_message "Initializing Terraform..."
if terraform init >> ../host_app/training_log.txt 2>&1; then
    log_message "SUCCESS: Terraform initialized"
else
    log_message "ERROR: Terraform initialization failed"
    exit 1
fi

# Apply the configuration
log_message "Creating GPU droplet..."
if terraform apply -auto-approve >> ../host_app/training_log.txt 2>&1; then
    log_message "SUCCESS: GPU droplet created"
else
    log_message "ERROR: Failed to create GPU droplet"
    exit 1
fi

# Get the droplet IP
DROPLET_IP=$(terraform output -raw droplet_ip 2>/dev/null)
if [ -z "$DROPLET_IP" ]; then
    log_message "ERROR: Could not get droplet IP"
    exit 1
fi

log_message "Droplet IP: $DROPLET_IP"

# Wait for SSH to be ready
log_message "Waiting for SSH to be ready..."
retry_count=0
max_retries=30

while ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ~/.ssh/id_rsa_do_controller root@$DROPLET_IP exit 2>/dev/null; do
    retry_count=$((retry_count + 1))
    if [ $retry_count -ge $max_retries ]; then
        log_message "ERROR: SSH connection timeout after $max_retries attempts"
        terraform destroy -auto-approve >> ../host_app/training_log.txt 2>&1
        exit 1
    fi
    sleep 10
    log_message "SSH attempt $retry_count/$max_retries - Still waiting..."
done

log_message "SUCCESS: SSH connection established"
log_message "Setting up environment on remote server..."

# SSH into droplet and set up environment
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_do_controller root@$DROPLET_IP << EOF 2>&1 | while read line; do echo "\$(date '+%Y-%m-%d %H:%M:%S') - REMOTE: \$line" >> ../host_app/training_log.txt; done
    echo "Starting system update..."
    apt-get update -y
    
    echo "Installing required packages..."
    apt-get install -y git wget unzip python3-pip
    
    echo "Cloning repository: $GITHUB_REPO_URL"
    cd /root
    if git clone $GITHUB_REPO_URL repo; then
        echo "SUCCESS: Repository cloned"
        cd repo
        
        echo "Downloading dataset: $DATASET_URL"
        if wget -O dataset.zip $DATASET_URL; then
            echo "SUCCESS: Dataset downloaded"
            
            if [[ $DATASET_URL == *.zip ]]; then
                echo "Extracting ZIP dataset..."
                unzip -q dataset.zip
            elif [[ $DATASET_URL == *.tar.gz ]] || [[ $DATASET_URL == *.tgz ]]; then
                echo "Extracting TAR.GZ dataset..."
                tar -xzf dataset.zip
            fi
            echo "SUCCESS: Dataset extracted"
            
            echo "Executing training command: $EXECUTE_COMMAND"
            eval $EXECUTE_COMMAND
            echo "SUCCESS: Training command completed"
        else
            echo "ERROR: Failed to download dataset"
            exit 1
        fi
    else
        echo "ERROR: Failed to clone repository"
        exit 1
    fi
EOF

if [ $? -eq 0 ]; then
    log_message "SUCCESS: Training completed successfully"
else
    log_message "ERROR: Training failed on remote server"
fi

log_message "Training complete. Starting 2-minute countdown before destruction..."

# Countdown 120 seconds
for i in {120..1}; do
    log_message "Countdown: $i seconds remaining"
    sleep 1
done

# Destroy the droplet
log_message "Destroying droplet..."
if terraform destroy -auto-approve >> ../host_app/training_log.txt 2>&1; then
    log_message "SUCCESS: Droplet destroyed"
else
    log_message "WARNING: Issues during droplet destruction"
fi

log_message "Cleanup complete."