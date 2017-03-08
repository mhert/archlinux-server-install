#!/usr/bin/env bash
set -x

if [ $# -eq 1 ]; then
    CLOUD_CONFIG_URL=$1
    AFTERBNOOT_GIT_URL=$2
else
    echo "usage: "_$(basename $0)_" <CLOUD_CONFIG_URL> <SERVER_INSTALL_GIT_URL>"
    exit
fi

curl -o cloud-config.yaml $CLOUD_CONFIG_URL

bash <(curl -s https://raw.githubusercontent.com/coreos/init/master/bin/coreos-install) -d /dev/sda -C stable -c cloud-config.yaml

sgdisk /dev/sda --delete=9
sgdisk /dev/sda --new=9::+10G --type=9:FFFF
sgdisk /dev/sda --new=10:: --type=10:8300
resize2fs /dev/sda9 10G

partprobe

cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha512 -i 10000 --use-random /dev/sda10
cryptsetup luksOpen /dev/sda10 encrypted-system
mkfs.btrfs -f /dev/mapper/encrypted-system

mkdir /mnt
mount /dev/mapper/encrypted-system /mnt

git clone $AFTERBNOOT_GIT_URL /mnt/scripts

echo "$CLOUD_CONFIG_URL" > /mnt/cloud-config-url

mkdir /mnt/ssl
