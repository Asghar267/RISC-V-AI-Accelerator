#!/usr/bin/env python3
import os
import sys
import time

port = "/dev/ttyUSB1"
if len(sys.argv) > 1:
    port = sys.argv[1]

print(f"--- Opening UART Serial Port {port} at 115200 Baud ---")
print("Listening for FPGA RISC-V output... (Press Ctrl+C to stop)\n")

# Set serial port baud rate using stty
os.system(f"stty -F {port} 115200 cs8 -cstopb -parenb 2>/dev/null")

try:
    fd = os.open(port, os.O_RDONLY | os.O_NONBLOCK)
    while True:
        try:
            data = os.read(fd, 64)
            if data:
                text = data.decode('utf-8', errors='ignore')
                sys.stdout.write(text)
                sys.stdout.flush()
        except BlockingIOError:
            pass
        time.sleep(0.01)

except PermissionError:
    print(f"\n[ERROR] Permission denied opening {port}.")
    print(f"Please run with sudo:  sudo python3 {sys.argv[0]}")
except Exception as e:
    print(f"\n[ERROR] Could not open {port}: {e}")
