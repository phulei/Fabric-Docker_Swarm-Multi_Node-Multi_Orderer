#!/bin/sh

set -x

FABRIC_CFG_PATH=${PWD}
CHANNEL_NAME=fabric-sample
CHAINCODE_NAME=fabric-payment
USER_NAME=fabricuser
API_PATH=${PWD}/../../api
GOPATH=/home/hexoindia/go
CA_ADMIN_PASSWORD=adminpw


##if [ $# -ne 1 ]; then
#  echo "usage: ${0} CA_ADMIN_PASSWORD"
#  exit 1
#fi

# remove previous crypto material and config transactions
rm -fr ./artifacts
rm -fr ./crypto-config

mkdir -p ./artifacts
mkdir -p ./crypto-config

# generate crypto material
./bin/cryptogen generate --config=./crypto-config.yaml
if [ "$?" -ne 0 ]; then
  echo "Failed to generate crypto material..."
  exit 1
fi

# generate genesis block for orderer
./bin/configtxgen -profile OneOrgOneOrdererGenesis -outputBlock ./artifacts/genesis.block
if [ "$?" -ne 0 ]; then
  echo "Failed to generate orderer genesis block..."
  exit 1
fi

# generate channel configuration transaction
./bin/configtxgen -profile OneOrgOneOrdererChannel -outputCreateChannelTx ./artifacts/channel.tx -channelID ${CHANNEL_NAME}
if [ "$?" -ne 0 ]; then
  echo "Failed to generate channel configuration transaction..."
  exit 1
fi

# generate anchor peer transaction
./bin/configtxgen -profile OneOrgOneOrdererChannel -outputAnchorPeersUpdate ./artifacts/Org1MSPanchors.tx -channelID ${CHANNEL_NAME} -asOrg Org1MSP
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

