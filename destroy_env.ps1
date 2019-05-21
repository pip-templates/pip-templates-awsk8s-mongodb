#!/usr/bin/env pwsh

param
(
    [Alias("c", "Path")]
    [Parameter(Mandatory=$false, Position=0)]
    [string] $ConfigPath
)

# Load support functions
$rootPath = $PSScriptRoot
if ($rootPath -eq "") { $rootPath = "." }
. "$($rootPath)/lib/include.ps1"

. "$($rootPath)/cloud/unpeer_mongo.ps1" $ConfigPath
. "$($rootPath)/cloud/destroy_mongo.ps1" $ConfigPath
. "$($rootPath)/cloud/destroy_k8s.ps1" $ConfigPath
