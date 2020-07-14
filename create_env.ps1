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

. "$($rootPath)/cloud/install_mongo.ps1" $ConfigPath
