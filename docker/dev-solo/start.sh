#!/bin/bash
set -x

ORDERER_ADDRESS="orderer:7050"
LOCALMSPID="Org1MSP"
PEER_MSPCONFIGPATH="/etc/hyperledger/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp"
CHAINCODE_SRC="github.com/nmatsui/fabric-payment-sample-chaincode"
CHANNEL_NAME="fabric-sample"
CHAINCODE_NAME="fabric-payment"
CHAINCODE_VERSION="0.1"
CA_ADMIN_PASSWORD="adminpw"
USER_NAME="fabricuser"


docker-compose -f docker-compose.yaml down
docker network rm fabric-sample-nw

docker network create --driver=bridge --attachable=true fabric-sample-nw
docker-compose -f docker-compose.yaml up -d

sleep 20

CLI="cli"
API="api"

PEER_ADDRESS="peer:7051"

# Create the channel
docker exec -e "CORE_PEER_LOCALMSPID=${LOCALMSPID}" -e "CORE_PEER_MSPCONFIGPATH=${PEER_MSPCONFIGPATH}" ${CLI} peer channel create -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME} -f /etc/hyperledger/artifacts/channel.tx

sleep 10

# Setup peer

## Join peer0 to the channel
docker exec -e "CORE_PEER_LOCALMSPID=${LOCALMSPID}" -e "CORE_PEER_MSPCONFIGPATH=${PEER_MSPCONFIGPATH}" -e "CORE_PEER_ADDRESS=${PEER_ADDRESS}" ${CLI} peer channel join -b /etc/hyperledger/artifacts/${CHANNEL_NAME}.block

## Update anchor of peer
docker exec -e "CORE_PEER_LOCALMSPID=${LOCALMSPID}" -e "CORE_PEER_MSPCONFIGPATH=${PEER_MSPCONFIGPATH}" -e "CORE_PEER_ADDRESS=${PEER_ADDRESS}" ${CLI} peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME} -f /etc/hyperledger/artifacts/Org1MSPanchors.tx

## Install chaincode to peer
docker exec -e "CORE_PEER_LOCALMSPID=${LOCALMSPID}" -e "CORE_PEER_MSPCONFIGPATH=${PEER_MSPCONFIGPATH}" -e "CORE_PEER_ADDRESS=${PEER_ADDRESS}" ${CLI} peer chaincode install -n ${CHAINCODE_NAME} -p ${CHAINCODE_SRC} -v ${CHAINCODE_VERSION}

sleep 10

# Instantiate chaincode
docker exec -e "CORE_PEER_LOCALMSPID=${LOCALMSPID}" -e "CORE_PEER_MSPCONFIGPATH=${PEER_MSPCONFIGPATH}" -e "CORE_PEER_ADDRESS=${PEER_ADDRESS}" ${CLI} peer chaincode instantiate -o ${ORDERER_ADDRESS} -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} -v ${CHAINCODE_VERSION} -c '{"Args":[""]}' -P "OR ('Org1MSP.member')"

sleep 10

# Generate CA admin & user
docker exec ${API} node ./scripts/enrollAdmin.js ${CA_ADMIN_PASSWORD}
docker exec ${API} node ./scripts/registerUser.js ${USER_NAME}
