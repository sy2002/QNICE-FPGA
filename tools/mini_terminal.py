#!/usr/bin/env python3

# Mini Terminal for connecting to QNICE-FPGA
#
# Setup:
#   1. Install dependencies: pip install -r mini_terminal.txt
#   2. Set the QNICE_FPGA_PORT variable (below)
#   3. Run via python3 mini_terminal.py or by directly executing ./mini_terminal.py
#
# Exit using CTRL+Q
#
# done by sy2002 on 20th of July 2019

# on macOS and Linux enter "ll -l /dev/cu*" in terminal to find out where to connect to
# the following port is the one on sy2002's computer; you'll probabily need to adjust it to yours
QNICE_FPGA_PORT = '/dev/cu.usbserial-2102927424241'

import readchar
import serial
import threading
import time
import sys

print("\nQNICE Mini-Terminal V1.0, done by sy2002 on 20th of July 2019")
print("=============================================================\n")
print("press CTRL+Q to exit\n")

try:
    ser = serial.Serial(    port='/dev/cu.usbserial-2102927424241',
                            baudrate=115200,
                            bytesize=8, parity=serial.PARITY_NONE, stopbits=serial.STOPBITS_ONE,
                            rtscts=True,
                            timeout=0)
except:
    print("ERROR: SERIAL PORT CANNOT BE OPENED.")
    sys.exit(1)

CONTINUE_RUNNING = True                         # if set to False, the threads end

def read_thread(ser):
    global CONTINUE_RUNNING
    while CONTINUE_RUNNING:
        time.sleep(0.01)                        # sleep 10ms, free CPU cycles, keep CPU usage low
        amount = ser.in_waiting                 # amount of chars in serial read buffer
        input_str = ""
        if amount > 0:
            ser_in = ser.read(amount)           # due to "timeout=0" this is a non-blocking serial read
            input_str = ser_in.decode("ASCII")  # interpret byte stream as ASCII and convert to python string
            print(input_str, end="")            # print without a standard CR/LF
            sys.stdout.flush()                  # necessary to make sure we see the printed strint immediatelly

def write_thread(ser):
    global CONTINUE_RUNNING
    while CONTINUE_RUNNING:
        ch = readchar.readchar()                # blocking call
        try:
            send_str = ch.encode("ASCII")       # convert python string to byte stream
            ser.write(send_str)                 # send non-blocking due to "timeout=0" in serial.Serial(...)            
        except:
            pass
        
        if ord(ch) == 17:                       # CTRL+Q ends the program
            CONTINUE_RUNNING = False

# The serial interface is full duplex and therefore reading and writing operations occur concurrently.
# "join()" means: wait until the thread ends
t1 = threading.Thread(target=read_thread, args=[ser])
t2 = threading.Thread(target=write_thread, args=[ser])
t1.start()
t2.start()
t1.join()
t2.join()
ser.close()
print("\n\nCONNECTION CLOSED!\n")
