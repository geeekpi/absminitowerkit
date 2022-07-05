#!/bin/bash
# 
. /lib/lsb/init-functions
sudo apt update && sudo apt -y -q install git cmake scons  || log_action_msg "please check internet connection and make sure it can access internet!" 

# install libraries. 
log_action_msg "Check dependencies and install deps packages..."
sudo apt -y install python3 python3-pip python3-pil libjpeg-dev zlib1g-dev libfreetype6-dev liblcms2-dev libopenjp2-7 libtiff5 && log_action_msg "deps packages installed successfully!" || log_warning_msg "deps packages install process failed, please check the internet connection..." 

# grant privilledges to user pi.
sudo usermod -a -G gpio,i2c pi && log_action_msg "grant privilledges to user pi" || log_warning_msg "Grant privilledges failed!" 

# download driver from internet 
cd /usr/local/ 
if [ ! -d luma.examples ]; then
   git clone https://github.com/rm-hull/luma.examples.git && cd luma.examples/ || log_warning_msg "Could not download repository from github, please check the internet connection..." 
   cd luma.examples/  && sudo -H pip3 install -e . && log_action_msg "Install dependencies packages successfully..." || log_warning_msg "Cound not access github repository, please check the internet connections!!!" 
fi 

# download rpi_ws281x libraries.
cd /usr/local/ 
if [ ! -d rpi_ws281x ]; then
   git clone https://github.com/jgarff/rpi_ws281x && log_action_msg "Download moodlight driver finished..." || log_warning_msg "Could not access github repository, please check the internet connections!!!" 
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

echo "[Unit]" > ${moodlight_svc_file}
echo "Description=Minitower mood light Service " >> ${moodlight_svc_file}
echo "DefaultDependencies=no " >> ${moodlight_svc_file}
echo "StartLimitIntervalSec=60 " >> ${moodlight_svc_file}
echo "StartLimitBurst=5 " >> ${moodlight_svc_file}
echo "[Service] " >> ${moodlight_svc_file}
echo "RootDirectory=/ " >> ${moodlight_svc_file}
echo "User=root " >> ${moodlight_svc_file}
echo "Type=simple " >> ${moodlight_svc_file}
echo "ExecStart=sudo /usr/bin/moodlight &  " >> ${moodlight_svc_file}
echo "RemainAfterExit=yes " >> ${moodlight_svc_file}
echo "Restart=always " >> ${moodlight_svc_file}
echo "RestartSec=30 " >> ${moodlight_svc_file}
echo "[Install] " >> ${moodlight_svc_file}
echo "WantedBy=multi-user.target" >> ${moodlight_svc_file}

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

if [ -d /usr/local/luma.examples ]; then
  echo "[Unit]" > ${oled_svc_file}
  echo "Description=Minitower Service" >> ${oled_svc_file}
  echo "DefaultDependencies=no" >> ${oled_svc_file}
  echo "StartLimitIntervalSec=60" >> ${oled_svc_file}
  echo "StartLimitBurst=5" >> ${oled_svc_file}
  
  
  echo "[Service]" >> ${oled_svc_file}
  echo "RootDirectory=/tmp" >> ${oled_svc_file}
  echo "User=root" >> ${oled_svc_file}
  echo "Type=simple" >> ${oled_svc_file}
  echo "ExecStart=sudo /usr/bin/python3 /usr/local/luma.examples/examples/sys_info.py & " >> ${oled_svc_file}
  echo "RemainAfterExit=yes" >> ${oled_svc_file}
  echo "Restart=always" >> ${oled_svc_file}
  echo "RestartSec=30" >> ${oled_svc_file}
  
  echo "[Install]" >> ${oled_svc_file}
  echo "WantedBy=multi-user.target" >> ${oled_svc_file}

log_action_msg "Minitower Service configuration finished." 
sudo chown root:root ${oled_svc_file}
sudo chmod 644 $oled_svc_file

log_action_msg "Minitower Service Load module." 
sudo systemctl daemon-reload
sudo systemctl enable ${oled_svc}.service
sudo systemctl restart ${oled_svc}.service

# Finished 
log_success_msg "Minitower service installation finished successfully." 
# greetings and require rebooting system to take effect.
log_action_msg "Have fun!" 
sudo sync
else 
  log_warning_msg "Installation failed due to can not download the repository from github..."
fi

