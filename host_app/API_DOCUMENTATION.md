# Training Host API Documentation

## Overview

The Training Host provides a REST API and WebSocket interface for managing GPU-accelerated training jobs. It supports concurrent training of multiple classes with real-time log streaming and infrastructure management via Terraform.

## Base URL

- **HTTP/REST**: `http://localhost:5000`
- **WebSocket**: `ws://localhost:5000/socket.io`

---

## REST API Endpoints

### 1. GET `/`

**Description**: Serves the web dashboard HTML interface.

**Response**:
- Status: `200 OK`
- Content-Type: `text/html`
- Body: Dashboard HTML page

**Example**:
```bash
curl http://localhost:5000/
```

---

### 2. GET `/api/status`

**Description**: Get the current status of all active trainings.

**Response**:
```json
{
  "status": "Running",
  "active": true,
  "active_trainings": ["batch_20251101T223547Z", "batch_20251101T225654Z"],
  "count": 2,
  "trainings_data": {
    "batch_20251101T223547Z": {
      "started_at": "2025-11-02T15:30:45.123456"
    },
    "batch_20251101T225654Z": {
      "started_at": "2025-11-02T15:35:12.654321"
    }
  }
}
```

**Status Codes**:
- `200 OK` - Successfully retrieved status

**Example**:
```bash
curl http://localhost:5000/api/status
```

---

### 4. GET `/api/classes`

**Description**: Get available class names from the raw-data folder.

**Response**:
```json
{
  "classes": [
    "batch_20251101T223547Z",
    "batch_20251101T225654Z",
    "batch_20251101T230146Z",
    "mvt2",
    "batch_20251101T230355Z"
  ]
}
```

**Status Codes**:
- `200 OK` - Successfully retrieved classes

**Example**:
```bash
curl http://localhost:5000/api/classes
```

---

### 5. GET `/api/models`

**Description**: Get available trained models from the results/models/backbone_0 directory.

**Response**:
```json
{
  "models": [
    {
      "name": "mvtec_batch_20251101T223547Z",
      "path": "/root/TrainingHost/GLASS-new/results/models/backbone_0/mvtec_batch_20251101T223547Z",
      "created": 1730543820.03
    },
    {
      "name": "mvtec_batch_20251101T225654Z",
      "path": "/root/TrainingHost/GLASS-new/results/models/backbone_0/mvtec_batch_20251101T225654Z",
      "created": 1730540520.3
    },
    {
      "name": "mvtec_mvt2",
      "path": "/root/TrainingHost/GLASS-new/results/models/backbone_0/mvtec_mvt2",
      "created": 1760737618.03
    }
  ],
  "count": 3
}
```

**Fields**:
- `name`: Model directory name
- `path`: Full path to model directory
- `created`: Unix timestamp of directory creation
- `count`: Total number of models found

**Status Codes**:
- `200 OK` - Successfully retrieved models

**Example**:
```bash
curl http://localhost:5000/api/models
```

---

### 6. POST `/api/start-training`

**Description**: Start a new training job for a specified class. Prevents duplicate trainings of the same class. Creates a separate GPU droplet via Terraform.

**Request**:
- Content-Type: `application/json`
- Body:
```json
{
  "class_name": "batch_20251101T223547Z"
}
```

**Response (Success)**:
```json
{
  "success": true,
  "message": "Training started for class: batch_20251101T223547Z"
}
```

**Status Codes**:
- `200 OK` - Training started successfully
- `400 Bad Request` - Missing or invalid class_name
- `400 Bad Request` - Class already training
- `500 Internal Server Error` - Failed to setup Terraform

**Example**:
```bash
curl -X POST http://localhost:5000/api/start-training \
  -H "Content-Type: application/json" \
  -d '{"class_name": "batch_20251101T223547Z"}'
```

**Behavior**:
1. Validates class name is provided
2. Checks if class is already training (prevents duplicates)
3. Creates class-specific Terraform directory: `../training/{class_name}_terraform`
4. Copies `main.tf` and `terraform.tfvars` to class directory
5. Clears old log file if it exists
6. Starts `train.sh` subprocess with class name parameter
7. Launches log monitoring thread for that class
8. Emits `training_started` event to all connected WebSocket clients

---

### 7. GET `/api/env`

**Description**: Get environment variables (legacy endpoint for configuration display).

**Response**:
```json
{
  "env": "CLASS_NAME=batch_20251101T223547Z\nGITHUB_REPO_URL=https://github.com/example/repo.git\n..."
}
```

**Status Codes**:
- `200 OK` - Successfully retrieved environment

**Example**:
```bash
curl http://localhost:5000/api/env
```

---

## WebSocket Events

### Client → Server Events

#### 1. `stop_training`

**Description**: Stop a running training job and destroy its infrastructure.

**Event Data**:
```json
{
  "class_name": "batch_20251101T223547Z"
}
```

**Example**:
```javascript
socket.emit('stop_training', { class_name: 'batch_20251101T223547Z' });
```

**Behavior**:
1. Validates class name is provided
2. Checks if training exists
3. Terminates the training subprocess
4. Emits log updates showing destruction progress
5. Runs `terraform destroy -auto-approve` in the class-specific directory
6. Removes from active trainings
7. Emits `training_stopped` event to all clients

---

### Server → Client Events

#### 1. `log_update`

**Description**: Real-time log message from a training job.

**Event Data**:
```json
{
  "message": "[2025-11-02 15:30:45] Creating GPU droplet...",
  "class_name": "batch_20251101T223547Z",
  "is_html": true
}
```

**Fields**:
- `message`: Log message (may contain HTML for colored output with ANSI codes converted)
- `class_name`: Which training this log belongs to
- `is_html`: If true, message contains HTML and should be rendered as `innerHTML`

**Example**:
```javascript
socket.on('log_update', function(data) {
  console.log(`[${data.class_name}] ${data.message}`);
});
```

---

#### 2. `training_started`

**Description**: Emitted when a new training job has started.

**Event Data**:
```json
{
  "class_name": "batch_20251101T223547Z"
}
```

**Example**:
```javascript
socket.on('training_started', function(data) {
  console.log(`Training started for: ${data.class_name}`);
});
```

---

#### 3. `training_completed`

**Description**: Emitted when a training job completes successfully.

**Event Data**:
```json
{
  "class_name": "batch_20251101T223547Z"
}
```

**Example**:
```javascript
socket.on('training_completed', function(data) {
  console.log(`Training completed for: ${data.class_name}`);
});
```

---

#### 4. `training_stopped`

**Description**: Emitted when a training job is stopped by user.

**Event Data**:
```json
{
  "class_name": "batch_20251101T223547Z"
}
```

**Example**:
```javascript
socket.on('training_stopped', function(data) {
  console.log(`Training stopped for: ${data.class_name}`);
});
```

---

#### 5. `error`

**Description**: Error message from the server.

**Event Data**:
```json
{
  "message": "No active training for batch_20251101T223547Z"
}
```

**Example**:
```javascript
socket.on('error', function(data) {
  console.error(`Error: ${data.message}`);
});
```

---

## Data Flow

### Starting a Training Job

```
Client (Browser)
    ↓ POST /api/start-training
Server (Flask)
    ↓ Creates Terraform directory
    ↓ Copies Terraform files
    ↓ Starts train.sh subprocess
    ↓ Launches monitor_logs thread
    ↓ Returns 200 OK response
    ↓ Emits training_started event
Client receives training_started
    ↓ Updates UI to show active training
    ↓ Subscribes to log_update events
```

### Real-Time Log Streaming

```
train.sh (running)
    ↓ Writes to training_log_{class_name}.txt (via exec redirection)
    ↓ Output flows through tee to both terminal and log file
Monitor thread (Python)
    ↓ Reads log file changes every 0.5 seconds
    ↓ Converts ANSI codes to HTML
    ↓ Emits log_update events via Socket.IO
Client (Browser)
    ↓ Receives log_update event
    ↓ Stores log in logsPerClass[class_name]
    ↓ If class selected, displays log with colors
```

### Stopping a Training Job

```
Client (Browser)
    ↓ emit('stop_training', { class_name: ... })
Server (Socket.IO handler)
    ↓ Terminates subprocess
    ↓ Runs terraform destroy in class directory
    ↓ Emits log_update events during destruction
    ↓ Removes from active_trainings dict
    ↓ Emits training_stopped event
Client
    ↓ Receives training_stopped event
    ↓ Removes from activeTrainings UI
    ↓ Updates status display
```

---

## Log File Structure

### File Naming
- **Pattern**: `training_log_{class_name}.txt`
- **Location**: `/root/TrainingHost/host_app/`
- **Example**: `training_log_batch_20251101T223547Z.txt`

### File Contents
Each log file contains timestamped output from the entire training lifecycle:

```
[2025-11-02 15:30:45] Initializing Terraform...
Initializing modules...
Terraform has been successfully initialized!
[2025-11-02 15:30:50] Creating GPU droplet...
digitalocean_ssh_key.controller: Creating...
digitalocean_droplet.gpu_training: Creating...
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
[2025-11-02 15:31:05] Droplet IP: 165.101.132.243
[2025-11-02 15:31:15] SSH ready. Syncing GLASS-new folder...
... (rsync output) ...
[2025-11-02 15:31:45] Connecting to droplet for setup...
[REMOTE] Updating system packages...
[REMOTE] Installing system packages...
... (training progress) ...
[2025-11-02 15:55:30] Training complete. Syncing results back...
[2025-11-02 15:56:15] Results synced successfully. Destroying droplet...
[2025-11-02 15:56:45] Cleanup complete.
```

### ANSI Color Codes
The logs preserve ANSI color codes from Terraform and training output. The backend converts these to HTML `<span>` tags with colors for display in the web UI:

- `\x1b[32m` (Green) → `<span style="color: #51cf66;">`
- `\x1b[31m` (Red) → `<span style="color: #ff6b6b;">`
- `\x1b[33m` (Yellow) → `<span style="color: #ffd43b;">`
- `\x1b[34m` (Blue) → `<span style="color: #74c0fc;">`
- `\x1b[1m` (Bold) → `<strong>`

---

## Terraform Integration

### Class-Specific Directories

Each training gets its own Terraform working directory:

```
/root/TrainingHost/training/
├── main.tf                                          (template)
├── terraform.tfvars                                 (template)
├── batch_20251101T223547Z_terraform/               (class 1)
│   ├── main.tf
│   ├── terraform.tfvars
│   ├── .terraform/
│   └── terraform.tfstate
└── batch_20251101T225654Z_terraform/               (class 2)
    ├── main.tf
    ├── terraform.tfvars
    ├── .terraform/
    └── terraform.tfstate
```

### Concurrent Droplets

Each training deploys its own DigitalOcean GPU droplet:
- Separate Terraform state per training
- Independent resource lifecycle
- Allows true concurrent training
- Resources cleaned up when training stops or completes

---

## Error Handling

### Common Error Responses

#### Missing Class Name
```json
{
  "success": false,
  "message": "Class name not provided"
}
```
Status: `400 Bad Request`

#### Class Already Training
```json
{
  "success": false,
  "message": "Training for batch_20251101T223547Z is already running"
}
```
Status: `400 Bad Request`

#### Terraform Setup Failed
```json
{
  "success": false,
  "message": "Failed to setup terraform: [error details]"
}
```
Status: `500 Internal Server Error`

#### No Active Training to Stop
```json
{
  "message": "No active training for batch_20251101T223547Z"
}
```
Via Socket.IO `error` event

---

## Performance Considerations

- **Log Monitoring Interval**: 0.5 seconds (fast updates, low overhead)
- **Status Poll Interval**: 2 seconds (UI refresh rate)
- **Max Concurrent Trainings**: Limited by Terraform and DigitalOcean API limits
- **Log File Storage**: Logs persist in individual files for post-training review

---

## Security Notes

### Current Implementation
- No authentication/authorization
- CORS enabled for all origins (`*`)
- WebSocket connections unrestricted
- Runs as root (via sudo)

### Production Recommendations
1. Add JWT or OAuth authentication
2. Restrict CORS to specific domains
3. Implement role-based access control
4. Run Flask app as unprivileged user
5. Use production WSGI server (Gunicorn, uWSGI)
6. Add rate limiting on API endpoints
7. Sanitize log output to prevent XSS
8. Encrypt sensitive data (API keys, tokens)

---

## Example Integration

### JavaScript (Browser)

```javascript
// Connect to WebSocket
const socket = io('http://localhost:5000');

// Start training
async function startTraining(className) {
  const response = await fetch('/api/start-training', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ class_name: className })
  });
  const data = await response.json();
  console.log(data.message);
}

// Listen for logs
socket.on('log_update', function(data) {
  console.log(`[${data.class_name}] ${data.message}`);
});

// Listen for training completion
socket.on('training_completed', function(data) {
  console.log(`Training for ${data.class_name} is complete!`);
});

// Stop training
function stopTraining(className) {
  socket.emit('stop_training', { class_name: className });
}
```

### Bash/cURL

```bash
# Get available classes
curl http://localhost:5000/api/classes

# Start training
curl -X POST http://localhost:5000/api/start-training \
  -H "Content-Type: application/json" \
  -d '{"class_name": "batch_20251101T223547Z"}'

# Check status
curl http://localhost:5000/api/status
```

---

## Troubleshooting

### Training starts but logs not updating
1. Check if `training_log_{class_name}.txt` is being created
2. Verify monitor_logs thread is running
3. Check Flask console for errors
4. Ensure WebSocket connection is established

### Terraform fails to deploy
1. Check DigitalOcean API token in `.env`
2. Verify account has GPU availability quota
3. Check if specified region has GPU droplets in stock
4. Review Terraform logs in the log file

### Stop button doesn't work
1. Verify `stop_training` event is emitted
2. Check if class_name matches exactly
3. Ensure Terraform directory exists for cleanup
4. Review Flask console for errors

---

## Version History

- **v1.0** (2025-11-02): Initial API documentation
  - REST endpoints for training control
  - WebSocket events for real-time streaming
  - Multi-concurrent training support
  - Class-specific Terraform deployments
  - ANSI color code support in logs
