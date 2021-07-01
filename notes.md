## Install Azure CLI

https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt

Log in with `az login`.

## Create resource group

Do this in the browser, as shown.

## Create a VM

Do this in the browser, as shown.

## Create a host alias and copy key

Add this to ~/.ssh/config

    Host vm
        HostName ...
        User ...

The HostName should be the IP address of the VM, and the User should be the
username. By default it's 'azureuser' but check that when you make the VM. If
you make a VM using `az vm create` the remote user will be the same as the local
user.

Then do

    ssh-copy-id vm

and give all the right answers.

## SSH to the VM

Just do

    ssh vm

At this point you can install docker

    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh

Confirm that it's working:

    sudo docker run hello-world

To run docker containers without sudo you have to do

    sudo usermod -aG docker $USER

Then log in and out. You should be able to do:

    docker run hello-world

At this point you might want to run `docker pull thebb/ifem`.

## Copy case to VM

    scp substructure.xinp vm:

## Run case

    docker run -v$(pwd):/workdir --workdir /workdir thebb/ifem bash -c 'LinEl substructure.xinp -hdf5 -petsc'

## MPI

    echo "localhost slots=$(nprocs)" > hostfile
    docker run --cap-add SYS_PTRACE -v$(pwd):/workdir --workdir /workdir thebb/ifem \
        bash -c 'mpirun -np 2 LinEl substructure.xinp -hdf5 -petsc'

## SISO

    docker run -v$(pwd):/workdir --workdir thebb/ifem bash -c 'siso substructure.hdf5 -f vts --last'

## Convenience bash function

Add this to `.bashrc`:

    ifem () {
        docker run --cap-add SYS_PTRACE -v$(pwd):/workdir --workdir /workdir thebb/ifem bash -c "$*"
    }

Then log out and in (or source the .bashrc). The last three examples can now be
run as:

    ifem LinEl substructure.xinp -hdf5 -petsc
    ifem mpirun --hostfile hostfile -np 2 LinEl substructure.xinp -hdf5 -petsc
    ifem siso substructure.hdf5 -f vts --last

## Extreme convenience setup script

Add this to a script and run it as `./script vm my.ip.address`.

Note, this will rewrite your ~/.ssh/config and it requires that there is an
existing entry there called 'Host vm'.

This script does all of the above except create the resource group and the VM.
It also doesn't do `ssh-copy-id`.  You must supply the desired host alias and
the IP address.

    #!/bin/sh

    cat ~/.ssh/config |\
        tr '\n' '#' |\
        sed -e "s/\(Host $1#\s*HostName\) [^#]*/\1 $2/" |\
        tr '#' '\n' > /tmp/sshconf
    mv /tmp/sshconf ~/.ssh/config

    ssh $1 <<'ENDSSH'
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    sudo usermod -aG docker $USER
    echo "localhost slots=$(nproc)" > hostfile
    echo 'ifem () { docker run --cap-add SYS_PTRACE -v$(pwd):/workdir --workdir /workdir thebb/ifem bash -c "$*"; }' >> .bashrc
    ENDSSH

    ssh $1 <<'ENDSSH'
    docker pull thebb/ifem
    ENDSSH

## Start from the CLI

These are the commands for creating a resource group and a VM from the command
line. For this to work you have to do `az login` first.

Note that if you start a VM this way, `ssh-copy-id` should be unnecessary, as
the public key is part of the setup.

    az group create --name AutoGrp --location northeurope
    az vm create --resource-group AutoGrp --name AutoVM --image UbuntuLTS --ssh-key-values ~/.ssh/id_rsa.pub --size Standard_D2s_v3

## Ultra convenience startup script

This combines the two in one. It creates a VM and sets up Docker and IFEM there.

Use it like `./setup.sh vm Standard_D2s_v3`. This requires `jq` to be installed.

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

    ssh $1 <<'ENDSSH'
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    sudo usermod -aG docker $USER
    echo "localhost slots=$(nproc)" > hostfile
    echo 'ifem () { docker run --cap-add SYS_PTRACE -v$(pwd):/workdir --workdir /workdir thebb/ifem bash -c "$*"; }' >> .bashrc
    ENDSSH

    ssh $1 <<'ENDSSH'
    docker pull thebb/ifem
    ENDSSH

## Ultra convenience teardown script

`./teardown.sh vm`

    #!/bin/sh

    IP=$(az vm list-ip-addresses --name AutoVM | jq -r '.[0].virtualMachine.network.publicIpAddresses[0].ipAddress')

    yes | ssh-keygen -R $IP
    az group delete --yes --name AutoGrp
