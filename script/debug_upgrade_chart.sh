#!/bin/bash

git submodule update
su root -- -x -c '/usr/sbin/qm stop 104 && /usr/sbin/qm destroy 104 && /usr/sbin/qm destroy 901'

cd configuration
source .env
git pull
cd packer
packer build -only "proxmox-clone.docker*" .
sleep 15

cd ../provisioner
tofu apply -auto-approve
sleep 15

cd ../configuration
ssh-keygen -R 192.168.0.116
ansible-playbook ./configure-machines.yml
