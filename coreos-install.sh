#!/usr/bin/env bash
set -x

if [ $# -eq 2 ]; then
    AFTERBOOT_GIT_URL="$1"
    CLOUD_CONFIG_URL="$2"
else
    echo "usage: "_$(basename $0)_" <AFTERBOOT_GIT_URL> <CLOUD_CONFIG_URL>"
    exit
fi

curl -o cloud-config.yaml "$CLOUD_CONFIG_URL"

bash <(curl -s https://raw.githubusercontent.com/coreos/init/master/bin/coreos-install) -d /dev/sda -C stable -c cloud-config.yaml

sgdisk /dev/sda --delete=9
sgdisk /dev/sda --new=9::+10G --type=9:FFFF
sgdisk /dev/sda --new=10:: --type=10:8300

partprobe

cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha512 -i 10000 --use-random /dev/sda10
cryptsetup luksOpen /dev/sda10 data
mkfs.btrfs -f /dev/mapper/data

mkdir -p /mnt
mount /dev/mapper/encrypted-data /mnt

echo "$CLOUD_CONFIG_URL" > /mnt/cloud-config-url.yaml

mkdir /mnt/ssl

umount /mnt
cryptsetup luksClose /dev/mapper/data

mount /sda9 /mnt
resize2fs /dev/sda9 10G

git clone "$AFTERBOOT_GIT_URL" /mnt/root/scripts

umount /mnt
