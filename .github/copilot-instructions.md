# GitHub Copilot Instructions for TrainingHost

This project is a GPU training automation system with a comprehensive web dashboard. Here are the key guidelines for GitHub Copilot to provide better assistance:

## 🏗️ Project Architecture

- **Backend**: Python Flask with Flask-SocketIO for real-time communication
- **Frontend**: HTML5/CSS3/JavaScript with Socket.IO client
- **Infrastructure**: Terraform for DigitalOcean GPU droplets (multi-region support)
- **Orchestration**: Bash scripts (train.sh) for lifecycle management
- **Data Sync**: Rsync with class-specific filtering and compression
- **Logging**: Per-class timestamped logs with ANSI color code support

## 📊 System Features

### Multi-Training Support
- Run multiple training jobs concurrently (different classes only)
- Each training gets its own:
  - GPU droplet on DigitalOcean
  - Terraform working directory for state management
  - Timestamped log file with ANSI colors preserved
  - Independent log monitoring thread
  - Individual stop/control button in UI

### Real-Time Web Dashboard
- Active trainings list with elapsed time tracking
- Per-class log viewing with color syntax highlighting
- Click-to-select training to view its logs
- Individual Start/Stop controls per training
- Automatic UI updates every 2 seconds

### API Architecture
- **REST Endpoints**: `/api/start-training`, `/api/status`, `/api/classes`, `/api/env`
- **WebSocket Events**: `log_update`, `training_started`, `training_completed`, `training_stopped`, `stop_training`
- **Request Format**: JSON with class_name parameter
- **Response Format**: JSON with success/error status and messages

## 🎯 Code Style & Patterns

### Python Code (Flask)
- Python 3.8+ with type hints where beneficial
- PEP 8 compliant
- Use f-strings for formatting
- Use pathlib for file operations

```python
# Preferred patterns
from pathlib import Path
from datetime import datetime
import logging

def monitor_logs(class_name: str) -> None:
    """Monitor training logs for a specific class and emit to clients"""
    log_file = f"training_log_{class_name}.txt"
    last_log_position = 0
    
    while class_name in active_trainings:
        if os.path.exists(log_file):
            with open(log_file, "r") as f:
                f.seek(0, 2)  # Seek to end
                file_size = f.tell()
                
                if file_size > last_log_position:
                    f.seek(last_log_position)
                    new_content = f.read()
                    # Process and emit...
                    last_log_position = f.tell()
        
        time.sleep(0.5)
```

### Flask-SocketIO Patterns
- Use `socketio.emit(..., namespace='/')` from routes (no `broadcast=True`)
- Use `emit(..., broadcast=True)` from event handlers only
- Always include `class_name` in event data for multi-training support
- Use `namespace='/'` parameter for consistency

```python
# From Flask route (API endpoint)
@app.route('/api/start-training', methods=['POST'])
def start_training_api():
    socketio.emit('training_started', {'class_name': class_name}, namespace='/')

# From Socket.IO event handler
@socketio.on('stop_training')
def handle_stop_training(data):
    emit('training_stopped', {'class_name': class_name}, broadcast=True)
```

### Bash Scripts (train.sh)
- Redirect all output to log file: `exec 1> >(tee -a "$LOG_FILE")`
- Use class-specific Terraform directories: `TERRAFORM_DIR="../training/${CLASS_NAME}_terraform"`
- Log with timestamps: `echo "[$(date '+%Y-%m-%d %H:%M:%S')] Message..."`
- Capture SSH remote output via heredoc (unquoted EOF for variable expansion)

```bash
#!/bin/bash

CLASS_NAME="${1}"
LOG_FILE="training_log_${CLASS_NAME}.txt"

# Redirect ALL output to log file AND terminal
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

# Create class-specific working directory
TERRAFORM_DIR="../training/${CLASS_NAME}_terraform"
mkdir -p "$TERRAFORM_DIR"

# SSH with output capture (unquoted EOF)
ssh -o StrictHostKeyChecking=no root@$DROPLET_IP << EOF
    echo "[REMOTE] Starting remote process..."
    # Commands here can use $CLASS_NAME
EOF
```

### Frontend JavaScript
- Use class_name consistently in all data structures
- Maintain per-class log arrays: `logsPerClass[className] = [{message, isHtml}]`
- Track selected training: `selectedTrainingClass`
- Convert ANSI codes to HTML using backend helper

```javascript
// Data structure for logs per class
let logsPerClass = {
  'batch_20251101T223547Z': [
    {message: '[2025-11-02 15:30:45] Starting...', isHtml: true},
    {message: '[REMOTE] Initializing...', isHtml: true}
  ]
};

// Active trainings tracking
let activeTrainings = {
  'batch_20251101T223547Z': {started_at: new Date(...)}
};

// Socket event with class awareness
socket.on('log_update', function(data) {
  if (!logsPerClass[data.class_name]) {
    logsPerClass[data.class_name] = [];
  }
  logsPerClass[data.class_name].push({
    message: data.message,
    isHtml: data.is_html || false
  });
  
  if (selectedTrainingClass === data.class_name) {
    addLogLine(data.message, '', data.is_html);
  }
});
```

## 🔑 Key Components

### 1. train.sh (`/root/TrainingHost/host_app/train.sh`)
- Main orchestration script for single training job
- Takes CLASS_NAME as parameter
- Redirects all output to `training_log_{CLASS_NAME}.txt`
- Creates class-specific Terraform directory
- Manages full lifecycle: Terraform → SSH setup → Training → Sync results → Cleanup

### 2. flask_app.py (`/root/TrainingHost/host_app/flask_app.py`)
- Flask server with Socket.IO for real-time events
- Global `active_trainings` dict tracking: `{ class_name: { 'process': Popen, 'thread': Thread, 'started': datetime } }`
- `monitor_logs(class_name)` function: reads per-class log file, converts ANSI to HTML, emits updates
- REST endpoints: `/api/start-training`, `/api/status`, `/api/classes`
- Socket.IO handlers: `stop_training` event listener
- ANSI→HTML conversion with color mapping

### 3. index.html (`/root/TrainingHost/host_app/templates/index.html`)
- Dashboard UI with "Active Trainings" card
- Per-training elapsed time calculation
- Click-to-select training for viewing its logs
- Individual Start/Stop buttons per training
- Real-time log display with color syntax highlighting
- Modal for class selection before starting training

### 4. main.tf (`/root/TrainingHost/training/main.tf`)
- Terraform configuration for DigitalOcean GPU droplets
- Multi-region support (sfo3, ams3, blr1, nyc3) with fallback
- SSH key management
- Resource outputs: droplet_ip, droplet_region

### 5. Preprocessing (`/root/TrainingHost/GLASS-new/preprocessing/`)
- orchestrator.py: Handles data preparation
- Called with `--source raw-data/{CLASS_NAME}/good-images --class_name {CLASS_NAME}`

## 📊 Multi-Training Architecture

### Concurrent Execution
```
Request 1: POST /api/start-training {class: "batch_A"}
  ├─ Creates ../training/batch_A_terraform/
  ├─ Starts subprocess: train.sh batch_A
  ├─ Launches monitor_logs("batch_A") thread
  └─ Adds to active_trainings["batch_A"]

Request 2: POST /api/start-training {class: "batch_B"}
  ├─ Creates ../training/batch_B_terraform/
  ├─ Starts subprocess: train.sh batch_B
  ├─ Launches monitor_logs("batch_B") thread
  └─ Adds to active_trainings["batch_B"]

Both trainings run simultaneously with:
- Independent GPU droplets
- Independent Terraform state
- Independent log files
- Independent log monitoring threads
```

### Log File Separation
- batch_A writes to: `training_log_batch_A.txt`
- batch_B writes to: `training_log_batch_B.txt`
- UI can filter logs by selected training
- Each thread monitors its class-specific file

## 🔄 Data Flow Patterns

### Starting a Training
1. Frontend: POST `/api/start-training` with class_name
2. Backend: Create class-specific Terraform directory
3. Backend: Start train.sh as subprocess
4. Backend: Launch monitor_logs thread
5. Backend: Emit `training_started` to all clients
6. Frontend: Update active trainings list
7. Monitor thread: Read log file every 0.5s
8. Monitor thread: Convert ANSI codes to HTML
9. Monitor thread: Emit `log_update` events
10. Frontend: Display logs in real-time

### Stopping a Training
1. Frontend: emit('stop_training', {class_name})
2. Backend: Terminate subprocess
3. Backend: Emit log updates during destruction
4. Backend: Run terraform destroy in class directory
5. Backend: Emit `training_stopped` event
6. Frontend: Remove from active trainings
7. Frontend: Update UI

## 🔒 Important Behaviors

### Duplicate Prevention
- Check if class already in `active_trainings` before starting
- Return 400 error if class already training
- UI grays out already-training classes in modal

### Resource Isolation
- Each training gets its own:
  - GPU droplet (separate DigitalOcean resource)
  - Terraform state file
  - Log file
  - Monitoring thread
  - Stop button and controls

### Log Preservation
- Logs append with `>>` (not overwrite with `>`)
- ANSI color codes preserved in file
- Backend converts to HTML for display
- Per-class files stay separate

### Error Handling
- Terraform failures logged with full output
- SSH connection retries with 10s intervals
- Cleanup always runs (even on failure)
- Errors emitted to frontend via `error` event

## 📝 Logging & Progress

### Log File Format
```
[YYYY-MM-DD HH:MM:SS] Local operation
Terraform output with colors
[YYYY-MM-DD HH:MM:SS] Next local operation
[REMOTE] Remote server output
... training progress ...
[YYYY-MM-DD HH:MM:SS] Cleanup complete
```

### Color Codes Preserved
- ANSI codes like `\x1b[32m` (green) stored in file
- Backend converts to HTML: `<span style="color: #51cf66;">`
- Frontend displays with colors in terminal-like UI

## 🚀 Common Tasks

### Adding New API Endpoint
1. Create `@app.route('/api/endpoint', methods=['GET/POST'])`
2. Include class_name in request/response if needed
3. Return JSON: `{'success': True/False, 'message': '...', 'data': {}}`
4. Emit Socket.IO events for real-time updates

### Adding New UI Feature
1. Add HTML structure to index.html
2. Add JavaScript event listeners for Socket.IO events
3. Add CSS styling with responsive design
4. Update logsPerClass or activeTrainings data structures
5. Test with multiple concurrent trainings

### Monitoring New Log Source
1. Ensure output goes to training_log_{CLASS_NAME}.txt
2. Update monitor_logs() if special parsing needed
3. Emit log_update with {message, class_name, is_html}
4. Frontend automatically subscribes to events

### Debugging Issues
1. Check Flask console for errors in monitor_logs()
2. Verify train.sh is running: `ps aux | grep train.sh`
3. Check log file exists: `ls -la training_log_*.txt`
4. Check WebSocket connection: Browser DevTools → Network → WS
5. Review Terraform directory: `ls -la ../training/*_terraform/`

## 🌐 API Response Patterns

### Success Response
```json
{
  "success": true,
  "message": "Operation completed",
  "data": {...}
}
```

### Error Response
```json
{
  "success": false,
  "message": "Reason for failure"
}
```

### Status Response
```json
{
  "status": "Running|Idle",
  "active": true|false,
  "active_trainings": ["class1", "class2"],
  "count": 2,
  "trainings_data": {
    "class1": {"started_at": "ISO-datetime"},
    "class2": {"started_at": "ISO-datetime"}
  }
}
```

## 🎯 Suggestions for Copilot

When suggesting code:
1. **Always maintain class_name context** in multi-training code
2. **Include error handling** for file I/O and subprocess operations
3. **Use per-class isolation** in data structures and file operations
4. **Add logging/progress updates** for user-facing operations
5. **Handle concurrent access** to active_trainings dict
6. **Test with multiple trainings** before suggesting new features
7. **Preserve ANSI codes** in logs for color display
8. **Use proper Socket.IO syntax** based on context (route vs handler)
9. **Include class_name in all events** for proper filtering
10. **Clean up resources** on error (Terraform, subprocesses)

## 🔄 Recent Improvements

- ✅ Multi-concurrent training support (class-based isolation)
- ✅ Per-class log files with proper append mode
- ✅ Real-time log streaming via Socket.IO
- ✅ ANSI color code support (preserved in logs, converted to HTML for display)
- ✅ Class-specific Terraform directories for independent state management
- ✅ Per-training elapsed time calculation
- ✅ Click-to-select training for viewing specific logs
- ✅ Individual Stop buttons per training
- ✅ Rsync with compression and class-specific data filtering
- ✅ Comprehensive API documentation

## 🔮 Future Enhancement Ideas

1. **Authentication**: Add user accounts and role-based access
2. **Multiple GPU Sizes**: Make GPU droplet size configurable per training
3. **Training History**: Persist completed training metadata and results
4. **Notifications**: Send alerts on completion/failure via email or Slack
5. **Training Presets**: Save/load configuration templates
6. **Dataset Management**: UI for uploading/managing custom datasets
7. **Resource Scheduling**: Queue trainings when quota is exceeded
8. **Training Comparison**: Side-by-side comparison of different training runs
9. **Model Management**: Download and manage trained models
10. **Cost Tracking**: Monitor and display per-training costs

---

Remember: This system handles expensive GPU resources, so always prioritize **safety**, **cost control**, **proper cleanup**, and **resource isolation** in all suggestions!
