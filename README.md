# TrainingHost 🚀

A complete GPU training automation system that provisions DigitalOcean GPU droplets, executes training jobs, and provides real-time monitoring through a web interface.

## 🎯 Overview

TrainingHost automatically:
- 🏗️ Provisions GPU droplets via Terraform
- 📦 Copies GLASS-new folder to GPU server
- 🔄 Executes training commands
- 📱 Provides real-time web monitoring
- 📋 Copies back the folder with trained parameters, models back to host server
- 🧹 Auto-destroys resources after completion

## 🏗️ Architecture

```
TrainingHost/
├── .github/           # GitHub-specific files
│   └── copilot-instructions.md  # AI assistant guidelines
├── host_app/          # Web interface and main application
│   ├── templates/     # Flask HTML templates
│   │   └── index.html # Web interface template
│   ├── flask_app.py   # Flask web interface
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
1. Put your DigitalOcean api key in training/terraform.tfvars
2. `cd host_app`
3. `chmod +x ./train.sh`
4. `./train.sh`
