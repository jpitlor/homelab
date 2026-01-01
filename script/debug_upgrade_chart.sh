#!/bin/bash

source .env
cd configuration
git pull origin main
ansible-playbook ./configure-containers.yml
