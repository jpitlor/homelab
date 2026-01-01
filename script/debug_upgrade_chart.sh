#!/bin/bash

source .env
cd configuration
git pull origin main
ansible-playbook ./configure-templates.yml --tags "docker_containers"
