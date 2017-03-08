#!/usr/bin/env bash
set -x

mkdir -p /data
cryptsetup luksOpen /dev/sda10 data
mount /dev/mapper/data /data

CLOUD_CONFIG_URL=$(cat /data/cloud-config-url)

curl -O /data/cloud-config.yaml $CLOUD_CONFIG_URL
coreos-cloudinit --from-file=/data/cloud-config.yaml

systemctl daemon-reload
systemctl start afterboot
