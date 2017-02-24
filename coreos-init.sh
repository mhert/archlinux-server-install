#!/usr/bin/env bash
set -x

if [ $# -eq 1 ]; then
    curl -O $1
    CONFIG_NAME=$(echo "$1" | rev | cut -d"/" -f1 | rev)
else
    echo "usage: "_$(basename $0)_" <CLOUD_CONFIG_URL>"
    exit
fi

mkdir /data
cryptsetup luksOpen /dev/sda10 data
mount /dev/mapper/data /data

mkdir /data/ssl
mv $CONFIG_NAME /data/cloud-config.yaml

coreos-cloudinit --from-file=/data/cloud-config.yaml
