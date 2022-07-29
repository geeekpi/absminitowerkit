#!/bin/bash
# 
. /lib/lsb/init-functions
sudo apt update && sudo apt -y -q install git cmake scons python3-dev || log_action_msg "please check internet connection and make sure it can access internet!" 

# install libraries. 
log_action_msg "Check dependencies and install deps packages..."
sudo apt -y install python3 python3-pip python3-pil libjpeg-dev zlib1g-dev libfreetype6-dev liblcms2-dev libopenjp2-7 libtiff5 && log_action_msg "deps packages installed successfully!" || log_warning_msg "deps packages install process failed, please check the internet connection..." 

# install psutil lib.
sudo -H pip3 install psutil
if [ $? -eq 0 ]; then
	log_action_msg "psutil library has been installed successfully."
fi

# grant privilledges to user pi.
sudo usermod -a -G gpio,i2c pi && log_action_msg "grant privilledges to user pi" || log_warning_msg "Grant privilledges failed!" 

# download driver from internet 
cd /usr/local/ 
if [ ! -d luma.examples ]; then
   cd /usr/local/
   git clone https://github.com/rm-hull/luma.examples.git && cd /usr/local/luma.examples/ && sudo cp -f /home/pi/absminitowerkit/sysinfo.py . || log_warning_msg "Could not download repository from github, please check the internet connection..." 
else
   # copy sysinfo.py application to /usr/local/luma.examples/examples/ folder.
   sudo cp -vf /home/pi/absminitowerkit/sysinfo.py /usr/local/luma.examples/examples/ 2>/dev/null
fi 

cd /usr/local/luma.examples/  && sudo -H pip3 install -e . && log_action_msg "Install dependencies packages successfully..." || log_warning_msg "Cound not access github repository, please check the internet connections!!!" 

# download rpi_ws281x libraries.
cd /usr/local/ 
if [ ! -d rpi_ws281x ]; then
   cd /usr/local/
   sudo git clone https://github.com/jgarff/rpi_ws281x && log_action_msg "Download moodlight driver finished..." || log_warning_msg "Could not access github repository, please check the internet connections!!!" 
   cd rpi_ws281x/ && sudo scons && mkdir build && cd build/ && cmake -D BUILD_SHARED=OFF -D BUILD_TEST=ON .. && sudo make install && sudo cp ./test /usr/bin/moodlight  && log_action_msg "Installation finished..." || log_warning_msg "Installation process failed! Please try again..."
fi

# Enable i2c function on raspberry pi.
log_action_msg "Enable i2c on Raspberry Pi "

sudo sed -i '/dtparam=i2c_arm*/d' /boot/config.txt 
sudo sed -i '$a\dtparam=i2c_arm=on' /boot/config.txt 

if [ $? -eq 0 ]; then
   log_action_msg "i2c has been setting up successfully"
fi

# install minitower service.
log_action_msg "Minitower service installation begin..."

if [ -f /usr/bin/moodlight ]; then
   log_action_msg "moodlight driver install successfully"
fi

# mood light service.
moodlight_svc="minitower_moodlight"
moodlight_svc_file="/lib/systemd/system/${moodlight_svc}.service"
sudo rm -f ${moodlight_svc_file}

sudo echo "[Unit]" > ${moodlight_svc_file}
sudo echo "Description=Minitower moodlight Service" >> ${moodlight_svc_file}
sudo echo "DefaultDependencies=no" >> ${moodlight_svc_file}
sudo echo "StartLimitIntervalSec=60" >> ${moodlight_svc_file}
sudo echo "StartLimitBurst=5" >> ${moodlight_svc_file}
sudo echo "[Service]" >> ${moodlight_svc_file}
sudo echo "RootDirectory=/ " >> ${moodlight_svc_file}
sudo echo "User=root" >> ${moodlight_svc_file}
sudo echo "Type=simple" >> ${moodlight_svc_file}
sudo echo "ExecStart=sudo /usr/bin/moodlight &" >> ${moodlight_svc_file}
sudo echo "RemainAfterExit=yes" >> ${moodlight_svc_file}
sudo echo "Restart=always" >> ${moodlight_svc_file}
sudo echo "RestartSec=30" >> ${moodlight_svc_file}
sudo echo "[Install]" >> ${moodlight_svc_file}
sudo echo "WantedBy=multi-user.target" >> ${moodlight_svc_file}

log_action_msg "Minitower moodlight service installation finished." 
sudo chown root:root ${moodlight_svc_file}
sudo chmod 644 ${moodlight_svc_file}

log_action_msg "Minitower moodlight Service Load module." 
sudo systemctl daemon-reload
sudo systemctl enable ${moodlight_svc}.service
sudo systemctl restart ${moodlight_svc}.service


# oled screen display service.
oled_svc="minitower_oled"
oled_svc_file="/lib/systemd/system/${oled_svc}.service"
sudo rm -f ${oled_svc_file}

sudo echo "[Unit]" > ${oled_svc_file}
sudo echo "Description=Minitower Service" >> ${oled_svc_file}
sudo echo "DefaultDependencies=no" >> ${oled_svc_file}
sudo echo "StartLimitIntervalSec=60" >> ${oled_svc_file}
sudo echo "StartLimitBurst=5" >> ${oled_svc_file}
sudo echo "[Service]" >> ${oled_svc_file}
sudo echo "RootDirectory=/" >> ${oled_svc_file}
sudo echo "User=root" >> ${oled_svc_file}
sudo echo "Type=forking" >> ${oled_svc_file}
sudo echo "ExecStart=/bin/bash -c '/usr/bin/python3 /usr/local/luma.examples/examples/sysinfo.py &'" >> ${oled_svc_file}
sudo echo "# ExecStart=/bin/bash -c '/usr/bin/python3 /usr/local/luma.examples/examples/clock.py &'" >> ${oled_svc_file}
sudo echo "RemainAfterExit=yes" >> ${oled_svc_file}
sudo echo "Restart=always" >> ${oled_svc_file}
sudo echo "RestartSec=30" >> ${oled_svc_file}
sudo 
sudo echo "[Install]" >> ${oled_svc_file}
sudo echo "WantedBy=multi-user.target" >> ${oled_svc_file}

log_action_msg "Minitower Service configuration finished." 
sudo chown root:root ${oled_svc_file}
sudo chmod 644 ${oled_svc_file}

log_action_msg "Minitower Service Load module." 
systemctl daemon-reload
systemctl enable ${oled_svc}.service
systemctl restart ${oled_svc}.service 

# Finished 
log_success_msg "Minitower service installation finished successfully." 

# greetings and require rebooting system to take effect.
log_action_msg "Please reboot Raspberry Pi and Have fun!" 
sudo sync


