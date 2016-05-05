#! /bin/bash
echo Type CTRL-A : to get into command mode, then enter quit to exit screen.
sleep 2
screen /dev/tty.usbserial-000013FAB 115200,rts
