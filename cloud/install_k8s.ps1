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

# Set default values for config parameters
Set-EnvConfigCloudDefaults -Config $config -All | Out-Null

# Set environment variables
$env:KOPS_STATE_STORE = $config.k8s_s3_store

# Check for S3 bucket and create one if needed
$out = (aws s3api list-buckets --query "Buckets[].Name" --output="text") | Out-String
$buckets = $out.Replace("`n", "").Replace("`t", " ").Split(" ") | foreach($_) { "s3://" + $_ }
if (-not $buckets.Contains($config.k8s_s3_store)) {
    aws s3 mb $config.k8s_s3_store --region $config.aws_region | Out-Null
    Write-Host "Created S3 bucket for kops store $($config.k8s_s3_store)."
}

# Create ssh key
if ($config.k8s_ssh_new) {
    Remove-Item -Path "$($config.k8s_ssh_key)*"
    ssh-keygen -q -t rsa -f $config.k8s_ssh_key
}

# Create cluster
Write-Host "Creating Kubernetes cluster $($config.env_name)..."
kops create cluster `
--yes `
--cloud=aws `
"--name=$($config.k8s_dns_zone)" `
"--dns-zone=$($config.k8s_dns_zone)" `
"--master-zones=$($config.k8s_master_zones -join ',')" `
"--zones=$($config.k8s_node_zones -join ',')" `
"--node-count=$($config.k8s_node_count)" `
"--node-size=$($config.k8s_instance_type)" `
"--master-count=$($config.k8s_master_count)" `
"--master-size=$($config.k8s_instance_type)" `
"--state=$($config.k8s_s3_store)" `
"--image=$($config.k8s_ami)" `
"--ssh-public-key=$($config.env_ssh_key).pub" `
"--cloud-labels=Role=k8s,Environment=$($config.env_name)" `
--encrypt-etcd-storage `
"--network-cidr=$($config.env_network_cidr)" `
"--ssh-access=$($config.mgmt_network_cidr)" `
--networking=weave `
"--kubernetes-version=$($config.k8s_version)" `
#--topology=private `
#--dns=private `
# --authorization=RBAC `

# Wait until instances are created
Write-Host "Waiting for $($config.env_name) cluster to start..."
aws ec2 wait instance-running --region $config.aws_region --filters "Name=tag:Environment,Values=$($config.env_name)" "Name=tag:Role,Values=k8s"

# Read kubernetes IP addresses
while ($true) {
    $out = (aws ec2 describe-instances --region "$($config.aws_region)" --filters "Name=tag:Environment,Values=$($config.env_name)" "Name=tag:Role,Values=k8s" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].PrivateIpAddress" --output "text") | Out-String
    $k8s_nodes = $out.Replace("`n", "").Replace("`t", " ").Split(" ")
    if ($k8s_nodes.Length -gt 1) { break; }
    
    Write-Host "Did not find k8 nodes. Retrying..."
    Start-Sleep -Seconds 5
}

$k8s_inventory = @()
foreach ($node in $k8s_nodes) {
    $inventory = $node + " ansible_ssh_user=ubuntu ansible_ssh_private_key_file=$($config.env_ssh_key)"
    $k8s_inventory += $inventory
}

# Read VPC parameters
$out = (aws ec2 describe-vpcs --region $config.aws_region --filters "Name=tag:KubernetesCluster,Values=$($config.k8s_dns_zone)" --query "Vpcs[].VpcId" --output "text") | Out-String
$env_vpc = $out.Replace("`n", "").Replace("`t", " ").Split(" ")[0]

$out = (aws ec2 describe-subnets --region $config.aws_region --filters "Name=tag:KubernetesCluster,Values=$($config.k8s_dns_zone)" --query "Subnets[].SubnetId" --output "text") | Out-String
$env_subnet = $out.Replace("`n", "").Replace("`t", " ").Split(" ")[0]

$out = (aws ec2 describe-instances --region $config.aws_region --filters "Name=tag:KubernetesCluster,Values=$($config.k8s_dns_zone)" "Name=tag:Role,Values=k8s" "Name=instance-state-name,Values=running"  --query "Reservations[].Instances[].KeyName" --output "text") | Out-String
$env_keyname = $out.Replace("`n", "").Replace("`t", " ").Split(" ")[0]

Write-Host "K8s cluster $($config.env_name) was successfully created."

# Write k8s resources
$resources.k8s_type = "kops"
$resources.k8s_nodes = @($k8s_nodes)
$resources.k8s_address = "api." + $config.k8s_dns_zone
$resources.k8s_inventory = $k8s_inventory

$resources.env_vpc = $env_vpc
$resources.env_subnet = $env_subnet
$resources.env_keyname = $env_keyname

Write-EnvResources -Path $ConfigPath -Resources $resources