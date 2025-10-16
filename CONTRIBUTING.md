# Contributing to TrainingHost 🤝

Thank you for your interest in contributing to TrainingHost! This document provides guidelines and information for contributors.

## 🎯 How to Contribute

### 🐛 Reporting Bugs

1. **Check existing issues** first to avoid duplicates
2. **Use the bug report template** when creating new issues
3. **Include detailed information**:
   - OS and Python version
   - Terraform version
   - Complete error messages
   - Steps to reproduce
   - Expected vs actual behavior

### ✨ Suggesting Features

1. **Check the roadmap** in README.md first
2. **Create a feature request** with:
   - Clear description of the feature
   - Use case and benefits
   - Possible implementation approach
   - Backward compatibility considerations

### 🔧 Code Contributions

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature-name`
3. **Make your changes** following our coding standards
4. **Test thoroughly** including edge cases
5. **Update documentation** as needed
6. **Submit a pull request**

## 🏗️ Development Setup

### Prerequisites

```bash
# Required tools
python >= 3.8
terraform >= 1.0
git
docker (optional, for testing)

# Python packages
pip install -r host_app/requirements.txt
pip install -r requirements-dev.txt  # Development dependencies
```

### Local Development

```bash
# Clone your fork
git clone https://github.com/yourusername/TrainingHost.git
cd TrainingHost

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
# or
venv\Scripts\activate     # Windows

# Install dependencies
pip install -r host_app/requirements.txt

# Set up pre-commit hooks
pre-commit install
```

### Environment Configuration

Create a development `.env` file:

```bash
# Development environment
GITHUB_REPO_URL=https://github.com/yourusername/test-training-repo.git
DATASET_URL=https://httpbin.org/base64/ZGF0YQ==  # Small test data
EXECUTE_COMMAND=echo "Training simulation complete"
DEBUG=1
```

## 📝 Coding Standards

### Python Style

- **Follow PEP 8** with 88-character line limit
- **Use type hints** for function parameters and returns
- **Add docstrings** for public functions and classes
- **Use f-strings** for string formatting
- **Import organization**: standard library, third-party, local imports

```python
```python
# Good example
from pathlib import Path
from typing import Optional
import logging

from flask import Flask, render_template
import flask_socketio

from utils.helpers import update_progress


def start_training(repo_url: str, dataset_url: str) -> Optional[str]:
    """Start the training process with given parameters.
    
    Args:
        repo_url: GitHub repository URL to clone
        dataset_url: URL to download dataset from
        
    Returns:
        Process ID if successful, None if failed
        
    Raises:
        ValueError: If URLs are invalid
        ConnectionError: If network operations fail
    """
    if not repo_url.startswith(('http://', 'https://')):
        raise ValueError(f"Invalid repository URL: {repo_url}")
    
    logging.info(f"Starting training with repo: {repo_url}")
    update_progress("Initializing training process")
    
    # Implementation here
    return process_id
```

### Bash Script Style

- **Use `set -e`** for error handling
- **Quote variables** to prevent word splitting
- **Use `local`** for function variables
- **Include error messages** with line numbers

```bash
#!/bin/bash
set -e  # Exit on error
set -u  # Exit on undefined variable

# Function example
update_progress() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${message}" > progress.txt
    echo "[${timestamp}] ${message}" >> training_log.txt
}

# Error handling example
if ! command -v terraform &> /dev/null; then
    echo "ERROR: Terraform is not installed" >&2
    exit 1
fi
```

### Terraform Style

- **Use consistent naming** with underscores
- **Add descriptions** to variables and outputs
- **Include tags** for resource organization
- **Use data sources** for external references

```hcl
variable "instance_type" {
  description = "GPU instance type for training"
  type        = string
  default     = "gpu-h100x1-80gb"
  
  validation {
    condition     = contains(["gpu-h100x1-80gb", "gpu-h100x8-640gb"], var.instance_type)
    error_message = "Instance type must be a valid GPU instance."
  }
}

resource "digitalocean_droplet" "training" {
  name   = "training-${random_id.suffix.hex}"
  region = var.region
  size   = var.instance_type
  image  = var.base_image
  
  tags = [
    "environment:${var.environment}",
    "project:traininghost",
    "managed-by:terraform"
  ]
}

output "instance_ip" {
  description = "Public IP address of the training instance"
  value       = digitalocean_droplet.training.ipv4_address
  sensitive   = false
}
```

## 🧪 Testing

### Running Tests

```bash
# Unit tests
python -m pytest tests/ -v

# Integration tests (requires setup)
python -m pytest tests/integration/ -v

# Linting
flake8 host_app/
black --check host_app/
mypy host_app/

# Terraform validation
cd training/
terraform fmt -check
terraform validate
```

### Test Categories

1. **Unit Tests**: Individual function testing
2. **Integration Tests**: Component interaction testing
3. **End-to-End Tests**: Full workflow testing (expensive, run sparingly)

### Test Structure

```python
# tests/test_training.py
import pytest
from unittest.mock import patch, MagicMock

from host_app.training import start_training, update_progress


class TestTraining:
    
    def test_start_training_valid_input(self):
        """Test training start with valid parameters."""
        result = start_training(
            repo_url="https://github.com/test/repo.git",
            dataset_url="https://example.com/data.zip"
        )
        assert result is not None
    
    def test_start_training_invalid_url(self):
        """Test training start with invalid repository URL."""
        with pytest.raises(ValueError, match="Invalid repository URL"):
            start_training(
                repo_url="invalid-url",
                dataset_url="https://example.com/data.zip"
            )
    
    @patch('builtins.open')
    def test_update_progress(self, mock_open):
        """Test progress update functionality."""
        update_progress("Test message")
        mock_open.assert_called()
```

## 📚 Documentation

### Code Documentation

- **Docstrings**: Use Google-style docstrings
- **Comments**: Explain why, not what
- **Type hints**: For better IDE support
- **README updates**: For new features or changes

### Documentation Structure

```
docs/
├── api/              # API documentation
├── guides/           # User guides and tutorials
├── development/      # Development documentation
└── examples/         # Code examples and use cases
```

## 🔄 Pull Request Process

### Before Submitting

1. **Update your fork**: `git pull upstream main`
2. **Run tests**: Ensure all tests pass
3. **Update documentation**: If adding features
4. **Check formatting**: Run linters and formatters
5. **Squash commits**: For clean history

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No new warnings introduced
```

### Review Process

1. **Automated checks** must pass
2. **Code review** by maintainers
3. **Testing** in development environment
4. **Approval** by at least one maintainer
5. **Merge** when all checks pass

## 🏷️ Release Process

### Version Numbering

We use [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

### Release Checklist

1. Update version numbers
2. Update CHANGELOG.md
3. Run full test suite
4. Create release notes
5. Tag release: `git tag v1.0.0`
6. Push tags: `git push --tags`

## 🎯 Areas for Contribution

### High Priority
- [ ] Multi-cloud support (AWS, GCP)
- [ ] Enhanced error handling and recovery
- [ ] Training cost optimization
- [ ] Performance monitoring and metrics

### Medium Priority
- [ ] Web UI improvements
- [ ] Additional dataset sources
- [ ] Training scheduling system
- [ ] Notification integrations

### Good First Issues
- [ ] Documentation improvements
- [ ] Code style fixes
- [ ] Test coverage expansion
- [ ] Example implementations

## 💬 Communication

- **Discussions**: Use GitHub Discussions for questions
- **Issues**: Use GitHub Issues for bugs and features
- **Slack**: Join our community Slack (link in README)
- **Email**: Contact maintainers directly for security issues

## 🙏 Recognition

Contributors will be:
- Added to CONTRIBUTORS.md
- Mentioned in release notes
- Invited to maintainer team (for significant contributions)

Thank you for contributing to TrainingHost! 🚀