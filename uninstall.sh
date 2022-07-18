#!/bin/bash
# uninstall minitowerkit script 
. /lib/lsb/init-functions

moodlight_svc="minitower_moodlight.service"
filelocation="/lib/systemd/system/${moodlight_svc}.service"

oled_svc="minitower_oled.service"
svclocation="/lib/systemd/system/${oled_svc}"

log_action_msg "Uninstalling minitower moodlight Driver..."
sleep 1

log_action_msg "Remove dtoverlay configure from /boot/config.txt file"
sudo sed -i '/dtparam=i2c.*/ s/^/#/' /boot/config.txt

log_action_msg "Stop and disable ${moodlight_svc}"
sudo systemctl disable ${moodlight_svc} 2&>/dev/null  
sudo systemctl stop ${moodlight_svc}  2&>/dev/null

log_action_msg "Stop and disable ${oled_svc}"
sudo systemctl disable ${oled_svc} 2&>/dev/null  
sudo systemctl stop ${oled_svc}  2&>/dev/null

log_action_msg "Remove Minitower kit Driver..."
sudo rm -f  /lib/systemd/system/minitower_moodlight.service  2&>/dev/null 
sudo rm -f /usr/bin/moodlight 2&>/dev/null 
sudo rm -rf /lib/systemd/system/minitower_oled.service 2&>/dev/null

sudo rm -rf /usr/local/luma.examples/ 2&>/dev/null
sudo rm -rf /usr/local/rpi_ws281x/ 2&>/dev/null

log_success_msg "Uninstall Mini tower kit Driver Successfully." 
