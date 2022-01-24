#!/usr/bin/env bash

set -e

[ $EUID -ne 0 ] && echo "run as root" >&2 && exit 1

# Convenience script to run vision processing and recognition code
cat << EOF > /usr/local/bin/vision.sh
#!/usr/bin/env bash

set -e

# Symlink a binary to run the vision code to this path.
/usr/local/bin/run-vision-python.sh
EOF
chmod +x /usr/local/bin/vision.sh

# Service configuration file to run vision processing and recognition code
cat << EOF > /etc/systemd/system/vision.service
[Unit]
Description=vision

[Service]
Type=simple
ExecStart=/usr/local/bin/vision.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable vision
