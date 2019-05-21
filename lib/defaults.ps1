function Set-EnvConfigCommonDefaults
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [hashtable] $Config
    )
    
    if ($Config.mongo_db -eq $null) {
        $Config.mongo_db = "tracker"
    }
    if ($Config.mongo_user -eq $null) {
        $Config.mongo_user = "positron"
    }
    if ($Config.mongo_pass -eq $null) {
        $Config.mongo_pass = "positron#123"
    }
}

function Set-EnvConfigLocalDefaults
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [hashtable] $Config
    )
    
    Set-EnvConfigCommonDefaults -Config $Config

    if ($Config.k8s_version -eq $null) {
        $Config.k8s_version = "1.8.0"
    }
    if ($Config.k8s_address -eq $null) {
        $Config.k8s_address = "192.168.99.100"
    }        
    if ($Config.k8s_driver -eq $null) {
        $Config.k8s_driver = "virtualbox"
    }
    if ($Config.k8s_ssh_key -eq $null) {
        $Config.k8s_ssh_key  = "~/.ssh/id_rsa"
    }
}

function Set-EnvConfigCloudDefaults
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [hashtable] $Config,
        [Parameter(Mandatory=$false, Position=1)]
        [switch] $All
    )
    
    Set-EnvConfigCommonDefaults -Config $Config

    # Set environment variables
    $env:AWS_ACCESS_KEY_ID = $config.aws_access_id
    $env:AWS_SECRET_ACCESS_KEY = $config.aws_access_key 

    if ($Config.aws_region -eq $null) {
        $Config.aws_region = "us-east-1"
    }

    if ($Config.env_network_cidr -eq $null) {
        $Config.env_network_cidr = "10.1.0.0/16"
    }
    if ($Config.env_ssh_key -eq $null) {
        $Config.env_ssh_key  = "~/.ssh/id_rsa"
    }
    if ($Config.env_ssh_key -eq "new") {
        $Config.env_ssh_new = $true
        $keyParent = Split-Path -Path $ConfigPath -Parent
        $keyFile = $config.env_name.Replace('.', '-')
        $config.env_ssh_key = "$keyParent/$keyFile"
    }

    if ($Config.k8s_version -eq $null) {
        $Config.k8s_version = "1.8.0"
    }
        if ($Config.k8s_node_zones -eq $null) {
        $Config.k8s_node_zones = @( $Config.aws_region + "a" )
    }
    if ($Config.k8s_master_zones -eq $null) {
        $Config.k8s_master_zones = @( $Config.aws_region + "a" )
    }
    if ($Config.k8s_instance_type -eq $null) {
        $Config.k8s_instance_type = "t2.medium"
    }
    if ($Config.k8s_ami -eq $null -and $All) {
        $out = (aws ec2 describe-images --region $Config.aws_region --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-20180126" --query "Images[].ImageId" --output "text") | Out-String
        $Config.k8s_ami = $out.Replace("`n", "").Replace("`t", " ").Split(" ")[0]
    }

        
    if ($Config.mongo_group_name -eq $null) {
        $Config.mongo_group_name = $Config.env_name.Replace(".", "-")
    }
    if ($Config.mongo_cluster_name -eq $null) {
        $Config.mongo_cluster_name = $Config.env_name.Replace(".", "-")
    }
    if ($Config.mongo_network_cidr -eq $null) {
        $Config.mongo_network_cidr = "10.2.0.0/24"
    }
    if ($Config.mongo_shards -eq $null) {
        $Config.mongo_shards = 1
    }
    if ($Config.mongo_size -eq $null) {
        $Config.mongo_size = 10
    }
    if ($Config.mongo_instance_type -eq $null) {
        $Config.mongo_instance_type = "M10"
    }
    if ($Config.mongo_backup -eq $null) {
        $Config.mongo_backup = $false
    }
    if ($Config.mongo_iops -eq $null) {
        $Config.mongo_iops = 0
    }

    if ($Config.blobs_name -eq $null) {
        $Config.blobs_name = ("blobs." + $Config.k8s_dns_zone)
    } 
        
    if ($Config.baseline_tag -eq $null) {
        $Config.baseline_tag = "baseline-0"
    }
}
