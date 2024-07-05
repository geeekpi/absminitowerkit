#!/bin/bash
# 
. /lib/lsb/init-functions
log_action_msg "Welcome to GeeekPi ABS Minitower kit installation Program"
codename=`lsb_release -a |grep Codename| awk '{print $NF}'`
arch=`uname -m`
log_action_msg "Detect system information..." 
if [[ $codename == 'bookworm' && $arch == 'aarch64' ]]; then
	log_action_msg "OS: Raspberry Pi OS 64bit bookworm"
	sleep 5
else 
	log_action_msg "OS: It's $arch : $codename" 
	sleep 3
fi

log_action_msg "Modify /etc/resolv.conf to google DNS" 
sudo sh -c "sed -i 's/^/#/' /etc/resolv.conf"
sudo sh -c "sed -i '\$a\nameserver 114.114.114.114' /etc/resolv.conf"
sudo sh -c "sed -i '\$a\nameserver 8.8.8.8' /etc/resolv.conf"

log_action_msg "Installing basic dependencies packages..."
sudo apt update && sudo apt -y -q install git cmake scons python3-dev || log_action_msg "please check internet connection and make sure it can access internet!" 

# install libraries. 
log_action_msg "Check dependencies and install deps packages..."
sudo apt -y install python3 python3-pip python3-pil libjpeg-dev zlib1g-dev libfreetype6-dev liblcms2-dev libopenjp2-7 libtiff5-dev && log_action_msg "deps packages installed successfully!" || log_warning_msg "deps packages install process failed, please check the internet connection..." 

# install psutil lib.
pip3 install psutil --break-system-packages
if [ $? -eq 0 ]; then
	log_action_msg "psutil library has been installed successfully."
fi

# grant privilledges to user pi.
sudo usermod -a -G gpio,i2c pi && log_action_msg "grant privilledges to user pi" || log_warning_msg "Grant privilledges failed!" 

# download driver from internet 
cd /tmp
if [ ! -d /tmp/luma.examples ]; then
   while [[ ! -d /tmp/luma.examples ]];
   do 
   git clone https://github.com/rm-hull/luma.examples.git 
   if [[ -d /tmp/luma.examples ]]; then 
	   break
   fi
   done 
   cd /tmp/luma.examples/examples/ && sudo sh -c "cp -Rvf /tmp/luma.examples/examples /home/$USER/Downloads/" && log_action_msg "Downloaded repository to /tmp folder..." || log_warning_msg "Could not download repository from github, please check the internet connection..." 
else 
	log_action_msg "luma.examples repository exists in /tmp folder!!!"
fi 

#
log_action_msg "Install dependencies in side repository /tmp/luma.examples" 
cd /tmp/luma.examples/  && sudo -H pip3 install -e . --break-system-packages && log_action_msg "Install dependencies packages successfully..." || log_warning_msg "Cound not access github repository, please check the internet connections!!!" 

# download rpi_ws281x libraries.
cd /tmp/ 
if [ ! -d /tmp/rpi_ws281x ]; then
   while [[ ! -d /tmp/rpi_ws281x ]]; 
   do
     git clone https://github.com/jgarff/rpi_ws281x 
     if [[ -d /tmp/rpi_ws281x ]]; then
	   break
     fi
   done 
   log_action_msg "Download moodlight driver finished..." || log_warning_msg "Could not access github repository, please check the internet connections!!!" 
   cd /tmp/rpi_ws281x/ && sudo scons && mkdir build && cd build/ && cmake -D BUILD_SHARED=OFF -D BUILD_TEST=ON .. && sudo make install && sudo cp ./test /usr/bin/moodlight  && log_action_msg "Installation finished..." || log_warning_msg "Installation process failed! Please try again..."
else
	log_action_msg "rpi_ws281x repository exists in location: /tmp "
fi

# Enable i2c function on raspberry pi.
log_action_msg "Enable i2c on Raspberry Pi "
sudo sh -c "sed -i '/dtparam=i2c_arm*/d' /boot/firmware/config.txt"
sudo sh -c "sed -i '\$a\dtparam=i2c_arm=on' /boot/firmware/config.txt"
if [ $? -eq 0 ]; then
   log_action_msg "i2c has been setting up successfully"
fi

# install minitower service.
log_action_msg "Minitower service installation begin..."
#
if [ -f /usr/bin/moodlight ]; then
   log_action_msg "moodlight driver install successfully"
else 
   log_action_msg "Please copy /tmp/rpi_ws281x/build/test file to /usr/bin/ fold and rename it moodlight"
   sudo sh -c "cp -f /tmp/rpi_ws281x/build/test /usr/bin/moodlight"
fi

# check moodlight file 
if [[ -e /usr/bin/moodlight ]]; then
	log_action_msg "/usr/bin/moodlight is ok" 
else 
   sudo sh -c "cp -f /tmp/rpi_ws281x/build/test /usr/bin/moodlight"
fi

# mood light service.
service_file="/etc/systemd/system/minitower_moodlight.service"
sudo sh -c "cat <<EOF > '$service_file'
[Unit]
Description=Minitower moodlight Service
DefaultDependencies=no
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
RootDirectory=/ 
User=root
Type=simple
ExecStart=sudo /usr/bin/moodlight 
RemainAfterExit=yes
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target

EOF"

log_action_msg "`cat /etc/systemd/system/minitower_moodlight.service`"
log_action_msg "Created systemd service file: $service_file"
#
log_action_msg "Minitower moodlight service installation finished." 
sudo chown root:root $service_file
sudo chmod 644 $service_file
#
log_action_msg "Minitower moodlight Service Load module." 
sudo systemctl daemon-reload
sudo systemctl enable minitower_moodlight.service
sudo systemctl start minitower_moodlight.service
sudo systemctl restart minitower_moodlight.service
#
#
# oled screen display service.
#
sudo sh -c "mkdir -pv /usr/local/minitower/ && cd /usr/local/minitower/"

demo_opts_file="/usr/local/minitower/demo_opts.py"
sudo sh -c "cat <<EOF > '$demo_opts_file'
# -*- coding: utf-8 -*-
# Copyright (c) 2014-2022 Richard Hull and contributors
# See LICENSE.rst for details.

import sys
import logging

from luma.core import cmdline, error


# logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)-15s - %(message)s'
)
# ignore PIL debug messages
logging.getLogger('PIL').setLevel(logging.ERROR)


def display_settings(device, args):
    \"\"\"
    Display a short summary of the settings.

    :rtype: str
    \"\"\"
    iface = ''
    display_types = cmdline.get_display_types()
    if args.display not in display_types['emulator']:
        iface = f'Interface: {args.interface}\n'

    lib_name = cmdline.get_library_for_display_type(args.display)
    if lib_name is not None:
        lib_version = cmdline.get_library_version(lib_name)
    else:
        lib_name = lib_version = 'unknown'

    import luma.core
    version = f'luma.{lib_name} {lib_version} (luma.core {luma.core.__version__})'

    return f'Version: {version}\nDisplay: {args.display}\n{iface}Dimensions: {device.width} x {device.height}\n{\"-\" * 60}'


def get_device(actual_args=None):
    \"\"\"
    Create device from command-line arguments and return it.
    \"\"\"
    if actual_args is None:
        actual_args = sys.argv[1:]
    parser = cmdline.create_parser(description='luma.examples arguments')
    args = parser.parse_args(actual_args)

    if args.config:
        # load config from file
        config = cmdline.load_config(args.config)
        args = parser.parse_args(config + actual_args)

    # create device
    try:
        device = cmdline.create_device(args)
        print(display_settings(device, args))
        return device

    except error.Error as e:
        parser.error(e)
        return None

EOF"

python_file="/usr/local/minitower/sysinfo.py"
sudo sh -c "cat <<EOF > '$python_file' 
#!/usr/bin/python3
# -*- coding: utf-8 -*-

import os
import sys
import time
from pathlib import Path
from datetime import datetime
from demo_opts import get_device
from luma.core.render import canvas
from PIL import ImageFont
import psutil
import subprocess as sp


def bytes2human(n):
    symbols = ('K', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y')
    prefix = {}
    for i, s in enumerate(symbols):
        prefix[s] = 1 << (i + 1) * 10
    for s in reversed(symbols):
        if n >= prefix[s]:
            value = int(float(n) / prefix[s])
            return '%s%s' % (value, s)
    return \"%sB\" % n


def cpu_usage():
    # load average
    av1, av2, av3 = os.getloadavg()
    return \"Ld:%.1f %.1f %.1f\" % (av1, av2, av3)


def uptime_usage():
    # uptime, Ip
    # uptime = datetime.now() - datetime.fromtimestamp(psutil.boot_time())
    ip = sp.getoutput(\"hostname -I\").split(' ')[0]
    return \"IP:%s\" % (ip)
    

def mem_usage():
    usage = psutil.virtual_memory()
    return \"Mem:%s %.0f%%\" % (bytes2human(usage.used), 100 - usage.percent)


def disk_usage(dir):
    usage = psutil.disk_usage(dir)
    return \"SD:%s %.0f%%\" % (bytes2human(usage.used), usage.percent)


def network(iface):
    stat = psutil.net_io_counters(pernic=True)[iface]
    return \"%s: Tx: %s,Rx: %s\" % (iface, bytes2human(stat.bytes_sent), bytes2human(stat.bytes_recv))


def stats(device):
    # use custom font
    font_path = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
    font2 = ImageFont.truetype(font_path, 11)

    with canvas(device) as draw:
        draw.text((0, 1), cpu_usage(), font=font2, fill=\"white\")
        if device.height >= 32:
            draw.text((0, 12), mem_usage(), font=font2, fill=\"white\")

        if device.height >= 64:
            draw.text((0, 24), disk_usage('/'), font=font2, fill=\"white\")
            try:
                draw.text((0, 36), network('wlan0'), font=font2, fill=\"white\")
                draw.text((0, 48), uptime_usage(), font=font2, fill=\"white\")

            except KeyError:
                # no wifi enabled/available
                pass


device = get_device()

while True:
    stats(device)
    time.sleep(5)

EOF"

oled_service_file="/etc/systemd/system/minitower_oled.service"

sudo sh -c "cat <<EOF > '$oled_service_file'
[Unit]
Description=Minitower OLED Service
DefaultDependencies=no
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
ExecStart=sudo /bin/bash -c '/usr/bin/python3 /usr/local/minitower/sysinfo.py'
RemainAfterExit=yes
Restart=always

[Install]
WantedBy=multi-user.target

EOF"
#
log_action_msg "`cat /etc/systemd/system/minitower_oled.service`"
log_action_msg "Created systemd service file: $oled_service_file"
#
log_action_msg "Minitower Service configuration finished." 
sudo chown root:root $oled_service_file
sudo chmod 644 $oled_service_file
#
log_action_msg "Minitower Service Load module." 
sudo systemctl daemon-reload
sudo systemctl enable minitower_oled.service
sudo systemctl start minitower_oled.service
sudo systemctl restart minitower_oled.service
#
## Finished 
log_success_msg "Minitower service installation finished successfully." 
## greetings and require rebooting system to take effect.
for i in `seq 1 5 |sort -rn`
do
   log_action_msg "System will reboot in $i seconds"
   sleep 1
   clear
done
sudo sync
sudo reboot
