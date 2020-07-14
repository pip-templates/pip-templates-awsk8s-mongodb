#!/bin/sh

# Install brew package manager
xcode-select --install
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew update

# Install powershell
brew install openssl
brew install curl --with-openssl
brew cask install powershell

# Install AWS Cli
brew install awscli

# Install other tools
brew install mongodb