#!/bin/sh

az group create --name AutoGrp --location northeurope
az vm create --resource-group AutoGrp --name AutoVM --image UbuntuLTS --ssh-key-values ~/.ssh/id_rsa.pub --size $2
USER=$(az vm show --resource-group AutoGrp --name AutoVM | jq -r '.osProfile.adminUsername')
IP=$(az vm list-ip-addresses --name AutoVM | jq -r '.[0].virtualMachine.network.publicIpAddresses[0].ipAddress')

ssh-keyscan -H $IP >> ~/.ssh/known_hosts

cat ~/.ssh/config |\
    tr '\n' '#' |\
    sed -e "s/\(Host $1#\s*HostName\) [^#]*\(#\s*User\) [^#]*/\1 $IP\2 $USER/" |\
    tr '#' '\n' > temp
mv temp ~/.ssh/config

ssh vm <<'ENDSSH'
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm get-docker.sh
sudo usermod -aG docker $USER
echo "localhost slots=$(nproc)" > hostfile
ENDSSH

ssh vm <<'ENDSSH'
docker pull thebb/ifem
echo 'ifem () { docker run --cap-add SYS_PTRACE -v$(pwd):/workdir --workdir /workdir thebb/ifem bash -c "$*"; }' >> .bashrc
ENDSSH
