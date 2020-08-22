# odroid-n2box
Ubuntu packages for Odroid N2

ODROID-N2: Kodi packages for ubuntu. compiled for armhf.

## How to install:
```
download from releases and extract
cd kodi-ubuntu-bionic
cat KEY.gpg | apt-key add -
# install python-pip (arm64)
apt-get install python-pip

# create file
vim /etc/apt/sources.list.d/odroid-n2box.list
deb file:/path/to/folder/kodi-ubuntu-bionic ./

dpkg --add-architecture armhf
apt-get update
apt-get install kodi:armhf kodi-inputstream.adaptive:armhf kodi-pvr.iptvsimple:armhf

# with user you run kodi:
pip install wheel
pip install pycryptodomex
mkdir -p ~/.kodi/addons
cd ~/.kodi/addons
wget https://github.com/emilsvennesson/script.module.inputstreamhelper/archive/master.tar.gz
