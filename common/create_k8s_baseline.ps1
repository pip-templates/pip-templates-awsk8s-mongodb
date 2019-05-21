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
$path = $PSScriptRoot
if ($path -eq "") { $path = "." }
. "$($path)/../lib/include.ps1"

# Read config and resources
$config = Read-EnvConfig -Path $ConfigPath
$resources = Read-EnvResources -Path $ConfigPath

# Set default values for config parameters
Set-EnvConfigCloudDefaults -Config $config | Out-Null

# Select kubectl context
kubectl config use-context $config.env_name

# Get launched containers images from all namespaces and select registry
$podsImages = kubectl describe pods --all-namespaces | Select-String -Pattern "Image:" | Select-String -Pattern $($config.docker_registry)

# Login to docker server
Write-Host "Attempting loggin to private docker registry..."
docker login $config.docker_registry -u $config.docker_user -p $config.docker_pass

foreach ($item in $podsImages) {
    [String]$podImage = $item
    # Save docker pod image and baseline image
    $dockerImage = $podImage.Substring($podImage.IndexOf("Image: ")+7).Trim()
    $dockerImageWithTag = $dockerImage
    # Remove tag from image if it exists
    if ($dockerImageWithTag.IndexOf(":") -gt 0) {
        $dockerImage = $dockerImage.Split(":")[0]
    }
    $baselineImage = $dockerImage + ":" + $Baseline

    # Pull image before tag
    Write-Host "Pulling image before tag..."
    docker pull $dockerImageWithTag

    # Tag image with baseline tag
    docker tag $dockerImageWithTag $baselineImage

    # Push image to registry
    Write-Host "Pushing image with baseline tag..."
    docker push $baselineImage

    # Cleanup
    docker rmi $dockerImageWithTag --force
    docker rmi $baselineImage --force
}

docker image prune --force

Write-Host "All images from private registry tagged `"$Baseline`" successfully"
