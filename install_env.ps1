#!/usr/bin/env pwsh

param
(
    [Alias("c", "Path")]
    [Parameter(Mandatory=$true, Position=0)]
    [string] $ConfigPath,
    [Parameter(Mandatory=$true, Position=1)]
    [string] $Baseline = ""
)

# Load support functions
$rootPath = $PSScriptRoot
if ($rootPath -eq "") { $rootPath = "." }
. "$($rootPath)/lib/include.ps1"

. "$($rootPath)/cloud/install_k8s.ps1" $ConfigPath
. "$($rootPath)/cloud/install_mongo.ps1" $ConfigPath
. "$($rootPath)/cloud/peer_mgmt.ps1" $ConfigPath
. "$($rootPath)/cloud/configure_k8s.ps1" $ConfigPath
. "$($rootPath)/cloud/peer_mongo.ps1" $ConfigPath
. "$($rootPath)/common/install_k8s_components.ps1" $ConfigPath $Baseline
