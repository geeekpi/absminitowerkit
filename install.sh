#!/bin/bash
# 
. /lib/lsb/init-functions
sudo apt update && sudo apt-get -q install git  || echo "please check internet connection and make sure it can access internet!" 

# install libraries. 
log_action_msg "Check dependencies and install deps packages..."
sudo apt -y install python3 python3-pip python3-pil libjpeg-dev zlib1g-dev libfreetype6-dev liblcms2-dev libopenjp2-7 libtiff5 && log_action_msg "deps packages installed successfully!" || log_warning_msg "deps packages install process failed, please check the internet connection..." 

# grant privilledges to user pi.
sudo usermod -a -G gpio,i2c pi && log_action_msg "grant privilledges to user pi" || log_warning_msg "Grant privilledges failed!" 

# download driver from internet 
cd /usr/local/ && git clone https://github.com/geeekpi/absminitowerkit && cd absminitowerkit/luma.examples/  && sudo -H pip3 install -e . && log_action_msg "Install dependencies packages successfully..." || log_warning_msg "Cound not access github repository, please check the internet connections!!!" 

# download rpi_ws281x libraries.
cd /usr/local/ && git clone https://github.com/geeekpi/absminitowerkit && log_action_msg "Download moodlight driver finished..." || log_warning_msg "Could not access github repository, please check the internet connections!!!" 
if [ $? -eq 0 ]; then
   log_action_msg "Install mood light driver..."
   sudo apt -y -q install scons && cd absminitowerkit/rpi_ws281x/ && sudo scons && mkdir build && cd build/ && cmake -D BUILD_SHARED=OFF -D BUILD_TEST=ON .. && sudo make install && sudo cp ./test /usr/bin/moodlight  && log_action_msg "Installation finished..." || log_warning_msg "Installation process failed! Please try again..."
fi

# create minitower systemd service.
daemon=minitower
minitower_svc_file=/lib/systemd/system/$daemon.service


# Enable i2c function on raspberry pi.
log_action_msg "Enable i2c on Raspberry Pi "
sudo sed -i '/dtparam=i2c_arm*/d' /boot/config.txt 
sudo sed -i '$a\dtparam=i2c_arm=on' /boot/config.txt 
if [ $? -eq 0 ]; then
   log_action_msg "i2c has been setting up successfully"
fi

# install minitower service.
log_action_msg "Minitower service installation begin..."
if [ -d /usr/local/luma.examples/ ]; then
   log_action_msg "OLED driver install successfully"
fi

if [ -f /usr/bin/moodlight ]; then
   log_action_msg "moodlight driver install successfully"
fi

# send signal to MCU before system shuting down.
echo "[Unit]" > ${minitower_svc_file}
echo "Description=Minitower Service" >> $minitower_svc_file
echo "DefaultDependencies=no" >> $minitower_svc_file
echo "StartLimitIntervalSec=60" >> $minitower_svc_file
echo "StartLimitBurst=5" >> $minitower_svc_file


echo "[Service]" >> $minitower_svc_file
echo "RootDirectory=/" >> $minitower_svc_file
echo "User=root" >> $minitower_svc_file
echo "Type=simple" >> $minitower_svc_file
echo "ExecStart=sudo /usr/bin/python3 /usr/local/luma.example/examples/sys_info.py & " >> $minitower_svc_file
echo "ExecStart=sudo /usr/bin/moodlight &" >> $minitower_svc_file
echo "RemainAfterExit=yes" >> $minitower_svc_file
echo "Restart=on-failure" >> $minitower_svc_file
echo "RestartSec=30" >> $minitower_svc_file

echo "[Install]" >> $minitower_svc_file
echo "WantedBy=multi-user.target" >> $minitower_svc_file

log_action_msg "Minitower Service configuration finished." 
sudo chown root:root $minitower_svc_file
sudo chmod 644 $minitower_svc_file

log_action_msg "Minitower Service Load module." 
sudo systemctl daemon-reload
sudo systemctl enable $daemon.service
sudo systemctl restart $daemon.service

# Finished 
log_success_msg "Minitower service installation finished successfully." 
# greetings and require rebooting system to take effect.
log_action_msg "Have fun!" 
sudo sync

