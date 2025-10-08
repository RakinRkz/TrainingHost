# TrainingHost 🚀

A complete GPU training automation system that provisions DigitalOcean GPU droplets, executes training jobs, and provides real-time monitoring through a web interface.

## 🎯 Overview

TrainingHost automatically:
- 🏗️ Provisions GPU droplets via Terraform
- 📦 Clones your GitHub repository
- 📊 Downloads datasets from any URL
- 🔄 Executes training commands
- 📱 Provides real-time web monitoring
- 🧹 Auto-destroys resources after completion

## 🏗️ Architecture

```
TrainingHost/
├── .github/           # GitHub-specific files
│   └── copilot-instructions.md  # AI assistant guidelines
├── host_app/          # Web interface and main application
│   ├── templates/     # Flask HTML templates
│   │   └── index.html # Web interface template
│   ├── app.py         # Streamlit web interface
│   ├── flask_app.py   # Alternative Flask interface
│   ├── train.sh       # Main training orchestration script
│   ├── start_web.sh   # Web interface launcher script
│   ├── .env           # Configuration (GitHub repo, dataset, commands)
│   ├── .env.example   # Example environment configuration
│   ├── progress.txt   # Real-time training progress
│   └── requirements.txt # Python dependencies
├── training/          # Terraform infrastructure
│   ├── main.tf        # DigitalOcean GPU droplet configuration
│   ├── terraform.tfvars # Terraform variables
│   └── *.tfstate      # Terraform state files
├── .gitignore         # Git ignore patterns
├── CHANGELOG.md       # Version history and release notes
├── CONTRIBUTING.md    # Contribution guidelines
├── LICENSE            # MIT License
├── README.md          # This file - project documentation
└── host_setup.sh      # Initial setup script
```

## 🚀 Quick Start

### 1. Prerequisites

- DigitalOcean account with GPU quota
- SSH key pair for DigitalOcean
- Python 3.8+
- Terraform installed

### 2. Initial Setup

```bash
# Clone the repository
git clone https://github.com/RakinRkz/TrainingHost.git
cd TrainingHost

# Run initial setup
chmod +x host_setup.sh
./host_setup.sh
```

### 3. Configure Environment

Edit `host_app/.env` with your settings:

```bash
# GitHub repository to clone
GITHUB_REPO_URL=https://github.com/yourusername/your-training-repo.git

# Dataset URL to download (supports zip, tar.gz, etc.)
DATASET_URL=https://huggingface.co/datasets/your-dataset/resolve/main/data.zip

# Command to execute after setup (can chain multiple commands with &&)
EXECUTE_COMMAND=pip install -r requirements.txt && python train.py --epochs 10
```

### 4. Set up DigitalOcean

```bash
# Set your DigitalOcean token
export DO_TOKEN="your_digitalocean_token"

# Ensure SSH key exists
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_do_controller
```

### 5. Launch Training

```bash
cd host_app

# Option 1: Use the launcher script (easiest)
./start_web.sh

# Option 2: Streamlit interface directly
streamlit run app.py

# Option 3: Flask interface directly
python flask_app.py

# Option 4: Direct command line training
./train.sh
```

## 🖥️ Web Interface Features

### Streamlit Interface (Default)
- 📊 Real-time progress monitoring
- 📈 Training metrics visualization
- 🔄 Auto-refreshing status updates
- 📋 Complete training logs
- ⚡ Start/stop training controls

### Flask Interface (Alternative)
- 🌐 Traditional web interface
- 📱 Mobile-responsive design
- 🔄 AJAX real-time updates
- 📊 Status dashboard
- 💾 Downloadable logs

## ⚙️ Configuration

### Environment Variables (.env)

| Variable | Description | Example |
|----------|-------------|---------|
| `GITHUB_REPO_URL` | Repository to clone | `https://github.com/user/repo.git` |
| `DATASET_URL` | Dataset download URL | `https://example.com/data.zip` |
| `EXECUTE_COMMAND` | Commands to run | `pip install -r requirements.txt && python train.py` |

### Terraform Variables (terraform.tfvars)

```hcl
do_token = "your_digitalocean_token"
```

### GPU Instance Configuration

Default configuration in `training/main.tf`:
- **Instance**: `gpu-h100x1-80gb` (H100 80GB GPU)
- **Region**: `ams3` (Amsterdam)
- **Base Image**: `gpu-h100x1-base`

## 📊 Monitoring & Logs

### Real-time Status Files

- `progress.txt` - Current operation status
- `training_log.txt` - Detailed training logs
- `error_log.txt` - Error messages and debugging info

### Log Levels

- **INFO**: General progress updates
- **SUCCESS**: Completed operations
- **ERROR**: Failures and issues
- **DEBUG**: Detailed debugging information

## 🔧 Advanced Usage

### Custom Training Scripts

Your training repository should include:

```
your-training-repo/
├── requirements.txt    # Python dependencies
├── train.py           # Main training script
├── data/              # Data processing scripts
└── models/            # Model definitions
```

### Multi-step Training Pipeline

```bash
# Example complex execute command
EXECUTE_COMMAND="pip install -r requirements.txt && python preprocess.py && python train.py --epochs 50 && python evaluate.py"
```

### Custom GPU Configuration

Modify `training/main.tf` for different GPU types:

```hcl
resource "digitalocean_droplet" "gpu_training" {
  name     = "gpu-training-droplet"
  region   = "ams3"
  size     = "gpu-h100x8-640gb"  # 8x H100 GPUs
  image    = "gpu-h100x1-base"
  ssh_keys = [digitalocean_ssh_key.controller.id]
}
```

## 🛠️ Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   ```bash
   # Check SSH key permissions
   chmod 600 ~/.ssh/id_rsa_do_controller
   chmod 644 ~/.ssh/id_rsa_do_controller.pub
   ```

2. **Terraform Apply Failed**
   ```bash
   # Check DigitalOcean token
   echo $DO_TOKEN
   
   # Verify GPU quota
   doctl compute droplet-action list
   ```

3. **Training Script Failed**
   - Check `error_log.txt` for details
   - Verify repository URL and credentials
   - Ensure dataset URL is accessible

### Debug Mode

Enable verbose logging:

```bash
export DEBUG=1
./train.sh
```

## 🔒 Security Considerations

- Store DigitalOcean tokens securely
- Use SSH key authentication only
- Review `.gitignore` for sensitive files
- Regularly rotate access tokens

## 📈 Cost Management

- GPU instances are expensive ($2-10/hour)
- Auto-destruction after 2 minutes (configurable)
- Monitor usage via DigitalOcean dashboard
- Set up billing alerts

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📜 License

MIT License - see LICENSE file for details

## 🆘 Support

- 📧 Email: rakinrkz@github.com
- 🐛 Issues: [GitHub Issues](https://github.com/RakinRkz/TrainingHost/issues)
- 📖 Wiki: [Project Wiki](https://github.com/RakinRkz/TrainingHost/wiki)

## 🎯 Roadmap

- [ ] Multi-cloud support (AWS, GCP)
- [ ] Distributed training across multiple GPUs
- [ ] Training result artifacts storage
- [ ] Slack/Discord notifications
- [ ] Cost optimization features
- [ ] Training scheduling system

---

⭐ **Star this repository if it helped you!**