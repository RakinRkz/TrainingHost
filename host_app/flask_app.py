from flask import Flask, render_template, jsonify, request
from flask_socketio import SocketIO, emit
import subprocess
import os
import threading
import time
from datetime import datetime

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your-secret-key'
socketio = SocketIO(app, cors_allowed_origins="*")

training_active = False
training_process = None

def monitor_logs():
    """Monitor training logs and emit to clients"""
    global training_active
    log_file = "training_log.txt"
    last_position = 0
    
    while training_active:
        if os.path.exists(log_file):
            try:
                with open(log_file, "r") as f:
                    f.seek(last_position)
                    new_content = f.read()
                    if new_content:
                        for line in new_content.strip().split('\n'):
                            if line:
                                socketio.emit('log_update', {'message': line})
                        last_position = f.tell()
                    
                    # Check for completion
                    f.seek(0)
                    content = f.read()
                    if "Cleanup complete" in content:
                        training_active = False
                        socketio.emit('training_complete')
                        break
            except:
                pass
        time.sleep(1)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/status')
def get_status():
    status = "Running" if training_active else "Idle"
    current_progress = ""
    
    if os.path.exists("progress.txt"):
        try:
            with open("progress.txt", "r") as f:
                current_progress = f.read().strip()
        except:
            pass
    
    return jsonify({
        'status': status,
        'active': training_active,
        'current_progress': current_progress
    })

@app.route('/api/env')
def get_env():
    env_content = ""
    if os.path.exists(".env"):
        with open(".env", "r") as f:
            env_content = f.read()
    return jsonify({'env': env_content})

@socketio.on('start_training')
def handle_start_training():
    global training_active, training_process
    
    if not training_active:
        training_active = True
        
        # Clear old logs
        for log_file in ["progress.txt", "training_log.txt"]:
            if os.path.exists(log_file):
                os.remove(log_file)
        
        # Start training script
        training_process = subprocess.Popen(["bash", "train.sh"])
        
        # Start log monitoring
        monitor_thread = threading.Thread(target=monitor_logs)
        monitor_thread.daemon = True
        monitor_thread.start()
        
        emit('training_started')
    else:
        emit('error', {'message': 'Training already running'})

@socketio.on('stop_training')
def handle_stop_training():
    global training_active, training_process
    
    training_active = False
    if training_process:
        training_process.terminate()
    
    # Kill any running processes
    subprocess.run(["pkill", "-f", "train.sh"], capture_output=True)
    emit('training_stopped')

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5000, debug=True)