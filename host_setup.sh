#!/usr/bin/env bash
set -euo pipefail

### ====== Configuration (customize these) ======

# Where to place the SSH key that controller will use to access future GPU droplets
SSH_KEY_PATH="$HOME/.ssh/id_rsa_do_controller"

# Python version or virtual env folder — you can adjust
PYTHON_VERSION="3"
VENV_DIR="$HOME/ctrl_venv"

### ====== Script ======

echo "=== Updating system packages ==="
sudo apt update
sudo apt upgrade -y

echo "=== Installing required base packages ==="
sudo apt install -y \
  curl \
  wget \
  unzip \
  git \
  software-properties-common \
  python3-pip \
  python3-venv \
  openssh-client \
  ssh \
  jq

echo "=== Installing Terraform ==="
# Add HashiCorp GPG key
wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add HashiCorp repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

sudo apt update
sudo apt install -y terraform

echo "Terraform version installed: $(terraform version | head -n1)"

echo "=== Generating SSH key for controller → GPU droplets ==="
if [ ! -f "$SSH_KEY_PATH" ]; then
  ssh-keygen -t rsa -b 4096 -C "controller-gpu-ssh-key" -f "$SSH_KEY_PATH" -N ""
  echo "SSH key created at ${SSH_KEY_PATH} and public key at ${SSH_KEY_PATH}.pub"
else
  echo "SSH key already exists at $SSH_KEY_PATH — skipping generation"
fi

echo "=== Setting up Python virtual environment ==="
# Create directory for venv
mkdir -p "$(dirname "$VENV_DIR")"
python3 -m venv "$VENV_DIR"
# Activate it
# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"

echo "=== Upgrading pip & installing basic Python packages ==="
pip install --upgrade pip
# Install packages you will likely need for orchestration / web app
pip install streamlit \
            python-digitalocean \
            paramiko \
            pyyaml \
            fastapi \
            uvicorn

deactivate

echo "=== Setup complete ==="
echo "Next steps:"
echo "  1. Export your DigitalOcean API token as an environment variable, e.g.:"
echo "     export DIGITALOCEAN_TOKEN=\"<your-token-here>\""
echo "  2. Use the SSH key public key (${SSH_KEY_PATH}.pub) in your Terraform / scripts to register with your DO account."
echo "  3. Create or copy your orchestration and Streamlit app code here; you can activate the venv when running it."
echo "  4. Run your orchestration / web app manually (or via systemd / service) when you’re ready."
