function Invoke-MongoCloud
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Method,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $Username,
        [Parameter(Mandatory=$true, Position=2)]
        [string] $ApiKey,
        [Parameter(Mandatory=$false, Position=3)]
        [string] $Route,
        [Parameter(Mandatory=$false, Position=4)]
        [object] $Body,
        [Parameter(Mandatory=$false, Position=5)]
        [switch] $IgnoreNotFound,
        [Parameter(Mandatory=$false, Position=6)]
        [switch] $IgnoreUnauthorized
    )
    
    if ($Body -ne $null) {
        $in = $Body | ConvertTo-Json -Compress

        # Convert to JSON does not add brackets for array with one object
        if ($Body -is [array] -and -not $in.StartsWith("[")) {
            $in = "[" + $in + "]"
        }
        $in = $in.Replace("`"", "\`"")
    } else {
        $in = "{}"
    }

    $out = (curl -s -X $Method -u "$($Username):$($ApiKey)" --digest "https://cloud.mongodb.com/api/atlas/v1.0$Route" -H "Content-Type: application/json" -d "$in") | Out-String
    $response = $out | ConvertFrom-Json | ConvertObjectToHashtable

    if ($response -eq $null) {
        throw "Failed to invoke Mongo Cloud"
    }

    if ($response.error -ne $null) {
        if ($IgnoreNotFound -and $response.error -eq 404) {
            Write-Output $null
        } elseif ($IgnoreUnauthorized -and $response.error -eq 401) {
            Write-Output $null
        } else {
            Write-Error $out
            if ($response.detail -ne $null) {
                throw $response.detail
            }
            throw $response.reason
        }
    } else {
        Write-Output $response
    }
}