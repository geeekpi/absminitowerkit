# absminitowerkit
ABS mini tower kit 's driver and installation script. 
## How to install ( Installation script works on Raspberry Pi OS 64bit ) 
* 1. Download the latest image from https://www.raspberrypi.com/software/
* 2. Flash it to your TF Card with etcher tool, Download link: https://etcher.io/
* 3. After flashing, insert the TF card back to Raspberry Pi card Slot.
* 4. Power up your Raspberry Pi and make sure it can access internet.
* 5. Update Repository and Upgrade packages.
```bash
sudo apt update 
sudo apt upgrade -y 
```
* 6. Enable I2C on Raspberry Pi.
```bash
sudo raspi-config
```
Navigate to `Interface Options` -> `I2C` -> Enable -> Select `YES`. 
* 7. Clone Repository.
```bash
git clone https://github.com/geeekpi/absminitowerkit.git
```
* 8. Install driver.
```bash
cd absminitowerkit/
sudo ./install.sh
```
* 9. Reboot and have fun.
```bash
sudo sync
sudo reboot
```
##Install script for Ubuntu 22.04 LTS User
1. please follow the steps to install libraries and packages:
```bash
sudo apt update 
sudo apt -y upgrade 
sudo apt -y install tree vim git i2c-tools python3 python3-pil python3-pip libjpeg-dev zlib1g-dev libfreetype6-dev liblcms2-dev libopenjp2-7 libtiff5
```
2. Grant permission to current user
```bash
sudo usermod -a -G roo,i2c `whoami`
id `whoami`
```
3. Detect OLED display's address. Default address will be : 0x3c
```bash
sudo i2cdetect -y 1
```
If you can not see the correct address, please check the connection of oled display driver board and raspberry Pi GPIO. 

4. Download luma.examples OLED demo code repository and install the dependencies packages.
```bash
cd 
git clone https://github.com/rm-hull/luma.exmaples 
cd luma.examples/
sudo pip3 -H install -e .
```
5. Test demo code 
```bash
sudo python3 clock.py 
```
If you can see clock on OLED display, you can press ctrl+C to quit program.
6. Download geeekpi abs minitower kit repository:
```bash
git clone https://github.com/geeekpi/absminitowerkit
cd absminitowerkit/
cp sysinfo.py ../luma.examples/examples/
cd ../luma.examples/examples/
sudo pip3 install psutil
sudo python3 sysinfo.py 
```
I will show the system information on OLED screen, if you want to put it into background and running. try this command:
```bash
sudo python3 sysinfo.py &
```
7. How to turn on the mood light?
Actually, Mood light system is 2 RGB ws281x led strip. One of them is soldered in back of the OLED driver board, it is number 1, another one is in the fan which is number 2. 
Just install following libraries to driver the leds.
```bash
sudo pip3 install rpi_ws281x adafruit-circuitpython-neopixel
```
8. Write a demo code to light up each led, create a new python file named moodlight.py and input following code and execute it.
```python
import board 
import neopixel
import time 
from random import randint


pixels = neopixel.NeoPixel(board.D18, 4)  # D18 means connect to GPIO18 on Raspberry Pi. 4 means 4 leds 

# led on back of OLED driver board, (255, 0 , 0 ) is RGB format of the light, value from 0-255,  (255,0,0) means (red, green, blue) it will turn on the light to red color. (0, 0, 0 ) will turn off the color. 
pixels[0] = (255, 0, 0) 

# led on fan 
pixels[1] = (0, 255, 0) # NO.1 LED turns on fan color to green 
pixels[2] = (255, 0, 0) # NO.2 LED turns on fan color to red
pixels[3] = (0, 0, 255) # NO.3 LED turns on fan color to blue  

# turns off leds on fan
pixels[4] = (0, 0, 0)　 # turns off all leds on fan

# turn off RGB LED on board 
pixels[0].fill((0,0,0))

# while loop
while True:
    for i in range(0, 255):
         np[1] = (randint(0,i), randint(i, 255), randint(i, 255))
         np[2] = (randint(0,i), randint(i, 255), randint(0, i))
         np[3] = (randint(i, 255), randint(0, i), randint(i, 255))
         time.sleep(0.02)
         np[4] = (0, 0, 0)  # turns off all leds

```

execute the python file like :
```bash
sudo python3 moodlight.py 
```

## How to turn off all leds?
just copy following code to a file and execute it. 
```python
import board
from neopixel import NeoPixel

np = NeoPixel(board.D18, 4) 

np.fill((0,0,0))
```
Save it and execute it:
```bash
sudo python3 turnoff_leds.py
```

## That's all 
Have a nice day and have fun!
