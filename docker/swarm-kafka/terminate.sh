#!/bin/bash
set -x

STACK_NAME=fabric-payment
NFS_HOST=10.142.0.2
NFS_PATH=/opt/nfs/fabric-payment

#if [ $# -ne 2 ]; then
#  echo "usage: ${0} NFS_HOST NFS_PATH"
#  exit 1
#fi

docker stack rm ${STACK_NAME}
docker stack rm kafka
docker stack rm zookeeper

sleep 30

docker rm -f $(docker ps -aq)
docker rmi $(docker images dev-* -q)

docker network rm fabric-sample-nw
docker volume prune -f

sudo mount -t nfs ${NFS_HOST}:${NFS_PATH}/key_store /mnt
sudo rm /mnt/*
sudo umount /mnt

sudo mount -t nfs ${NFS_HOST}:${NFS_PATH}/genesis_store /mnt
sudo rm /mnt/*
sudo umount /mnt
