ODROID-N2: 
- Kodi packages for ubuntu 20.04 compiled for armhf.
- EmulationStation, retroarch and libretro-cores for arm64

[Download ubuntu packages](https://github.com/gerulrich/odroid-n2box/releases)

## How to install:
```
# extract tar.gz file
cd ubuntu-focal
cat KEY.gpg | apt-key add -

# create file
vim /etc/apt/sources.list.d/odroid-n2box.list
deb file:/path/to/folder/ubuntu-focal ./

dpkg --add-architecture armhf
apt-get update
apt-get install kodi:armhf kodi-inputstream.adaptive:armhf kodi-pvr.iptvsimple:armhf

#install pip2
curl https://bootstrap.pypa.io/get-pip.py --output get-pip.py
sudo python2 get-pip.py

# with user you run kodi:
pip install wheel
pip install pycryptodomex
mkdir -p ~/.kodi/addons
cd ~/.kodi/addons
wget https://github.com/emilsvennesson/script.module.inputstreamhelper/archive/master.tar.gz
tar xzf master.tar.gz 
mv script.module.inputstreamhelper-master/ script.module.inputstreamhelper
rm master.tar.gz 
