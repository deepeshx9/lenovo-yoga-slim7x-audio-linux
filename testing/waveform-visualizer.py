import socket
import json
import os

SOCKET_PATH = "/tmp/wsa_safety_telemetry.sock"

# Clean up old socket if it exists
if os.path.exists(SOCKET_PATH):
    os.remove(SOCKET_PATH)

# Create a Datagram UNIX socket
server = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
server.bind(SOCKET_PATH)

print(f"Listening for telemetry on {SOCKET_PATH}...")

try:
    while True:
        datagram = server.recv(1024)
        if not datagram:
            break
            
        # Decode the JSON directly into a Python dictionary
        state = json.loads(datagram.decode('utf-8'))
        
        # Example GUI logic trigger
        if state["mode"] == "Limiting":
            print(f"🚨 WARNING: Gain Reduced by {state['gain_reduction']}dB! 🚨")
        else:
            print(f"Normal | Headroom: {state['headroom']}")
            
except KeyboardInterrupt:
    print("Shutting down visualizer...")
finally:
    os.remove(SOCKET_PATH)