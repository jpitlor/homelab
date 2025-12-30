#!/bin/bash

su root -- -x -c '/usr/sbin/qm stop 104 && /usr/sbin/qm destroy 104 && /usr/sbin/qm destroy 901'

cd ~/homelab-configuration
source .env
git pull
cd packer
packer build -only "proxmox-clone.docker*" .
sleep 10

cd ~/homelab-provisioner
tofu apply -auto-approve
sleep 5

cd ~/homelab-configuration
ssh-keygen -R 192.168.0.116
ansible-playbook ./configure-machines.yml