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

if ($config.mgmt_vpc -eq $null) {
    Write-Host "Peering with mgmt VPC is disabled. Skipping..."
    return
}

# Set default values for config parameters
Set-EnvConfigCloudDefaults -Config $config -All | Out-Null

Write-Host "Creating peering connection with mgmt VPC..."

$out = (aws ec2 create-vpc-peering-connection --region $config.aws_region --peer-region $config.aws_region --vpc-id $config.mgmt_vpc --peer-vpc-id $resources.env_vpc) | Out-String
$mgmt_peering = ($out | ConvertFrom-Json).VpcPeeringConnection.VpcPeeringConnectionId

# Accept peering
aws ec2 accept-vpc-peering-connection --region $config.aws_region --vpc-peering-connection-id $mgmt_peering | Out-Null
Write-Host "Created peering connection with mgmt VPC $($config.mgmt_vpc)."

# Enable DNS resolution
aws ec2 modify-vpc-peering-connection-options --region $config.aws_region --vpc-peering-connection-id $mgmt_peering --accepter-peering-connection-options AllowDnsResolutionFromRemoteVpc=true | Out-Null
aws ec2 modify-vpc-peering-connection-options --region $config.aws_region --vpc-peering-connection-id $mgmt_peering --requester-peering-connection-options AllowDnsResolutionFromRemoteVpc=true | Out-Null

# Get route tables
$out = (aws ec2 describe-route-tables --region $config.aws_region --filters "Name=vpc-id,Values=$($config.mgmt_vpc)" "Name=route.destination-cidr-block,Values=0.0.0.0/0" --query "RouteTables[].RouteTableId" --output "text") | Out-String
$mgmt_routes = $out.Replace("`n", "").Replace("`t", " ").Split(" ")
Write-Host "Found mgmt route table $mgmt_routes."

$out = (aws ec2 describe-route-tables --region $config.aws_region --filters "Name=vpc-id,Values=$($resources.env_vpc)" "Name=route.destination-cidr-block,Values=0.0.0.0/0" --query "RouteTables[].RouteTableId" --output "text") | Out-String
$aws_routes = $out.Replace("`n", "").Replace("`t", " ").Split(" ")
Write-Host "Found AWS route table $aws_routes."

# Add routes
foreach ($mgmt_route in $mgmt_routes) {
    aws ec2 create-route --region $config.aws_region --route-table-id $mgmt_route --destination-cidr-block $config.env_network_cidr --vpc-peering-connection-id $mgmt_peering | Out-Null
}
foreach ($aws_route in $aws_routes) {
    aws ec2 create-route --region $config.aws_region --route-table-id $aws_route --destination-cidr-block $config.mgmt_network_cidr --vpc-peering-connection-id $mgmt_peering | Out-Null
}
Write-Host "Added routes between AWS and mgmt networks"


# Create security group
$group_name = ("mgmt-peering." + $config.env_name).Replace(".", "-")
Write-Host "Creating security group $group_name ..."
$out = aws ec2 create-security-group `
    --region $config.aws_region `
    --group-name $group_name `
    --vpc-id $resources.env_vpc `
    --description "Open access for mgmt VPC"

$out = $out | ConvertFrom-Json
$group_id = $out.GroupId

if ($group_id -eq $null) {
    Write-Host "Security group creation failed. Close access before opening a new one. Existing..."
    return
}

Write-Host "Created security group $group_id"

# Set ingress rules
Write-Host "Adding ingress rules for all ports"
aws ec2 authorize-security-group-ingress --region $config.aws_region --group-id $group_id --protocol all --port 1-65535 --cidr $config.mgmt_network_cidr
aws ec2 authorize-security-group-ingress --region $config.aws_region --group-id $group_id --protocol icmp --port -1 --cidr $config.mgmt_network_cidr

# Find instances to open
Write-Host "Finding all instances in $($config.env_name) environment"
$out = (aws ec2 describe-instances --region $config.aws_region --filters "Name=tag:Environment,Values=$($config.env_name)") | Out-String
$reservations = ($out | ConvertFrom-Json).Reservations

foreach ($reservation in $reservations) {
    foreach ($instance in $reservation.Instances) {
        if ($instance.State.Name -eq "terminated") {
            continue;
        }

        $group_ids = @( $group_id )
        foreach ($group in $instance.SecurityGroups) {
            $group_ids += $group.GroupId
        }
        Write-Host "Opening access from mgmt VPC to instance $($instance.InstanceId)..."
        aws ec2 modify-instance-attribute --region $config.aws_region --instance-id $instance.InstanceId --groups $group_ids
    }
}

Write-Host "Peer connections with mgmt VPC was successfully created."

# Write peering resources
$resources.mgmt_peering = $mgmt_peering

Write-EnvResources -Path $ConfigPath -Resources $resources