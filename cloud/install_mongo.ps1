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

# Retrieving organization
Write-Host "Retrieving Mongo Cloud organization $($config.mongo_org_name)"
$out = Invoke-MongoCloud `
    -Method GET `
    -Username $config.mongo_access_id `
    -ApiKey $config.mongo_access_key `
    -Route "/orgs"
foreach ($result in $out.results) {
    if ($result.name -eq $config.mongo_org_name) {
        $mongo_org = $result.id
    }
}
if ($mongo_org -eq $null) {
    throw "Mongo Cloud organization $($config.mongo_org_name) was not found"
}
Write-Host "Found Mongo Cloud organization $($config.mongo_org_name) with id $mongo_org"

# Finding group
Write-Host "Finding Mongo Cloud group $($config.mongo_group_name)..."
$body = @{
    name = $config.mongo_group_name;
    orgId = $mongo_org;
}
$out = Invoke-MongoCloud `
    -Method GET `
    -Username $config.mongo_access_id `
    -ApiKey $config.mongo_access_key `
    -Route "/groups/byName/$($config.mongo_group_name)" `
    -IgnoreNotFound -IgnoreUnauthorized
if ($out -ne $null) {
    $mongo_group = $out.id
    Write-Host "Found Mongo Cloud group $mongo_group"
}

# Creating group
if ($mongo_group -eq $null) {
    Write-Host "Creating Mongo Cloud group $($config.mongo_group_name)..."
    $body = @{
        name = $config.mongo_group_name;
        orgId = $mongo_org;
    }
    $out = Invoke-MongoCloud `
        -Method POST `
        -Username $config.mongo_access_id `
        -ApiKey $config.mongo_access_key `
        -Route "/groups" `
        -Body $body 
    $mongo_group = $out.id
    Write-Host "Created Mongo Cloud group $mongo_group"
}

# Finding mongo cluster
Write-Host "Finding Mongo Cloud cluster $($config.mongo_cluster_name)..."
$out = Invoke-MongoCloud `
    -Method GET `
    -Username $config.mongo_access_id `
    -ApiKey $config.mongo_access_key `
    -Route "/groups/$mongo_group/clusters/$($config.mongo_cluster_name)" `
    -IgnoreNotFound
if ($out -ne $null -and $out.mongoURI -ne $null) {
    $mongo_cluster = $out.id
    $mongo_connect = $out.mongoURI.Replace("mongodb://", "")
    $mongo_uri = $out.mongoURIWithOptions
    $mongo_prebuilt = $true
    Write-Host "Found Mongo Cloud cluster $mongo_cluster"
} else {
    $mongo_prebuilt = $false
}

# Create mongo cluster
if (-not $mongo_prebuilt) {
    Write-Host "Creating Mongo Cloud cluster $($config.mongo_cluster_name)..."
    $mongo_region = $config.aws_region.ToUpper().Replace("-", "_")
    $body = @{
        name = $config.mongo_cluster_name;
        diskSizeGB = $config.mongo_size;
        numShards = $config.mongo_shards;
        providerSettings = @{
            providerName = "AWS";
            encryptEBSVolume = $false;
            instanceSizeName = $config.mongo_instance_type;
            regionName = $mongo_region;
        };
        replicationFactor = 3;
        replicationSpec = @{};
        backupEnabled = $config.mongo_backup;
        autoScaling = @{ diskGBEnabled = $true }
    }
    $body.replicationSpec[$mongo_region] = @{
        electableNodes = 3;
        priority = 7;
        readOnlyNodes = 0;
    }
    $out = Invoke-MongoCloud `
        -Method POST `
        -Username $config.mongo_access_id `
        -ApiKey $config.mongo_access_key `
        -Route "/groups/$mongo_group/clusters" `
        -Body $body 

    # Wait until cluster is created and read parameters
    Write-Host "Waiting for Mongo Cloud cluster to be created. It may take from 7 to 15 minutes..."
    while ($true) {
        $out = Invoke-MongoCloud `
            -Method GET `
            -Username $config.mongo_access_id `
            -ApiKey $config.mongo_access_key `
            -Route "/groups/$mongo_group/clusters/$($config.mongo_cluster_name)" 

        if ($out.mongoURI -ne $null) {
            $mongo_cluster = $out.id
            $mongo_connect = $out.mongoURI.Replace("mongodb://", "")
            $mongo_uri = $out.mongoURIWithOptions
    
            Write-Host "Created Mongo Cloud cluster $mongo_cluster"
            break
        } else {
            Start-Sleep -Seconds 20
        }
    }
}

# Delete mongo user
Write-Host "Deleting database user $($config.mongo_user)..."
$out = Invoke-MongoCloud `
    -Method DELETE `
    -Username $config.mongo_access_id `
    -ApiKey $config.mongo_access_key `
    -Route "/groups/$mongo_group/databaseUsers/admin/$($config.mongo_user)" `
    -IgnoreNotFound

# Create mongo user
Write-Host "Creating database user $($config.mongo_user)..."
$body = @{
    databaseName = "admin";
    groupId = $config.mongo_group;
    username = $config.mongo_user;
    roles = @(
        @{ databaseName = "admin"; roleName = "readWriteAnyDatabase" }
    );
    password = $config.mongo_pass
}
$out = Invoke-MongoCloud `
    -Method POST `
    -Username $config.mongo_access_id `
    -ApiKey $config.mongo_access_key `
    -Route "/groups/$mongo_group/databaseUsers" `
    -Body $body
Write-Host "Created database user $($config.mongo_user)"

# Read mongo parameters
Write-Host "Retrieving mongo vpc parameters..."
$out = Invoke-MongoCloud `
    -Method GET `
    -Username $config.mongo_access_id `
    -ApiKey $config.mongo_access_key `
    -Route "/groups/$mongo_group/containers" 

$mongo_vpc = $null
$mongo_network_cidr = $null
$mongo_container = $null
foreach ($cluster in $out.results) {
    if ($cluster.regionName -eq $mongo_region) {
        $mongo_vpc = $cluster.vpcId
        $mongo_network_cidr = $cluster.atlasCidrBlock
        $mongo_container = $cluster.id

        Write-Host "Found cluster vpc $mongo_vpc"
    }
}

# Calculate mongo connection parameters
$mongo_addresses = $mongo_connect.Replace(":27017", "").Split(",")
$mongo_address = $mongo_addresses[0].Replace("-shard-00-00", "").Replace("-shard-00-01", "").Replace("-shard-00-01", "")

$mongo_enc_user = [System.Web.HttpUtility]::UrlEncode($config.mongo_user)
$mongo_enc_pass = [System.Web.HttpUtility]::UrlEncode($config.mongo_pass)
$mongo_uri = $mongo_uri.Replace("mongodb://", "mongodb://$($mongo_enc_user):$($mongo_enc_pass)@")
$mongo_uri = $mongo_uri.Replace("/?", "/$($config.mongo_db)?")
    
# Write Mongo Cloud resources
$resources.mongo_org = $mongo_org
$resources.mongo_group = $mongo_group
$resources.mongo_cluster = $mongo_cluster
$resources.mongo_addresses = $mongo_addresses
$resources.mongo_address = $mongo_address
$resources.mongo_connect = $mongo_connect
$resources.mongo_uri = $mongo_uri
$resources.mongo_user = $config.mongo_user
$resources.mongo_pass = $config.mongo_pass
$resources.mongo_vpc = $mongo_vpc
$resources.mongo_network_cidr = $mongo_network_cidr
$resources.mongo_container = $mongo_container
$resources.mongo_prebuilt = $mongo_prebuilt

# Write Mongo Cloud resources
Write-EnvResources -Path $ConfigPath -Resources $resources