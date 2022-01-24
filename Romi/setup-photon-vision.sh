#!/usr/bin/env bash
#
# Source material: https://docs.photonvision.org/en/latest/docs/getting-started/installation/coprocessor-image.html#other-debian-based-co-processor-installation

set -e

[ $EUID -ne 0 ] && echo "run as root" >&2 && exit 1

wget https://git.io/JJrEP -O install.sh
chmod +x install.sh
./install.sh

reboot