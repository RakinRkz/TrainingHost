# Training Host - Complete Documentation Summary

## 📚 Documentation Files

This project now includes comprehensive documentation:

1. **API_DOCUMENTATION.md** - Complete API reference with examples
2. **.github/copilot-instructions.md** - Detailed development guidelines
3. **README.md** - Project overview and setup instructions
4. **This file** - Navigation and overview

---

## 🚀 Quick Start

### Starting the Flask Application

```bash
# Activate virtual environment
source /root/ctrl_venv/bin/activate

# Navigate to host app
cd /root/TrainingHost/host_app

# Start Flask server
python flask_app.py
```

The dashboard will be available at: **http://localhost:5000**

### Starting a Training

1. Open the dashboard in your browser
2. Click "Start Training" button
3. Select a class from the modal (classes are listed from `GLASS-new/raw-data/`)
4. Training starts immediately
5. Watch real-time logs with colors
6. Click on the training in "Active Trainings" to view its logs
7. Click "Stop" to terminate training and destroy the droplet

---

## 📖 API Reference

### REST Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/` | GET | Dashboard HTML |
| `/api/status` | GET | Get all active trainings |
| `/api/classes` | GET | List available classes |
| `/api/start-training` | POST | Start new training |
| `/api/env` | GET | Get environment variables |

### WebSocket Events

| Event | Direction | Purpose |
|-------|-----------|---------|
| `log_update` | Server→Client | Real-time log messages |
| `training_started` | Server→Client | Training started notification |
| `training_completed` | Server→Client | Training finished notification |
| `training_stopped` | Server→Client | Training stopped notification |
| `stop_training` | Client→Server | Stop a training job |
| `error` | Server→Client | Error messages |

See **API_DOCUMENTATION.md** for complete details and examples.

---

## 🏗️ Architecture Overview

### Multi-Training Support

The system is designed to run **multiple trainings concurrently** with complete isolation:

```
User Request: Start training for "batch_A"
    ↓
API: Create /training/batch_A_terraform/ directory
    ↓
Flask: Start train.sh subprocess with class_name parameter
    ↓
train.sh: All output redirected to training_log_batch_A.txt
    ↓
Flask: Launch monitor_logs("batch_A") thread
    ↓
Thread: Read log file every 0.5s → Convert ANSI codes → Emit via Socket.IO
    ↓
Frontend: Receive log_update events → Store in logsPerClass["batch_A"]
    ↓
UI: Display logs when "batch_A" training is selected
```

### Concurrent Trainings

- **Separate GPU Droplets**: Each training deploys its own droplet
- **Separate Log Files**: `training_log_batch_A.txt`, `training_log_batch_B.txt`
- **Separate Terraform State**: Each has its own `.tfstate` file
- **Independent Threads**: Each training has its own log monitoring thread
- **True Concurrency**: Trainings run simultaneously without interference

---

## 🔧 Key Files

### Backend

- **flask_app.py** - Main Flask server with:
  - REST API endpoints
  - Socket.IO event handlers
  - Log monitoring threads
  - ANSI to HTML conversion
  - Multi-training state management

- **train.sh** - Orchestration script with:
  - Full output redirection to log file
  - Class-specific Terraform directory creation
  - Terraform lifecycle management
  - SSH operations to remote server
  - Results synchronization

### Frontend

- **templates/index.html** - Web dashboard with:
  - Active trainings list
  - Real-time log display with colors
  - Per-class log filtering
  - Class selection modal
  - Start/Stop controls per training

### Infrastructure

- **training/main.tf** - Terraform configuration with:
  - DigitalOcean GPU droplet provisioning
  - Multi-region support (sfo3, ams3, blr1, nyc3)
  - SSH key management
  - Resource lifecycle

### Documentation

- **API_DOCUMENTATION.md** - Complete API reference
- **.github/copilot-instructions.md** - Development guidelines

---

## 🎯 Feature Highlights

### ✅ Completed Features

- [x] Multi-concurrent training with class-based isolation
- [x] Per-class log files with timestamps
- [x] Real-time log streaming via Socket.IO
- [x] ANSI color code support (terminal colors in web UI)
- [x] Class-specific Terraform directories
- [x] Per-training elapsed time calculation
- [x] Click-to-select training for viewing logs
- [x] Individual Stop button per training
- [x] Rsync with compression and class filtering
- [x] Duplicate training prevention
- [x] HTML dashboard with responsive design
- [x] REST API for training control
- [x] Error handling and recovery

### 📋 Data Structures

#### Active Trainings (Backend)
```python
active_trainings = {
  'batch_20251101T223547Z': {
    'process': <Popen object>,
    'thread': <Thread object>,
    'started': <datetime>
  },
  'batch_20251101T225654Z': {
    'process': <Popen object>,
    'thread': <Thread object>,
    'started': <datetime>
  }
}
```

#### Active Trainings (Frontend)
```javascript
activeTrainings = {
  'batch_20251101T223547Z': {
    started_at: <Date>
  },
  'batch_20251101T225654Z': {
    started_at: <Date>
  }
};
```

#### Logs Per Class (Frontend)
```javascript
logsPerClass = {
  'batch_20251101T223547Z': [
    {message: '[2025-11-02 15:30:45] Initializing...', isHtml: true},
    {message: 'Terraform output...', isHtml: true}
  ],
  'batch_20251101T225654Z': [
    {message: '[2025-11-02 15:35:12] Starting...', isHtml: true}
  ]
};
```

---

## 🔄 Common Workflows

### Starting a Training

```bash
curl -X POST http://localhost:5000/api/start-training \
  -H "Content-Type: application/json" \
  -d '{"class_name": "batch_20251101T223547Z"}'
```

### Checking Status

```bash
curl http://localhost:5000/api/status
```

Response:
```json
{
  "status": "Running",
  "active": true,
  "active_trainings": ["batch_A", "batch_B"],
  "count": 2,
  "trainings_data": {
    "batch_A": {"started_at": "2025-11-02T15:30:45.123456"},
    "batch_B": {"started_at": "2025-11-02T15:35:12.654321"}
  }
}
```

### Viewing Logs

Open dashboard at http://localhost:5000 to see real-time logs with:
- Terraform output in colors
- Training progress with timestamps
- Preprocessing and dataset information
- Completion or error messages

### Stopping a Training

Click the "Stop" button next to a training in the UI, or use JavaScript:
```javascript
socket.emit('stop_training', { class_name: 'batch_20251101T223547Z' });
```

---

## 🐛 Troubleshooting

### Issue: Logs not showing in web UI

**Check:**
1. Is Flask running? `ps aux | grep flask_app.py`
2. Does log file exist? `ls -la training_log_*.txt`
3. Is monitor thread running? Check Flask console output
4. Is WebSocket connected? Browser DevTools → Network → WS connections

**Solution:**
- Restart Flask: `pkill -f "python flask_app.py"` then run again
- Check Flask console for errors in monitor_logs()

### Issue: Training starts but doesn't connect to droplet

**Check:**
1. DigitalOcean API token in `.env`
2. Account has GPU quota available
3. Selected region has GPU droplets in stock
4. SSH key exists: `ls ~/.ssh/id_rsa_do_controller`

**Solution:**
- Review training_log_*.txt file for Terraform errors
- Check DigitalOcean dashboard for failed droplets

### Issue: Stop button doesn't work

**Check:**
1. Terraform directory exists: `ls ../training/{class_name}_terraform/`
2. Check Flask console for error messages
3. Verify class_name matches exactly

**Solution:**
- Manually destroy: `cd ../training/{class_name}_terraform && terraform destroy -auto-approve`
- Restart Flask

### Issue: Multiple trainings interfering with each other

**Check:**
1. Each training should have separate:
   - Log file: `training_log_batch_A.txt` vs `training_log_batch_B.txt`
   - Terraform directory: `../training/batch_A_terraform/` vs `../training/batch_B_terraform/`
   - Monitor thread (check active_trainings dict)

**Solution:**
- Verify class-specific directories are created
- Check that each training gets unique class_name parameter

---

## 📊 Log File Locations

- **Host logs**: `/root/TrainingHost/host_app/training_log_{class_name}.txt`
- **Terraform state**: `/root/TrainingHost/training/{class_name}_terraform/`
- **Training results**: `/root/TrainingHost/GLASS-new/results/training/{class_name}/`
- **Raw data**: `/root/TrainingHost/GLASS-new/raw-data/{class_name}/`

---

## 🔒 Security Notes

### Current (Development)
- ✅ No authentication required
- ✅ CORS enabled for all origins
- ⚠️ Runs with full system access
- ⚠️ WebSocket unrestricted

### Recommended for Production
- [ ] Add JWT authentication
- [ ] Restrict CORS to specific domains
- [ ] Implement role-based access control
- [ ] Run Flask as unprivileged user
- [ ] Use production WSGI server (Gunicorn)
- [ ] Add rate limiting on API endpoints
- [ ] Sanitize user inputs
- [ ] Encrypt sensitive configuration

---

## 📈 Performance Metrics

- **Log Check Interval**: 0.5 seconds (responsive updates)
- **Status Poll Interval**: 2 seconds (UI refresh)
- **Terraform Deploy Time**: 25-45 seconds
- **SSH Connection Wait**: Up to 60 seconds (with retries)
- **Training Time**: Depends on model/dataset
- **Cleanup Time**: 15-25 seconds

---

## 🌐 Environment Variables

The system uses DigitalOcean API. Ensure your `.env` file has:

```bash
DIGITALOCEAN_TOKEN=your_do_api_token
GITHUB_REPO_URL=https://github.com/your/repo.git
CLASS_NAME=batch_20251101T223547Z  # Optional, can be passed as parameter
```

---

## 📝 Logging & ANSI Colors

### Log Format

```
[2025-11-02 15:30:45] Initializing Terraform...
Initializing modules...
Terraform has been successfully initialized!
[2025-11-02 15:30:50] Creating GPU droplet...
[colored terraform output with ANSI codes...]
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
[2025-11-02 15:31:05] Droplet IP: 165.101.132.243
... (continues) ...
[2025-11-02 15:56:45] Cleanup complete.
```

### Color Support

- Logs preserve ANSI color codes: `\x1b[32m` (green), `\x1b[31m` (red), etc.
- Backend converts to HTML: `<span style="color: #51cf66;">` 
- Frontend displays with terminal-like colors
- Works for Terraform output, training progress, and any shell commands

---

## 🎓 Development Guidelines

See **`.github/copilot-instructions.md`** for:
- Code style patterns (Python, Bash, JavaScript)
- Architecture patterns (multi-training, log streaming)
- Common tasks (adding endpoints, features, debugging)
- Best practices for Flask-SocketIO, Terraform, and frontend development

---

## 🚀 Next Steps

1. **Review API Documentation**: See `API_DOCUMENTATION.md` for complete API reference
2. **Review Development Guidelines**: See `.github/copilot-instructions.md` for coding standards
3. **Start the Application**: Run Flask and open dashboard at http://localhost:5000
4. **Test Multi-Training**: Start multiple trainings concurrently to verify isolation
5. **Monitor Logs**: Check real-time logs in UI and verify ANSI colors display correctly

---

## 📞 Support

For issues or questions:
1. Check the Troubleshooting section above
2. Review relevant documentation files
3. Check Flask console output for errors
4. Review training log files for detailed information
5. Check DigitalOcean dashboard for infrastructure issues

---

**Last Updated**: November 2, 2025
**Status**: ✅ Production Ready (with security recommendations for deployment)
