#lifted from https://github.com/LiquoriChris/azuredevops-extension-tag-git-release
[CmdletBinding()]
param (
    $Name       = "Tag Name",
    $Message    = "Tag message",
    [switch]$IgnoreExisting
)


if (-not ($env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI -and $env:SYSTEM_TEAMPROJECT -and $env:BUILD_REPOSITORY_ID -and  $env:BUILD_SOURCEVERSION)) {
    throw "Cannot find the variables to connect to the project." 
}
if (-not $env:SYSTEM_ACCESSTOKEN) {
    throw "There is no access token, please set environment variable 'SYSTEM_ACCESSTOKEN' to system.accesstoken before calling the script." 
}

$Params = @{
    Uri         = "{0}{1}/_apis/git/repositories/{2}/annotatedtags?api-version=5.1" -f $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI, $env:SYSTEM_TEAMPROJECT, $env:BUILD_REPOSITORY_ID
    Headers     = @{Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"}
    Body        = [ordered]@{name = $Name;  taggedObject = @{objectId = $env:BUILD_SOURCEVERSION} ; message = $Message } | ConvertTo-Json -Depth 2
    Method      = 'Post'
    ContentType = 'application/json'
    ErrorAction = 'Stop'
}

Try {
    <#
    $Response = Invoke-RestMethod @Params
    Write-Output "Name: $($Response.name)"
    Write-Output "Commit: $($Response.objectId)"
    Write-Output "Message: $($Response.message)" 
    #>
    $Params
}
Catch {
    $throw = $true
    $StatusCode = $_.Exception.Response.StatusCode.value__
    if (($StatusCode -eq 409) -and ($IgnoreExisting)) {
        Write-Warning "Tag '$Name' already exists. Ignoring."
        $throw = $false
    }
    if ($throw) {
        throw $_
    }
}
