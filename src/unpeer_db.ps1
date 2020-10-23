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

# Close public access for shared cluster
if ($resources.mongo_container -eq $null) {
    Write-Host "Closing public access to shared mongo cluster.."
    
    $cidr = "0.0.0.0/0".Replace("/", "%2F")
    Invoke-MongoCloud `
        -Method DELETE `
    -Username $config.mongo_access_id `
    -ApiKey $config.mongo_access_key `
    -Route "/groups/$($resources.mongo_group)/whitelist/$cidr" `
    -IgnoreNotFound  

    return
}

# Get route tables
$out = (aws ec2 describe-route-tables --region $config.aws_region --filters "Name=vpc-id,Values=$($config.mgmt_vpc)" "Name=route.destination-cidr-block,Values=$($resources.mongo_network_cidr)" --query "RouteTables[].RouteTableId" --output "text") | Out-String
$mgmt_routes = $out.Replace("`n", "").Replace("`t", " ").Split(" ")
Write-Host "Found mgmt route table $mgmt_routes."

$out = (aws ec2 describe-route-tables --region $config.aws_region --filters "Name=vpc-id,Values=$($resources.env_vpc)" "Name=route.destination-cidr-block,Values=$($resources.mongo_network_cidr)" --query "RouteTables[].RouteTableId" --output "text") | Out-String
$env_routes = $out.Replace("`n", "").Replace("`t", " ").Split(" ")
Write-Host "Found AWS route table $env_routes."

# Delete routes
foreach ($mgmt_route in $mgmt_routes) {
    if ($mgmt_route -eq "") { continue }
    aws ec2 delete-route --region $config.aws_region --route-table-id $mgmt_route --destination-cidr-block $resources.mongo_network_cidr | Out-Null
}
foreach ($env_route in $env_routes) {
    if ($mgmt_route -eq "") { continue }
    aws ec2 delete-route --region $config.aws_region --route-table-id $env_route --destination-cidr-block $resources.mongo_network_cidr | Out-Null
}
Write-Host "Deleted routes between mongo, AWS and mgmt networks"


# Find peering connections
Write-Host "Finding peering connections with $($resources.mongo_vpc)..."
$out = Invoke-MongoCloud `
    -Method GET `
    -Username $config.mongo_access_id `
    -ApiKey $config.mongo_access_key `
    -Route "/groups/$($resources.mongo_group)/peers"

# Delete all peering connections
foreach ($peer in $out.results) {
    if ($peer.containerId -eq $resources.mongo_container) {
        Invoke-MongoCloud `
            -Method DELETE `
            -Username $config.mongo_access_id `
            -ApiKey $config.mongo_access_key `
            -Route "/groups/$($resources.mongo_group)/peers/$($peer.id)" | Out-Null   
        
        Write-Host "Deleted peer connection with $($peer.vpcId)."
    }
}

# Close access to mongo db
$cidr = $config.env_network_cidr.Replace("/", "%2F")
Invoke-MongoCloud `
    -Method DELETE `
    -Username $config.mongo_access_id `
    -ApiKey $config.mongo_access_key `
    -Route "/groups/$($resources.mongo_group)/whitelist/$cidr" `
    -IgnoreNotFound
Write-Host "Unpeered AWS VPC $($config.env_network_cidr)."

$cidr = $config.mgmt_network_cidr.Replace("/", "%2F")
Invoke-MongoCloud `
    -Method DELETE `
    -Username $config.mongo_access_id `
    -ApiKey $config.mongo_access_key `
    -Route "/groups/$($resources.mongo_group)/whitelist/$cidr" `
    -IgnoreNotFound
Write-Host "Unpeered mgmt VPC $($config.mgmt_network_cidr)."     
