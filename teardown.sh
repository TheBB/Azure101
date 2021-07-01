#!/bin/sh

IP=$(az vm list-ip-addresses --name AutoVM | jq -r '.[0].virtualMachine.network.publicIpAddresses[0].ipAddress')

yes | ssh-keygen -R $IP
az group delete --yes --name AutoGrp
