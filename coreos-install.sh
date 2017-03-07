#!/usr/bin/env bash
set -x

if [ $# -eq 1 ]; then
    curl -O $1
    CONFIG_NAME=$(echo "$1" | rev | cut -d"/" -f1 | rev)
    mv $CONFIG_NAME cloud-config.yaml
else
    echo "usage: "_$(basename $0)_" <CLOUD_CONFIG_URL>"
    exit
fi

apt-get install gawk --yes

curl -O https://raw.githubusercontent.com/coreos/init/master/bin/coreos-install
chmod +x coreos-install
./coreos-install -d /dev/sda -C beta -c cloud-config.yaml

partprobe

sgdisk /dev/sda --delete=9
sgdisk /dev/sda --new=9::+10G --type=9:FFFF
sgdisk /dev/sda --new=10:: --type=10:8300
resize2fs /dev/sda9 10G

partprobe

cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha512 -i 10000 --use-random /dev/sda10
cryptsetup luksOpen /dev/sda10 encrypted-system
mkfs.btrfs -f /dev/mapper/encrypted-system
