# GitHub Copilot Instructions for TrainingHost

This project is a GPU training automation system built with Python, Terraform, and web interfaces. Here are the key guidelines for GitHub Copilot to provide better assistance:

## 🏗️ Project Architecture

- **Backend**: Python with Flask web interfaces
- **Infrastructure**: Terraform for DigitalOcean GPU droplets
- **Orchestration**: Bash scripts for automation
- **Monitoring**: Real-time log files and web dashboards

## 🎯 Code Style & Patterns

### Python Code
- Use Python 3.8+ features
- Follow PEP 8 style guidelines
- Use type hints where beneficial
- Prefer f-strings for string formatting
- Use pathlib for file operations when possible

```python
# Preferred patterns
from pathlib import Path
import logging

def update_progress(status: str, log_file: Path = Path("progress.txt")) -> None:
    """Update progress with timestamp and logging."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    message = f"[{timestamp}] {status}"
    
    with log_file.open("w") as f:
        f.write(message)
    logging.info(status)
```

### Bash Scripts
- Use `set -e` for error handling
- Add progress logging to progress.txt
- Use environment variables from .env files
- Include error checking for external commands

```bash
# Preferred patterns
set -e  # Exit on error

# Load environment variables
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Log progress
echo "Operation starting..." > progress.txt
```

### Terraform
- Use clear resource naming
- Include outputs for important values
- Add descriptions to variables
- Use data sources when appropriate

```hcl
# Preferred patterns
resource "digitalocean_droplet" "gpu_training" {
  name     = "gpu-training-${random_id.suffix.hex}"
  region   = var.region
  size     = var.gpu_size
  image    = var.base_image
  ssh_keys = [digitalocean_ssh_key.controller.id]
  
  tags = ["training", "gpu", "automated"]
}

output "droplet_ip" {
  description = "Public IP address of the GPU droplet"
  value       = digitalocean_droplet.gpu_training.ipv4_address
}
```

## 🔧 Key Components

### 1. Training Orchestration (`train.sh`)
- Manages complete lifecycle: provision → setup → train → destroy
- Logs all operations to progress.txt and training_log.txt
- Handles SSH connections and remote command execution
- Includes error handling and cleanup

### 2. Web Interfaces
- **Flask** (`flask_app.py`): Traditional web interface with AJAX
- Both should provide: progress monitoring, log viewing, training controls

### 3. Infrastructure (`main.tf`)
- DigitalOcean GPU droplet provisioning
- SSH key management
- Networking and security configuration
- Cost-optimized resource sizing

## 📊 Monitoring & Logging

### Log Files Structure
```
progress.txt      # Current status (single line, overwritten)
training_log.txt  # Detailed training logs (appended)
error_log.txt     # Error messages and debugging (appended)
```

### Log Format
```
[YYYY-MM-DD HH:MM:SS] [LEVEL] Message
```

### Progress States
- `INITIALIZING` - Setting up infrastructure
- `PROVISIONING` - Creating GPU droplet
- `CONNECTING` - Establishing SSH connection
- `PREPARING` - Installing dependencies
- `DOWNLOADING` - Fetching repository and dataset
- `TRAINING` - Executing training commands
- `COMPLETING` - Finalizing training
- `DESTROYING` - Cleaning up resources
- `COMPLETE` - All operations finished
- `ERROR` - Something went wrong

## 🌐 Web Interface Guidelines

### Flask Best Practices
- Use templates for HTML rendering
- Implement AJAX for real-time updates
- Include proper error handling
- Use Flask sessions for state management

## 🔒 Security Considerations

### SSH Keys
- Use dedicated SSH keys for DigitalOcean
- Store private keys securely
- Never commit private keys to version control

### Environment Variables
- Use .env files for configuration
- Never commit sensitive data
- Validate environment variables on startup

### API Tokens
- Use secure token storage
- Implement token rotation
- Add proper error handling for authentication

## 🚀 Performance Optimization

### Resource Management
- Auto-destroy expensive GPU instances
- Implement proper timeout handling
- Use background processes for long-running tasks

### Code Efficiency
- Use generators for large file processing
- Implement proper caching where beneficial
- Minimize external API calls

## 🧪 Testing Patterns

### Unit Tests
```python
import pytest
from unittest.mock import patch, mock_open

def test_update_progress():
    with patch("builtins.open", mock_open()) as mock_file:
        update_progress("Test message")
        mock_file.assert_called_once()
```

### Integration Tests
- Test SSH connections with mock servers
- Validate Terraform configurations
- Test web interface endpoints

## 🔄 Common Patterns

### Environment Loading
```python
from dotenv import load_dotenv
import os

load_dotenv()
github_repo = os.getenv('GITHUB_REPO_URL')
```

### SSH Command Execution
```bash
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_do_controller root@$DROPLET_IP << 'EOF'
    # Commands here
EOF
```

### Progress Updates
```python
def update_progress(status: str, level: str = "INFO"):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    message = f"[{timestamp}] [{level}] {status}"
    
    # Update current status
    with open("progress.txt", "w") as f:
        f.write(status)
    
    # Append to detailed log
    with open("training_log.txt", "a") as f:
        f.write(f"{message}\n")
```

## 🎯 Suggestions for Copilot

When suggesting code:
1. **Always include error handling** for external operations
2. **Add logging/progress updates** for user-facing operations
3. **Use environment variables** instead of hardcoded values
4. **Include type hints** for Python functions
5. **Add docstrings** for complex functions
6. **Consider resource cleanup** in error scenarios
7. **Use secure patterns** for SSH and API operations
8. **Implement proper validation** for user inputs

## 🔍 Common Use Cases

1. **Adding new cloud providers**: Extend Terraform configuration
2. **New training frameworks**: Update execute commands and dependencies
3. **Enhanced monitoring**: Add new log files and web interface features
4. **Cost optimization**: Implement smart resource scheduling
5. **Multi-GPU support**: Extend infrastructure and training scripts

Remember: This system handles expensive GPU resources, so always prioritize safety, cost control, and proper cleanup in suggestions!