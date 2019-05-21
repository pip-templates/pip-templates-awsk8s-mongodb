function Read-EnvConfig
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false, Position=0)]
        [string] $Path
    )

    if (($Path -eq $null) -or ($Path -eq "")) {
        throw "Config file is not set. Execute <script>.ps1 -Config <config file>"
    }

    if (-not (Test-Path -Path $Path)) {
        throw "Config file $($Path) was not found"
    }

    # $Config = Get-Content -Path $Path | ConvertFrom-Json | ConvertTo-Hashtable
    $Config = Get-Content -Path $Path | Out-String | ConvertFrom-Json | ConvertObjectToHashtable
    Write-Output $Config
}

function ConvertTo-EnvResourcesPath
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false, Position=0)]
        [string] $Path
    )

    $parent = Split-Path -Path $Path -Parent
    $file = Split-Path -Path $Path -Leaf
    $lastDotPos = $file.LastIndexOf('.')

    if($lastDotPos -gt -1)
    {
        $file = $file.Substring(0, $lastDotpos)
    }

    if ($file.Contains("config")) {
        $file = $file.Replace("config", "resources")
    } else {
        $file = $file + "_resources"
    }

    return $parent + "/" + $file + ".json"
}

function Read-EnvResources
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false, Position=0)]
        [string] $Path
    )

    $Path = ConvertTo-EnvResourcesPath -Path $Path
    
    if (($Config -eq $null) -or ($Path -eq "")) {
        return @{}
    }

    if (-not (Test-Path -Path $Path)) {
        return @{}
    }

    # $Resources  = Get-Content -Path $Path | ConvertFrom-Json | ConvertTo-Hashtable
    $Resources  = Get-Content -Path $Path | Out-String | ConvertFrom-Json | ConvertObjectToHashtable
    Write-Output $Resources
}

function Write-EnvResources
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Path,
        [Parameter(Mandatory=$true, Position=1)]
        [hashtable] $Resources
    )

    $Path = ConvertTo-EnvResourcesPath -Path $Path

    $Content = ConvertTo-Json $Resources
    Set-Content -Path $Path -Value $Content
}
