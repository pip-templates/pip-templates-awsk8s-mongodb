function ConvertObjectToHashtable 
{
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory=$False, Position = 0, ValueFromPipeline=$True)]
        [Object] $InputObject = $null
    )
    process 
    {
        if ($null -eq $InputObject) { return $null }

        if ($InputObject -is [Hashtable]) 
        {
            $InputObject
        } 
        elseif ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) 
        {
            $collection = 
            @(
                foreach ($object in $InputObject) { ConvertObjectToHashtable $object }
            )

            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject]) 
        {
            $hash = @{}

            foreach ($property in $InputObject.PSObject.Properties) 
            {
                $hash[$property.Name] = ConvertObjectToHashtable $property.Value
            }

            $hash
        }
        else 
        {
            $InputObject
        }
    }
}