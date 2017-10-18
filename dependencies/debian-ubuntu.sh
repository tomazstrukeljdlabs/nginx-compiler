#!/usr/bin/env bash

## Install Debian-Ubuntu dependencies
#
# https://wiki.debian.org/BuildingTutorial
# https://help.ubuntu.com/community/CompilingSoftware

apt -y install build-essential automake checkinstall wget git unzip
apt -y install libgd2-xpm-dev libpam0g-dev libxslt1.1 libxslt1-dev libgeoip-dev make autoconf

