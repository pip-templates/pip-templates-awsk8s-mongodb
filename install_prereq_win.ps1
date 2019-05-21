#!/usr/bin/env pwsh

Write-Host "Remember to run this script as Administrator!"

Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install AWS Cli
choco install --yes awscli

# Install other tools
choco install --yes mongodb