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

# Open public access for shared cluster
if ($resources.mongo_container -eq $null) {
    Write-Host "Opening public access to shared mongo cluster.."

    $body = @(
        @{
            cidrBlock = "0.0.0.0/0"
            comment = "Public access"
        }
    )
    Invoke-MongoCloud `
        -Method POST `
        -Username $config.mongo_access_id `
        -ApiKey $config.mongo_access_key `
        -Route "/groups/$($resources.mongo_group)/whitelist" `
        -Body $body | Out-Null    
        
    return
}


# Create peering with environment
Write-Host "Creating vpc peering with AWS VPC $($resources.env_vpc)..."
$body = @{
    vpcId = $resources.env_vpc;
    awsAccountId = $config.aws_account_id;
    routeTableCidrBlock = $config.env_network_cidr;
    containerId = $resources.mongo_container
}
$out = Invoke-MongoCloud `
    -Method POST `
    -Username $config.mongo_access_id `
    -ApiKey $config.mongo_access_key `
    -Route "/groups/$($resources.mongo_group)/peers" `
    -Body $body
Write-Host "Created vpc peeting with AWS VPC $($resources.env_vpc)."

# Open access to mongo db
Write-Host "Opening access to AWS VPC.."
$body = @(
    @{
        cidrBlock = $config.env_network_cidr
        comment = "Peering with AWS VPC"
    }
)
Invoke-MongoCloud `
    -Method POST `
    -Username $config.mongo_access_id `
    -ApiKey $config.mongo_access_key `
    -Route "/groups/$($resources.mongo_group)/whitelist" `
    -Body $body | Out-Null


# Create peering with management VPC
Write-Host "Creating vpc peering with mgmt VPC $($config.mgmt_vpc)..."
$body = @{
    vpcId = $config.mgmt_vpc;
    awsAccountId = $config.aws_account_id;
    routeTableCidrBlock = $config.mgmt_network_cidr;
    containerId = $resources.mongo_container
}
$out = Invoke-MongoCloud `
    -Method POST `
    -Username $config.mongo_access_id `
    -ApiKey $config.mongo_access_key `
    -Route "/groups/$($resources.mongo_group)/peers" `
    -Body $body
Write-Host "Created vpc peeting with mgmt VPC $($config.mgmt_vpc)."

# Open access to mongo db
Write-Host "Opening access to mgmt VPC.."
$body = @(
    @{
        cidrBlock = $config.mgmt_network_cidr
        comment = "Peering with mgmt VPC"
    }
)
Invoke-MongoCloud `
    -Method POST `
    -Username $config.mongo_access_id `
    -ApiKey $config.mongo_access_key `
    -Route "/groups/$($resources.mongo_group)/whitelist" `
    -Body $body | Out-Null    


# Wait for peering connection
Write-Host "Waiting for peering connection..."
aws ec2 wait vpc-peering-connection-exists --region $config.aws_region --filter "Name=requester-vpc-info.vpc-id,Values=$($resources.mongo_vpc)" "Name=status-code,Values=pending-acceptance" | Out-Null

# Get peering connections
while ($true) {
    $out = (aws ec2 describe-vpc-peering-connections --region $config.aws_region --filter "Name=requester-vpc-info.vpc-id,Values=$($resources.mongo_vpc)" "Name=accepter-vpc-info.vpc-id,Values=$($config.mgmt_vpc)" "Name=status-code,Values=pending-acceptance" --query "VpcPeeringConnections[].VpcPeeringConnectionId" --output "text") | Out-String 
    $mgmt_peering = $out.Replace("`n", "").Replace("`t", " ").Split(" ")[0]

    $out = (aws ec2 describe-vpc-peering-connections --region $config.aws_region --filter "Name=requester-vpc-info.vpc-id,Values=$($resources.mongo_vpc)" "Name=accepter-vpc-info.vpc-id,Values=$($resources.env_vpc)" "Name=status-code,Values=pending-acceptance" --query "VpcPeeringConnections[].VpcPeeringConnectionId" --output "text") | Out-String 
    $aws_peering = $out.Replace("`n", "").Replace("`t", " ").Split(" ")[0]

    if ($mgmt_peering -ne "" -and $aws_peering -ne "") {
        break
    }

    Start-Sleep -Seconds 10
    Write-Host "Retrying peering connections..."
}

# Accept peering connections
aws ec2 accept-vpc-peering-connection --region $config.aws_region --vpc-peering-connection-id $mgmt_peering | Out-Null
Write-Host "Accepted peering connection $mgmt_peering."

aws ec2 accept-vpc-peering-connection --region $config.aws_region --vpc-peering-connection-id $aws_peering | Out-Null
Write-Host "Accepted peering connection $aws_peering."


# Get route tables
$out = (aws ec2 describe-route-tables --region $config.aws_region --filters "Name=vpc-id,Values=$($config.mgmt_vpc)" "Name=route.destination-cidr-block,Values=0.0.0.0/0" --query "RouteTables[].RouteTableId" --output "text") | Out-String
$mgmt_routes = $out.Replace("`n", "").Replace("`t", " ").Split(" ")
Write-Host "Found mgmt route table $mgmt_routes."

$out = (aws ec2 describe-route-tables --region $config.aws_region --filters "Name=vpc-id,Values=$($resources.env_vpc)" "Name=route.destination-cidr-block,Values=0.0.0.0/0" --query "RouteTables[].RouteTableId" --output "text") | Out-String
$env_routes = $out.Replace("`n", "").Replace("`t", " ").Split(" ")
Write-Host "Found AWS route table $env_routes."

# Add routes
foreach ($mgmt_route in $mgmt_routes) {
    aws ec2 create-route --region $config.aws_region --route-table-id $mgmt_route --destination-cidr-block $resources.mongo_network_cidr --vpc-peering-connection-id $mgmt_peering | Out-Null
}
foreach ($env_route in $env_routes) {
    aws ec2 create-route --region $config.aws_region --route-table-id $env_route --destination-cidr-block $resources.mongo_network_cidr --vpc-peering-connection-id $aws_peering | Out-Null
}
Write-Host "Added routes between mongo, AWS and mgmt networks"
