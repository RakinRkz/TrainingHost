#!/bin/bash

echo "Choose your web interface:"
echo "1) Streamlit (Simple, auto-refreshing)"
echo "2) Flask (Real-time with WebSockets)"
echo -n "Enter choice (1 or 2): "
read choice

case $choice in
    1)
        echo "Starting Streamlit app..."
        streamlit run app.py --server.port 8501 --server.address 0.0.0.0
        ;;
    2)
        echo "Starting Flask app..."
        python flask_app.py
        ;;
    *)
        echo "Invalid choice. Starting Streamlit by default..."
        streamlit run app.py --server.port 8501 --server.address 0.0.0.0
        ;;
esac