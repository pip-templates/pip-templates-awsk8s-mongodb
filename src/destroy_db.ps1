#!/usr/bin/env pwsh

param
(
    [Alias("c", "Path")]
    [Parameter(Mandatory=$true, Position=0)]
    [string] $ConfigPath,
    [Alias("p")]
    [Parameter(Mandatory=$false, Position=1)]
    [string] $Prefix
)

# Load support functions
$path = $PSScriptRoot
if ($path -eq "") { $path = "." }
. "$($path)/../lib/include.ps1"
$path = $PSScriptRoot
if ($path -eq "") { $path = "." }

# Read config and resources
$config = Read-EnvConfig -Path $ConfigPath
$resources = Read-EnvResources -Path $ConfigPath

# Skip if mongo disabled
if (-not $config.mongo_enabled) {
    Write-Host "Mongo Cloud is disabled. Skipping..."
    return;
}

# Set default values for config parameters
Set-EnvConfigCloudDefaults -Config $config


# Deleting mongo cluster
if (-not $resources.mongo_prebuilt -or $resources.mongo_prebuilt -eq $null) {
    Write-Host "Deleting cluster $($config.mongo_cluster_name)..."
    Invoke-MongoCloud `
        -Method DELETE `
        -Username $config.mongo_access_id `
        -ApiKey $config.mongo_access_key `
        -Route "/groups/$($resources.mongo_group)/clusters/$($config.mongo_cluster_name)" `
        -Body $body | Out-Null
    Write-Host "Cluster $($config.mongo_cluster_name) deleted."
}


# Write Mongo resources
$resources.mongo_org = $null
$resources.mongo_group = $null
$resources.mongo_cluster = $null
$resources.mongo_addresses = @()
$resources.mongo_address = $null
$resources.mongo_connect = $null
$resources.mongo_uri = $null
$resources.mongo_user = $null
$resources.mongo_pass = $null
$resources.mongo_vpc = $null
$resources.mongo_network_cidr = $null
$resources.mongo_container = $null
$resources.mongo_prebuilt = $null

# Write Mongo Cloud resources
Write-EnvResources -Path $ConfigPath -Resources $resources