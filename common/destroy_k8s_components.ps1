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
Set-EnvConfigCommonDefaults -Config $config

# Delete dashboard
if ($config.k8s_dashboard_enabled) {
    kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
}

# Delete namespace
Build-EnvTemplate -InputPath "$($path)/../templates/namespace_deployment.yml" -OutputPath "$($path)/../temp/namespace_deployment.yml" -Params1 $config -Params2 $resources
kubectl delete -f "$($path)/../temp/namespace_deployment.yml"

# Skip deletion of other components
# Deleting namespace should delete all components in it
