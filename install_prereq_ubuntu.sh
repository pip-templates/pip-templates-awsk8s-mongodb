#!/bin/bash

# Install Powershell
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/microsoft.list
sudo apt-get update
sudo apt-get install -y powershell

# Install AWS Cli
sudo apt-get install -y python-setuptools python-dev build-essential
sudo easy_install pip 
sudo pip install awscli

# Install other tools
sudo apt-get install -y mongodb-clients
