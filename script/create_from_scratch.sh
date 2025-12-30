#!/bin/bash

# Install packer
if ! (which packer > /dev/null); then
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update && sudo apt-get install packer
fi

# Install OpenTofu
if ! (which tofu > /dev/null); then
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://get.opentofu.org/opentofu.gpg | sudo tee /etc/apt/keyrings/opentofu.gpg >/dev/null
    curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey | sudo gpg --no-tty --batch --dearmor -o /etc/apt/keyrings/opentofu-repo.gpg >/dev/null
    sudo chmod a+r /etc/apt/keyrings/opentofu.gpg /etc/apt/keyrings/opentofu-repo.gpg
    echo \
    "deb [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main
    deb-src [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" | \
    sudo tee /etc/apt/sources.list.d/opentofu.list > /dev/null
    sudo chmod a+r /etc/apt/sources.list.d/opentofu.list
    sudo apt-get update
    sudo apt-get install -y tofu
fi

# Install ansible and ansible-galaxy dependencies (TODO: install galaxy deps through packer)
if ! (which ansible > /dev/null); then
    sudo apt-get install python3 python3-pip pipx
    pipx ensurepath
    pipx install --include-deps ansible
fi
ansible-galaxy install -r configuration/requirements.yml
pip3 install -r configuration/requirements.txt

# Fill out .env
if [ ! -f .env ]; then
    echo ".env does not exist"
    exit 1
fi

sed -i "s/export BLUESKY_JWT_SECRET=fillmein/export BLUESKY_JWT_SECRET=$(openssl rand --hex 16)" .env
sed -i "s/export BLUESKY_PLC_ROTATION_KEY=fillmein/export BLUESKY_PLC_ROTATION_KEY=$(openssl ecparam --name secp256k1 --genkey --noout --outform DER | tail --bytes=+8 | head --bytes=32 | xxd --plain --cols 32)" .env
sed -i "s/export BLUESKY_ADMIN_PASSWORD=fillmein/export BLUESKY_ADMIN_PASSWORD=$(openssl rand --hex 16)" .env
sed -i "s/export INFISICAL_ENCRYPTION_KEY=fillmein/export INFISICAL_ENCRYPTION_KEY=$(openssl rand --hex 16)" .env
sed -i "s/export INFISICAL_AUTH_SECRET=fillmein/export INFISICAL_AUTH_SECRET=$(openssl rand -base64 32)" .env
sed -i "s/export TANDOOR_SECRET_KEY=fillmein/export TANDOOR_SECRET_KEY=$(openssl rand --hex 16)" .env

if grep -q fillmein .env; then
    echo ".env has placeholder values"
    exit 1
fi

# Build templates
source .env
cd configuration/packer
packer build -except "proxmox-clone.*" .
sleep 10
packer build -only "proxmox-clone.*" .
sleep 10

# Create resources
cd ../../provisioner
tofu apply -auto-approve

# Done!
clear
echo "Homelab provisioning complete!"