#!/bin/bash
# uninstall minitowerkit script 
. /lib/lsb/init-functions

daemonname="minitower.service"
filelocation=/lib/systemd/system/$daemonname

log_action_msg "Uninstalling minitower kit Driver..."
sleep 1
log_action_msg "Remove dtoverlay configure from /boot/config.txt file"
sudo sed -i '/dtparam=i2c.*/ s/^/#/' /boot/config.txt
log_action_msg "Stop and disable $daemonname"
sudo systemctl disable $daemonname 2&>/dev/null  
sudo systemctl stop $daemonname  2&>/dev/null
log_action_msg "Remove Minitower kit Driver..."
sudo rm -f  $filelocation  2&>/dev/null 
sudo rm -f /usr/bin/moodlight 2&>/dev/null 
log_success_msg "Uninstall Mini tower kit Driver Successfully." 

