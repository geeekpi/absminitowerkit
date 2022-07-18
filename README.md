# absminitowerkit
ABS mini tower kit 's driver and installation script. 
## How to install
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
