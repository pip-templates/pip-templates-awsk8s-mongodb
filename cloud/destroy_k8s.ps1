#!/usr/bin/env pwsh

param
(
    [Alias("c", "Path")]
    [Parameter(Mandatory=$false, Position=0)]
    [string] $ConfigPath
)

# Load support functions
$path = $PSScriptRoot
if ($path -eq "") { $path = "." }
. "$($path)/../lib/include.ps1"

# Read config and resources
$config = Read-EnvConfig -Path $ConfigPath
$resources = Read-EnvResources -Path $ConfigPath

Set-EnvConfigCloudDefaults -Config $config -All | Out-Null

# Set environment variables
$env:KOPS_STATE_STORE = $config.k8s_s3_store

# Delete cluster
kops delete cluster `
--state $config.k8s_s3_store `
--name $config.k8s_dns_zone `
--yes

# Write k8s resources
$resources.k8s_type = $null
$resources.k8s_nodes = @()
$resources.k8s_address = $null
$resources.k8s_inventory = @()

$resources.env_vpc = $null
$resources.env_subnet = $null
$resources.env_keyname = $null

Write-EnvResources -Path $ConfigPath -Resources $resources