#!/usr/bin/env bash
#
# Source material: https://github.com/wpilibsuite/WPILibPi/blob/main/stage5/01-sys-tweaks/01-run.sh

set -e

[ $EUID -ne 0 ] && echo "run as root" >&2 && exit 1

# Miscelaneous setup tasks
apt update
apt install -y git rsync
mkdir -p /src
chown pi:pi /src

# Install nodejs runtime.
mkdir -p /usr/local/lib/nodejs
pushd /tmp
curl -O -L https://nodejs.org/dist/v16.13.2/node-v16.13.2-linux-armv7l.tar.xz
tar -xJvf node-v16.13.2-linux-armv7l.tar.xz -C /usr/local/lib/nodejs
popd
ln -sf /usr/local/lib/nodejs/node-v16.13.2-linux-armv7l/bin/* /usr/local/bin/

# Enable i2c.
cat << EOF > /etc/modules-load.d/i2c.conf
i2c-dev
EOF
chmod 644 /etc/modules-load.d/i2c.conf
sed -i -e "s/^#dtparam=i2c_arm=on/dtparam=i2c_arm=on/" "/boot/config.txt"

# Romi configuration file.
cat << EOF > /etc/romi.json
{
  "ioConfig": ["dio", "ain", "ain", "pwm", "pwm"],
  "gyroZeroOffset": {
    "x": 0,
    "y": 0,
    "z": 0
  }
}
EOF

# Install the distributed wpilib-ws-robot-romi build
npm install -g @wpilib/wpilib-ws-robot-romi
npm install -g i2c-bus
ln -sf /usr/local/lib/nodejs/node-v16.13.2-linux-armv7l/bin/wpilibws-romi /usr/local/bin/

# Convenience script to run wpilibws-romi
cat << EOF > /usr/local/bin/wpilibws-romi.sh
#!/usr/bin/env bash

set -e

wpilibws-romi -c /etc/romi.json
EOF
chmod +x /usr/local/bin/wpilibws-romi.sh

# Service configuration file to run wpilibws-romi
cat << EOF > /etc/systemd/system/wpilibws-romi.service
[Unit]
Description=wpilibws-romi

[Service]
Type=simple
ExecStart=/usr/local/bin/wpilibws-romi.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable wpilibws-romi

# Install and configure hostapd to serve a WiFI hotspot
apt install -y hostapd
cat << EOF > /etc/hostapd/hostapd.conf
interface=wlan0
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
ssid=WPILibPi
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
wpa_passphrase=WPILib2021!
EOF
systemctl unmask hostapd
systemctl enable hostapd

# Install and configure dnsmasq for DHCP clients
apt install -y dnsmasq
cat << EOF > /etc/dnsmasq.d/wpilib.conf
interface=wlan0
dhcp-range=10.0.0.100,10.0.0.200,255.255.255.0,5m
server=1.1.1.1
EOF
systemctl enable dnsmasq

# Install and configure dhcpcd for static IP configuration
apt install -y dhcpcd
cat << EOF > /etc/dhcpcd.conf
interface wlan0
static ip_address=10.0.0.2/24
static routers=10.0.0.1
nohook wpa_supplicant

interface eth0
static ip_address=10.0.0.3/24
static routers=10.0.0.1
static domain_name_servers=10.0.0.1 1.1.1.1
EOF
systemctl enable dhcpcd

reboot
