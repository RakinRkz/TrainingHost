import streamlit as st
import subprocess
import time
import os
import threading
from datetime import datetime

st.set_page_config(page_title="Training Host", layout="wide")
st.title("🚀 GPU Training Host Dashboard")

# Initialize session state
if 'training_active' not in st.session_state:
    st.session_state.training_active = False
if 'training_logs' not in st.session_state:
    st.session_state.training_logs = []

def monitor_progress():
    """Monitor the progress file and update logs"""
    log_file = "training_log.txt"
    last_position = 0
    
    while st.session_state.training_active:
        if os.path.exists(log_file):
            try:
                with open(log_file, "r") as f:
                    f.seek(last_position)
                    new_content = f.read()
                    if new_content:
                        for line in new_content.strip().split('\n'):
                            if line:
                                timestamp = datetime.now().strftime("%H:%M:%S")
                                st.session_state.training_logs.append(f"[{timestamp}] {line}")
                        last_position = f.tell()
                    
                    # Check for completion
                    f.seek(0)
                    content = f.read()
                    if "Cleanup complete" in content:
                        st.session_state.training_active = False
                        break
            except:
                pass
        time.sleep(1)

# Display environment variables
st.sidebar.header("Configuration")
env_file = ".env"
if os.path.exists(env_file):
    with open(env_file, "r") as f:
        env_content = f.read()
    st.sidebar.code(env_content, language="bash")
else:
    st.sidebar.warning("No .env file found")

# Main control panel
col1, col2 = st.columns([2, 1])

with col1:
    st.header("Training Control")
    
    if not st.session_state.training_active:
        if st.button("🎯 Start Training", type="primary", use_container_width=True):
            # Clear old logs
            st.session_state.training_logs = []
            st.session_state.training_active = True
            
            # Remove existing log files
            for log_file in ["progress.txt", "training_log.txt"]:
                if os.path.exists(log_file):
                    os.remove(log_file)
            
            # Start the training script
            subprocess.Popen(["bash", "train.sh"])
            
            # Start monitoring in a separate thread
            monitor_thread = threading.Thread(target=monitor_progress)
            monitor_thread.daemon = True
            monitor_thread.start()
            
            st.rerun()
    else:
        st.error("Training is currently running...")
        if st.button("🛑 Stop Training", type="secondary"):
            st.session_state.training_active = False
            # Kill any running processes
            subprocess.run(["pkill", "-f", "train.sh"], capture_output=True)
            st.rerun()

with col2:
    st.header("Status")
    if st.session_state.training_active:
        st.success("🟢 Training Active")
    else:
        st.info("⚪ Idle")
    
    # Show current progress from progress.txt
    if os.path.exists("progress.txt"):
        try:
            with open("progress.txt", "r") as f:
                current_status = f.read().strip()
            st.info(f"Current: {current_status}")
        except:
            pass

# Live log display
st.header("📊 Training Logs")

# Auto-refresh toggle
auto_refresh = st.checkbox("Auto-refresh (every 2 seconds)", value=True)

if auto_refresh and st.session_state.training_active:
    time.sleep(2)
    st.rerun()

# Display logs
if st.session_state.training_logs:
    log_container = st.container()
    with log_container:
        # Show last 50 logs to prevent overwhelming
        recent_logs = st.session_state.training_logs[-50:]
        for log in recent_logs:
            if "ERROR" in log.upper():
                st.error(log)
            elif "WARNING" in log.upper():
                st.warning(log)
            elif "SUCCESS" in log.upper() or "COMPLETE" in log.upper():
                st.success(log)
            else:
                st.text(log)
else:
    st.info("No logs yet. Start training to see real-time updates.")

# Clear logs button
if st.button("🗑️ Clear Logs"):
    st.session_state.training_logs = []
    st.rerun()