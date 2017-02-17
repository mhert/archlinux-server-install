#!/usr/bin/env bash
set -x

if [ $# -eq 1 ]; then
    CLUSTERNAME=$1
    HOSTNAME=$(hostname)
    CERTNAME=${CLUSTERNAME}
else
    echo "usage: "_$(basename $0)_" <CLUSTERNAME>"
    exit
fi

pacman -Syu --noconfirm docker

mkdir /var/etcd
mkdir /etc/systemd/system/docker.service.d

echo "[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --ipv6 -H fd://" > /etc/systemd/system/docker.service.d/ipv6.conf

echo "[Unit]
Description=etcd container
Requires=docker.service
After=docker.service

[Service]
Restart=always
ExecStartPre=/usr/bin/sh -c \"if docker ps | grep etcd; then docker stop -t 2 etcd; fi\"
ExecStartPre=/usr/bin/sh -c \"if docker ps -a | grep etcd; then docker rm -f etcd; fi\"

ExecStart=/usr/bin/docker run --net=host -p 2379:2379 -p 2380:2380 -v /var/etcd:/data -v /var/ssl:/ssl --name etcd quay.io/coreos/etcd:v3.1.0 \
    /usr/local/bin/etcd \
        --data-dir /data \
        --discovery-srv ${CLUSTERNAME} \
        --name ${HOSTNAME} \
        --initial-cluster-token ${CLUSTERNAME} \
        --initial-advertise-peer-urls https://${HOSTNAME}:2380 \
        --advertise-client-urls https://${HOSTNAME}:2379 \
        --listen-client-urls https://0.0.0.0:2379 \
        --listen-peer-urls https://0.0.0.0:2380 \
        --peer-client-cert-auth \
        --peer-trusted-ca-file=/ssl/${CERTNAME}-ca-chain.cert.pem \
        --peer-cert-file=/ssl/${CERTNAME}.cert.pem \
        --peer-key-file=/ssl/${CERTNAME}.key.pem \
        --client-cert-auth \
        --trusted-ca-file=/ssl/${CERTNAME}-ca-chain.cert.pem \
        --cert-file=/ssl/${CERTNAME}.cert.pem \
        --key-file=/ssl/${CERTNAME}.key.pem

ExecStop=/usr/bin/sh -c \"if docker ps | grep etcd; then docker stop -t 2 etcd; fi\"
ExecStop=/usr/bin/sh -c \"if docker ps -a | grep etcd; then docker rm -f etcd; fi\"

[Install]
WantedBy=default.target" > /etc/systemd/system/etcd.service

systemctl daemon-reload
systemctl enable docker.service
systemctl start docker.service

systemctl enable etcd.service
systemctl start etcd.service
