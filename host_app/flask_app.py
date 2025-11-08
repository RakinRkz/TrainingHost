from flask import Flask, render_template, jsonify, request
from flask_socketio import SocketIO, emit, join_room, leave_room
import subprocess
import os
import threading
import time
import re
import shutil
from datetime import datetime
from pathlib import Path

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your-secret-key'
socketio = SocketIO(app, cors_allowed_origins="*")

# ANSI to HTML color mapping
ANSI_COLOR_MAP = {
    '30': '#808080',  # Black -> Gray
    '31': '#ff6b6b',  # Red
    '32': '#51cf66',  # Green
    '33': '#ffd43b',  # Yellow
    '34': '#74c0fc',  # Blue
    '35': '#da77f2',  # Magenta
    '36': '#22b8cf',  # Cyan
    '37': '#ffffff',  # White
}

def ansi_to_html(text):
    """Convert ANSI color codes to HTML span tags"""
    if not text:
        return text
    
    # Replace ANSI codes with HTML spans
    # Pattern: \x1b[<code>m
    def replace_ansi(match):
        code = match.group(1)
        if code == '0' or code == '':
            return '</span>'  # Reset
        elif code in ANSI_COLOR_MAP:
            color = ANSI_COLOR_MAP[code]
            return f'<span style="color: {color};">'
        elif code.startswith('1'):  # Bold
            return '<strong>'
        else:
            return ''
    
    # Convert ANSI codes
    html = re.sub(r'\x1b\[([0-9;]*)m', replace_ansi, text)
    return html

# Track multiple active trainings: { class_name: { 'process': Popen, 'thread': Thread, 'started': datetime } }
active_trainings = {}

def monitor_logs(class_name):
    """Monitor training logs for a specific class and emit to clients"""
    log_file = f"training_log_{class_name}.txt"
    last_log_position = 0
    check_count = 0
    
    while class_name in active_trainings:
        try:
            # Check training_log for detailed logs
            if os.path.exists(log_file):
                try:
                    with open(log_file, "r") as f:
                        # Check if file has grown
                        f.seek(0, 2)  # Seek to end
                        file_size = f.tell()
                        
                        if file_size > last_log_position:
                            # New content available
                            f.seek(last_log_position)
                            new_content = f.read()
                            if new_content:
                                for line in new_content.strip().split('\n'):
                                    if line.strip():
                                        # Convert ANSI codes to HTML and emit
                                        html_line = ansi_to_html(line.strip())
                                        socketio.emit('log_update', {'message': html_line, 'class_name': class_name, 'is_html': True}, namespace='/')
                            last_log_position = f.tell()
                        
                        # Check for completion markers
                        f.seek(0)
                        content = f.read()
                        if "Cleanup complete" in content or "Training stopped by user" in content:
                            socketio.emit('training_completed', {'class_name': class_name}, namespace='/')
                            if class_name in active_trainings:
                                del active_trainings[class_name]
                            break
                except Exception as e:
                    print(f"Error reading log file {log_file}: {e}")
            else:
                # Log file doesn't exist yet, create it
                with open(log_file, "w") as f:
                    f.write("")
        except Exception as e:
            print(f"Error in monitor_logs for {class_name}: {e}")
            html_error = ansi_to_html(f'[ERROR] Log monitoring error for {class_name}: {str(e)}')
            socketio.emit('log_update', {'message': html_error, 'class_name': class_name, 'is_html': True}, namespace='/')
        
        time.sleep(0.5)  # Check more frequently for new logs

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/status')
def get_status():
    active_classes = list(active_trainings.keys())
    status = "Running" if active_classes else "Idle"
    
    # Include start times for each training
    trainings_data = {}
    for class_name, info in active_trainings.items():
        trainings_data[class_name] = {
            'started_at': info['started'].isoformat()
        }
    
    return jsonify({
        'status': status,
        'active': len(active_classes) > 0,
        'active_trainings': active_classes,
        'count': len(active_classes),
        'trainings_data': trainings_data
    })

@app.route('/api/env')
def get_env():
    env_content = ""
    if os.path.exists(".env"):
        with open(".env", "r") as f:
            env_content = f.read()
    return jsonify({'env': env_content})

@app.route('/api/classes')
def get_classes():
    """Get available class names from raw-data folder"""
    raw_data_path = Path("../GLASS-new/raw-data").resolve()
    
    classes = []
    if raw_data_path.exists():
        for item in raw_data_path.iterdir():
            if item.is_dir():
                classes.append(item.name)
    
    classes.sort()  # Sort alphabetically
    return jsonify({'classes': classes})

@app.route('/api/models')
def get_models():
    """Get available trained models from results/models/backbone_0"""
    models_path = Path("../GLASS-new/results/models/backbone_0").resolve()
    
    models = []
    if models_path.exists():
        for backbone_dir in models_path.iterdir():
            if backbone_dir.is_dir():
                model_info = {
                    'name': backbone_dir.name,
                    'path': str(backbone_dir),
                    'created': backbone_dir.stat().st_mtime
                }
                models.append(model_info)
    
    # Sort by creation time (newest first)
    models.sort(key=lambda x: x['created'], reverse=True)
    
    return jsonify({
        'models': models,
        'count': len(models)
    })

@app.route('/api/start-training', methods=['POST'])
def start_training_api():
    """Start training with specified class name (allows multiple concurrent trainings)"""
    
    data = request.get_json()
    print(request.data)
    class_name = data.get('class_name') if data else None
    
    if not class_name:
        return jsonify({'success': False, 'message': 'Class name not provided'}), 400
    
    # Check if this class is already training
    if class_name in active_trainings:
        return jsonify({'success': False, 'message': f'Training for {class_name} is already running'}), 400
    
    # Setup class-specific terraform directory with copied files
    terraform_dir = Path(f"../training/{class_name}_terraform")
    terraform_dir.mkdir(parents=True, exist_ok=True)
    
    # Copy main.tf and terraform.tfvars to class-specific directory
    import shutil
    try:
        shutil.copy("../training/main.tf", terraform_dir / "main.tf")
        shutil.copy("../training/terraform.tfvars", terraform_dir / "terraform.tfvars")
    except Exception as e:
        return jsonify({'success': False, 'message': f'Failed to setup terraform: {str(e)}'}), 500
    
    # Clear old logs for this class
    log_file = f"training_log_{class_name}.txt"
    if os.path.exists(log_file):
        os.remove(log_file)
    
    # Start training script with class name parameter
    training_process = subprocess.Popen(["bash", "train.sh", class_name])
    
    # Track the training
    active_trainings[class_name] = {
        'process': training_process,
        'started': datetime.now()
    }
    
    # Start log monitoring thread for this training
    monitor_thread = threading.Thread(target=monitor_logs, args=(class_name,))
    monitor_thread.daemon = True
    monitor_thread.start()
    
    active_trainings[class_name]['thread'] = monitor_thread
    
    # Emit event to all clients using the correct socketio.emit syntax
    socketio.emit('training_started', {'class_name': class_name}, namespace='/')
    
    return jsonify({'success': True, 'message': f'Training started for class: {class_name}'}), 200

@socketio.on('start_training')
def handle_start_training_socket():
    """Legacy socket handler - now just emits an event"""
    pass  # This is handled by the POST API now

@socketio.on('stop_training')
def handle_stop_training(data=None):
    """Stop training for a specific class"""
    class_name = data.get('class_name') if isinstance(data, dict) else None
    
    if not class_name:
        emit('error', {'message': 'Class name not provided'})
        return
    
    if class_name not in active_trainings:
        emit('error', {'message': f'No active training for {class_name}'})
        return
    
    # Terminate the training process
    training_info = active_trainings[class_name]
    if training_info.get('process'):
        training_info['process'].terminate()
        training_info['process'].wait()
    
    # Destroy Terraform infrastructure (from class-specific directory)
    emit('log_update', {'message': f'[STOPPING] Destroying Terraform infrastructure for {class_name}...', 'class_name': class_name}, broadcast=True)
    try:
        terraform_dir = Path(f"../training/{class_name}_terraform")
        result = subprocess.run(
            ["terraform", "destroy", "-auto-approve"],
            cwd=str(terraform_dir),
            capture_output=True,
            text=True,
            timeout=300
        )
        if result.returncode == 0:
            emit('log_update', {'message': f'[SUCCESS] Terraform infrastructure for {class_name} destroyed.', 'class_name': class_name}, broadcast=True)
        else:
            emit('log_update', {'message': f'[ERROR] Terraform destroy failed for {class_name}: {result.stderr}', 'class_name': class_name}, broadcast=True)
    except subprocess.TimeoutExpired:
        emit('log_update', {'message': f'[ERROR] Terraform destroy timeout for {class_name} after 5 minutes.', 'class_name': class_name}, broadcast=True)
    except Exception as e:
        emit('log_update', {'message': f'[ERROR] Failed to destroy infrastructure for {class_name}: {str(e)}', 'class_name': class_name}, broadcast=True)
    
    # Remove from active trainings
    if class_name in active_trainings:
        del active_trainings[class_name]
    
    emit('training_stopped', {'class_name': class_name}, broadcast=True)

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5000, debug=True)