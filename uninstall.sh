#!/bin/bash
# uninstall minitowerkit script 
. /lib/lsb/init-functions

log_action_msg "Uninstalling minitower driver..."
sleep 3
log_action_msg "Disable moodlight and oled services."
sudo systemctl disable minitower_moodlight.service
sudo systemctl disable minitower_oled.service

log_action_msg "Stop moodlight and oled services."
sudo systemctl stop minitower_moodlight.service
sudo systemctl stop minitower_oled.service

log_action_msg "Remove moodlight and oled service files."
if [[ -e /etc/systemd/system/minitower_moodlight.service ]];then
   sudo rm -f /etc/systemd/system/minitower_moodlight.service
fi 

if [[ -e /etc/systemd/system/minitower_oled.service ]];then
   sudo rm -f /etc/systemd/system/minitower_oled.service
fi

log_action_msg "Remove dtoverlay configure from /boot/firmware/config.txt file"
sudo sh -c "sed -i '/dtparam=i2c.*/ s/^/#/' /boot/firmware/config.txt"

log_action_msg "Remove /usr/bin/moodlight file."
if [[ -e /usr/bin/moodlight ]]; then
	sudo rm -f /usr/bin/moodlight 2&>/dev/null 
fi

log_action_msg "Remove minitower oled python script"
if [[ -d /usr/local/minitower ]]; then
	sudo rm -rf /usr/local/minitower/ 2&>/dev/null
fi


log_success_msg "Uninstall Mini tower kit Driver Successfully." 

