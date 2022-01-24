#!/usr/bin/env bash

set -ex

[ $EUID -ne 0 ] && echo "run as root" >&2 && exit 1

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
pushd "${SCRIPT_DIR}"

disk="${1}"

if [ "${2}" == "3bv2" ]
then
  rootfs=/home/will/Downloads/ArchLinuxARM-rpi-armv7-latest.tar.gz
fi
if [ "${2}" == "zero2" ]
then
  rootfs=/home/will/Downloads/ArchLinuxARM-rpi-latest.tar.gz
fi

temp=$(mktemp --directory --suffix "archpi")
boot="${temp}/boot"
root="${temp}/root"

function clean_up()
{
  umount "${root}" > /dev/null || true
  umount "${boot}" > /dev/null || true
  rm -rf "${temp}"
}
trap clean_up EXIT

wipefs -a "${disk}"

printf "o\nn\np\n1\n\n+256M\nt\n0c\na\nw\n" | fdisk --wipe always --wipe-partitions always "${disk}"
mkfs.fat -F 32 "${disk}1"
printf "n\np\n2\n\n\nw\n" | fdisk --wipe always --wipe-partitions always "${disk}"
mkfs.ext4 -F "${disk}2"

mkdir -p "${boot}"
mount "${disk}1" "${boot}"
mkdir -p "${root}"
mount "${disk}2" "${root}"

bsdtar -xpf "${rootfs}" -C "${root}"
mv "${root}"/boot/* "${boot}"

cat << EOF > "${root}/etc/netctl/wlan0"
Description='wlan0'
Interface=wlan0
Connection=wireless
Security=wpa
ESSID=WPILibPi
IP=dhcp
Key='WPILib2021!'
EOF

mkdir -p "${root}/etc/systemd/system/netctl@wlan0.service.d"
cat << EOF > "${root}/etc/systemd/system/netctl@wlan0.service.d/profile.conf"
[Unit]
Description=wlan0
BindsTo=sys-subsystem-net-devices-wlan0.device
After=sys-subsystem-net-devices-wlan0.device
EOF

ln -s "${root}/usr/lib/systemd/system/netctl@.service" "${root}/etc/systemd/system/multi-user.target.wants/netctl@wlan0.service"

cat << EOF > "${root}/etc/modules-load.d/i2c.conf"
i2c-dev
EOF
chmod 644 "${root}/etc/modules-load.d/i2c.conf"
if ! grep -e '^dtparam=i2c_arm=on$' "${boot}/config.txt"
then
  echo "dtparam=i2c_arm=on" >> "${boot}/config.txt"
fi

echo "romipi" > "${root}/etc/hostname"
cat << EOF > "${root}/etc/hosts"
127.0.0.1        localhost
::1              localhost
127.0.1.1        romipi
EOF

cat << 'EOF' > "${root}/usr/local/bin/first-boot.sh"
#!/usr/bin/env bash

set -e

pacman-key --init
pacman-key --populate archlinuxarm

out=/first-boot.log

echo "successful-first-boot" >> ${out}
echo date >> ${out}
EOF
chmod +x "${root}/usr/local/bin/first-boot.sh"

cat << EOF > "${root}/etc/systemd/system/first-boot.service"
[Unit]
Description=First boot

[Service]
ExecStart=/usr/local/bin/first-boot.sh

[Install]
WantedBy=multi-user.target
EOF
ln -s "${root}/etc/systemd/system/first-boot.service" "${root}/etc/systemd/system/multi-user.target.wants/first-boot.service"

# Generate a package list by shelling into a live system (Arm Arch Pi specifically) and running this (changing the package names as needed).
# rm -f pkglist ; for pkg in "python" "curl" "jq" "npm" "nodejs" "base-devel" ; do pacman -Sp $pkg >> pkglist ; done
# I'm sure it's possible to web-scrape or do some other work to figure this out without being on a real Arm device, but this seems like a simple one-time exercise.

pushd ./package-cache
while read -r package
do
  if [ ! -f "$(basename "${package}")" ]
  then
    echo "retrieving: $package"
    curl -L -O "${package}"
  fi

  tar -xvf "$(basename "${package}")" -C "${root}/"
done <<EOF
http://mirror.archlinuxarm.org/armv6h/core/gdbm-1.22-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/libnsl-2.0.0-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/python-3.10.2-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/curl-7.81.0-2-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/community/oniguruma-6.9.7.1-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/community/jq-1.6-4-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/libnsl-2.0.0-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/extra/libuv-1.43.0-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/extra/c-ares-1.18.1-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/community/nodejs-17.3.0-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/community/nodejs-nopt-5.0.0-2-any.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/gdbm-1.22-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/python-3.10.2-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/community/semver-7.3.5-2-any.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/community/node-gyp-8.4.1-1-any.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/community/npm-8.4.1-1-any.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/libnsl-2.0.0-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/extra/libuv-1.43.0-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/extra/c-ares-1.18.1-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/community/nodejs-17.3.0-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/icu-70.1-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/gawk-5.1.1-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/m4-1.4.19-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/db-5.3.28-5-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/perl-5.34.0-3-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/autoconf-2.71-1-any.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/automake-1.16.5-1-any.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/findutils-4.8.0-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/libelf-0.186-4-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/elfutils-0.186-4-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/binutils-2.35-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/gettext-0.21-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/bison-3.8.2-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/sed-4.8-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/file-5.41-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/fakeroot-1.27-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/flex-2.6.4-3-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/libmpc-1.2.1-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/gcc-10.2.0-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/grep-3.7-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/groff-1.22.4-6-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/gzip-1.11-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/libtool-2.4.6+42+gb88cebd5-15-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/texinfo-6.8-2-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/extra/gc-8.2.0-2-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/extra/guile-2.2.7-2.1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/make-4.3-3.1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/pacman-6.0.1-3-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/patch-2.7.6-8-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/pkgconf-1.8.0-1-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/sudo-1.9.8.p2-3-armv6h.pkg.tar.xz
http://mirror.archlinuxarm.org/armv6h/core/which-2.21-5-armv6h.pkg.tar.xz
EOF
mkdir -p "${root}/var/cache/pacman/pkg/"
mkdir -p "${root}/var/cache/pacman/sync/"

# None of this is used since we explicitly untar (which is bad, if simpler) each package, but seems good to do this so the packages live where they're intended.
cp ./*.pkg.tar.xz "${root}/var/cache/pacman/pkg/"
curl -L -O "http://mirror.archlinuxarm.org/armv6h/community/community.db"
curl -L -O "http://mirror.archlinuxarm.org/armv6h/core/core.db"
curl -L -O "http://mirror.archlinuxarm.org/armv6h/extra/extra.db"
cp ./*.db "${root}/var/lib/pacman/sync/"
popd

# Must run 'npm install --global i2c-bus' on a real Arch Arm Pi device, copy out the files, and re-deploy later.
# The install has system-dependent bindings we can't easily handle from a non-Arm host machine.
mkdir -p "${root}/usr/lib/node_modules/i2c-bus"
rsync -avr ./node_modules/i2c-bus/ "${root}/usr/lib/node_modules/i2c-bus/"

pushd /tmp
curl -L -O https://github.com/wpilibsuite/wpilib-ws-robot-romi/releases/download/v1.4.0/romi-service-1.4.0.tgz
mkdir -p "${root}/usr/lib/node_modules/@wpilib/wpilib-ws-robot-romi"
tar -xzvf romi-service-1.4.0.tgz -C "${root}/usr/lib/node_modules/@wpilib/wpilib-ws-robot-romi" --strip-components=1
popd

cat << EOF > "${root}/usr/local/bin/romi-service.sh"
#!/usr/bin/env bash

set -e

/usr/bin/node "/usr/lib/node_modules/@wpilib/wpilib-ws-robot-romi/dist/index.js"
EOF
chmod +x "${root}/usr/local/bin/romi-service.sh"

cat << EOF > "${root}/etc/systemd/system/romi.service"
[Unit]
Description=Romi

[Service]
ExecStart=/usr/local/bin/romi-service.sh

[Install]
WantedBy=multi-user.target
EOF
ln -s "${root}/etc/systemd/system/romi.service" "${root}/etc/systemd/system/multi-user.target.wants/romi.service"

time sync
