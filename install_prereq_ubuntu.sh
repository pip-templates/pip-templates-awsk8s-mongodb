#!/bin/bash

# Install AWS Cli
sudo apt-get install -y python-setuptools python-dev build-essential
sudo easy_install pip 
sudo pip install awscli

# Install other tools
sudo apt-get install -y mongodb-clients
