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
Set-EnvConfigCloudDefaults -Config $config

$group_name = ("mgmt-peering." + $config.env_name).Replace(".", "-")

# Find security group
Write-Host "Searching for security group $group_name ..."
$out = (aws ec2 describe-security-groups --region $config.aws_region --filters "Name=group-name,Values=$group_name" "Name=vpc-id,Values=$($resources.env_vpc)" --query "SecurityGroups[].GroupId" --output "text") | Out-String
$group_id = $out.Replace("`n", "").Replace("`t", " ").Split(" ")[0]

if ($group_id -ne $null -and $group_id -ne "") {
    Write-Host "Finding all instances in $($config.env_name) environment"
    $out = (aws ec2 describe-instances --region $config.aws_region --filters "Name=tag:Environment,Values=$($config.env_name)") | Out-String
    $reservations = ($out | ConvertFrom-Json).Reservations

    foreach ($reservation in $reservations) {
        foreach ($instance in $reservation.Instances) {
            if ($instance.State.Name -eq "terminated") {
                continue;
            }

            $group_ids = @()
            foreach ($group in $instance.SecurityGroups) {
                if ($group.GroupId -ne $group_id) {
                    $group_ids += $group.GroupId
                }
            }
            Write-Host "Closing access from mgmt VPC to instance $($instance.InstanceId)..."
            aws ec2 modify-instance-attribute --region $config.aws_region --instance-id $instance.InstanceId --groups $group_ids
        }
    }

    # Delete security group
    Write-Host "Deleting security group $group_name ..."
    aws ec2 delete-security-group --region $config.aws_region --group-id $group_id
    Write-Host "Deleted security group $group_name"
}

if ($resources.mgmt_peering -ne $null) {
    Write-Host "Deleting peering connection with mgmt VPC..."
    Write-Host "$($resources.mgmt_peering)"
    aws ec2 delete-vpc-peering-connection --region $config.aws_region --vpc-peering-connection-id $resources.mgmt_peering | Out-Null
    Write-Host "Deleted peering connection with mgmt VPC."
}

# Get route tables
$out = (aws ec2 describe-route-tables --region $config.aws_region --filters "Name=vpc-id,Values=$($config.mgmt_vpc)" "Name=route.destination-cidr-block,Values=$($config.env_network_cidr)" --query "RouteTables[].RouteTableId" --output "text") | Out-String
$mgmt_routes = $out.Replace("`n", "").Replace("`t", " ").Split(" ")
Write-Host "Found mgmt route table $mgmt_routes."

$out = (aws ec2 describe-route-tables --region $config.aws_region --filters "Name=vpc-id,Values=$($resources.env_vpc)" "Name=route.destination-cidr-block,Values=$($config.mgmt_network_cidr)" --query "RouteTables[].RouteTableId" --output "text") | Out-String
$aws_routes = $out.Replace("`n", "").Replace("`t", " ").Split(" ")
Write-Host "Found AWS route table $aws_routes."

# Delete routes
foreach ($mgmt_route in $mgmt_routes) {
    aws ec2 delete-route --region $config.aws_region --route-table-id $mgmt_route --destination-cidr-block $config.env_network_cidr | Out-Null
}
foreach ($aws_route in $aws_routes) {
  aws ec2 delete-route --region $config.aws_region --route-table-id $aws_route --destination-cidr-block $config.mgmt_network_cidr | Out-Null
}
Write-Host "Deleted routes between AWS and mgmt networks"

# Write peering resources
$resources.mgmt_peering = $null

Write-EnvResources -Path $ConfigPath -Resources $resources