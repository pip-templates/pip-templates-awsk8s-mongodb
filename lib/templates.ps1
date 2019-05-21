function ConvertFrom-EnvTemplate
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Template,
        [Parameter(Mandatory=$false, Position=1)]
        [hashtable] $Params1 = @{},
        [Parameter(Mandatory=$false, Position=2)]
        [hashtable] $Params2 = @{},
        [Parameter(Mandatory=$false, Position=3)]
        [switch] $Secret
    )

    $params = @{}
    foreach ($key in $Params1.Keys) {
        $params[$key] = $Params1[$key]
    }
    foreach ($key in $Params2.Keys) {
        $params[$key] = $Params2[$key]
    }

    $beginTag = [regex]::escape("<%=")
    $endTag = [regex]::escape("%>")
    $output = ""

    $Template = $Template -replace [environment]::newline, "`r"

    while ($Template -match "(?<pre>.*?)$beginTag(?<key>.*?)$endTag(?<post>.*)") {
        $Template = $matches.post
        $key = $matches.key.Trim()
        $value = $params[$key] + ""
        if ($Secret) {
            $value = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($value))
        }
        $output += $matches.pre + $value
    }

    $output += $Template
    $output = $output -replace "`r", [environment]::newline 
    Write-Output $output
}

function Build-EnvTemplate
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $InputPath,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $OutputPath,
        [Parameter(Mandatory=$false, Position=2)]
        [hashtable] $Params1 = @{},
        [Parameter(Mandatory=$false, Position=3)]
        [hashtable] $Params2 = @{},
        [Parameter(Mandatory=$false, Position=4)]
        [switch] $Secret
    )

    $template = Get-Content -Path $InputPath | Out-String
    if ($template -ne "") {
        if ($Secret) {
            $value = ConvertFrom-EnvTemplate -Template $template -Params1 $Params1 -Params2 $Params2 -Secret 
        } else {
            $value = ConvertFrom-EnvTemplate -Template $template -Params1 $Params1 -Params2 $Params2
        }
    } else {
        $value = ""
    }
    Set-Content -Path $OutputPath -Value $value
}