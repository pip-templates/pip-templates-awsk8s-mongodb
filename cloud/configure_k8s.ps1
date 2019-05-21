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

# Prepare hosts file
$inventory = @("[k8s_nodes]")
foreach ($item in $resources.k8s_inventory) {
    $inventory += $item
}
Set-Content -Path "$path/../temp/k8s_nodes" -Value $inventory

# Whitelist nodes
Build-EnvTemplate -InputPath "$($path)/../templates/ssh_keyscan_playbook.yml" -OutputPath "$($path)/../temp/ssh_keyscan_playbook.yml" -Params1 $config -Params2 $resources
ansible-playbook -i "$path/../temp/k8s_nodes" "$path/../temp/ssh_keyscan_playbook.yml"

# Configure nodes
Build-EnvTemplate -InputPath "$($path)/../templates/k8s_nodes_playbook.yml" -OutputPath "$($path)/../temp/k8s_nodes_playbook.yml" -Params1 $config -Params2 $resources
ansible-playbook -i "$path/../temp/k8s_nodes" "$path/../temp/k8s_nodes_playbook.yml"

# Remove taint from master to launch containers
kubectl taint nodes $(kubectl get nodes --selector=kubernetes.io/role=master | tail -n 1 | cut -d " " -f 1) node-role.kubernetes.io/master-