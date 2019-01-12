#!/bin/sh

set -x

API_PATH=${PWD}/../../api
CHANNEL_NAME="fabric-sample"
CHAINCODE_NAME="fabric-payment"
CA_ADMIN_PASSWORD="adminpw"
NFS_HOST=10.142.0.2
NFS_PATH=/opt/nfs/fabric-payment
USER_NAME=fabricuser

#if [ $# -ne 3 ]; then
#  echo "usage: ${0} CA_ADMIN_PASSWORD NFS_HOST NFS_PATH"
##  exit 1
#fi

# remove previous crypto material and config transactions
rm -fr ./artifacts
rm -fr ./crypto-config

mkdir -p ./artifacts
mkdir -p ./crypto-config

sudo mount -t nfs ${NFS_HOST}:${NFS_PATH} /mnt
sudo rm -rf /mnt/*
sudo umount /mnt

sudo cp -r ~/fabric-tools/fabric-samples/bin .

# generate crypto material
./bin/cryptogen generate --config=./crypto-config.yaml
if [ "$?" -ne 0 ]; then
  echo "Failed to generate crypto material..."
  exit 1
fi

# generate genesis block for orderer
./bin/configtxgen -profile OneOrgFourOrderersGenesis -outputBlock ./artifacts/genesis.block
if [ "$?" -ne 0 ]; then
  echo "Failed to generate orderer genesis block..."
  exit 1
fi

# generate channel configuration transaction
./bin/configtxgen -profile OneOrgFourOrderersChannel -outputCreateChannelTx ./artifacts/channel.tx -channelID ${CHANNEL_NAME}
if [ "$?" -ne 0 ]; then
  echo "Failed to generate channel configuration transaction..."
  exit 1
fi

# generate anchor peer transaction
./bin/configtxgen -profile OneOrgFourOrderersChannel -outputAnchorPeersUpdate ./artifacts/Org1MSPanchors.tx -channelID ${CHANNEL_NAME} -asOrg Org1MSP
if [ "$?" -ne 0 ]; then
  echo "Failed to generate anchor peer update for Org1MSP..."
  exit 1
fi

rm -f docker-compose.yaml
cp docker-compose.yaml.template docker-compose.yaml
sed -i -e "s/<<CA_KEYFILE_PLACEHOLDER>>/$(basename $(ls crypto-config/peerOrganizations/org1.example.com/ca/*_sk))/g" docker-compose.yaml
sed -i -e "s/<<CA_ADMIN_PASSWORD>>/${CA_ADMIN_PASSWORD}/g" docker-compose.yaml
sed -i -e "s/<<CHANNEL_NAME>>/${CHANNEL_NAME}/g" docker-compose.yaml
sed -i -e "s/<<CHAINCODE_NAME>>/${CHAINCODE_NAME}/g" docker-compose.yaml
sed -i -e "s/<<USER_NAME>>/${USER_NAME}/g" docker-compose.yaml
sed -i -e "s/<<NFS_HOST>>/${NFS_HOST}/g" docker-compose.yaml
sed -i -e "s#<<NFS_PATH>>#${NFS_PATH}#g" docker-compose.yaml

docker rmi localhost:5000/fabric-payment-swarm/fabric-ca
docker rmi localhost:5000/fabric-payment-swarm/fabric-orderer
docker rmi localhost:5000/fabric-payment-swarm/fabric-peer
docker rmi localhost:5000/fabric-payment-swarm/fabric-tools
docker rmi localhost:5000/fabric-payment-swarm/api

rm -rf api
rm -rf scripts
rm -rf fabric-payment-sample-chaincode
cp -r ${API_PATH}/api .
cp -r ${API_PATH}/scripts .
cp -r /home/hexoindia/go/src/github.com/nmatsui/fabric-payment-sample-chaincode .
#///home/hexoindia/go/src/github.com/nmatsui/fabric-payment-sample-chaincode

docker build -t localhost:5000/fabric-payment-swarm/fabric-ca -f swarm-dockerfiles/ca_Dockerfile .
docker build -t localhost:5000/fabric-payment-swarm/fabric-orderer -f swarm-dockerfiles/orderer_Dockerfile .
docker build -t localhost:5000/fabric-payment-swarm/fabric-peer -f swarm-dockerfiles/peer_Dockerfile .
docker build -t localhost:5000/fabric-payment-swarm/fabric-tools -f swarm-dockerfiles/cli_Dockerfile .
docker build -t localhost:5000/fabric-payment-swarm/api -f swarm-dockerfiles/api_Dockerfile .

docker tag hyperledger/fabric-zookeeper:latest localhost:5000/hyperledger/fabric-zookeeper:latest
docker tag hyperledger/fabric-kafka:latest localhost:5000/hyperledger/fabric-kafka:latest
docker tag hyperledger/fabric-couchdb:latest localhost:5000/hyperledger/fabric-couchdb:latest

docker push localhost:5000/fabric-payment-swarm/fabric-ca:latest
docker push localhost:5000/fabric-payment-swarm/fabric-orderer:latest
docker push localhost:5000/fabric-payment-swarm/fabric-peer:latest
docker push localhost:5000/fabric-payment-swarm/fabric-tools:latest
docker push localhost:5000/fabric-payment-swarm/api:latest
docker push localhost:5000/hyperledger/fabric-zookeeper:latest
docker push localhost:5000/hyperledger/fabric-kafka:latest
docker push localhost:5000/hyperledger/fabric-couchdb:latest

rm -rf api
rm -rf scripts
rm -rf fabric-payment-sample-chaincode
