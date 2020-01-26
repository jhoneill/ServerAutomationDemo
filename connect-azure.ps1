[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [SecureString]$ServicePrincipalPassword,

    [ValidateNotNullOrEmpty()]
    [string]$Subscription = $env:SUBSCRIPTION_ID,

    [ValidateNotNullOrEmpty()]
    [string]$ApplicationId = $env:APPLICATION_ID,

    [ValidateNotNullOrEmpty()]
    [string]$Tenant = $env:TENANT_ID
)

Get-Command az -ErrorAction SilentlyContinue

if (-not (Get-Module -ListAvailable Az.Accounts )) {Install-Module -Name Az.Accounts  -Force -SkipPublisherCheck}
if (-not (Get-Module -ListAvailable Az.Resources)) {Install-Module -Name Az.Resources -Force -SkipPublisherCheck}

#$password   = ConvertTo-SecureString $ServicePrincipalPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($ApplicationId, $ServicePrincipalPassword)

Connect-AzAccount -ServicePrincipal -Subscription $Subscription -Tenant $Tenant -Credential $credential