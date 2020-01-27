param (
    $rgname           = $env:azure_resource_group_name
)
if (-not (Get-Module -ListAvailable Az.Accounts )) {Install-Module -Name Az.Accounts  -Force -SkipPublisherCheck}
if (-not (Get-Module -ListAvailable Az.Resources)) {Install-Module -Name Az.Resources -Force -SkipPublisherCheck}
if (-not (Get-Module -ListAvailable Az.Security )) {Install-Module -Name Az.Security  -Force -SkipPublisherCheck}
if (-not (Get-Module -ListAvailable Az.Compute  )) {Install-Module -Name Az.Compute   -Force -SkipPublisherCheck}

$rg                   =  Get-AzResourceGroup -name $rgname
$vmname               = (Get-Content .\server.parameters.json | ConvertFrom-Json ).parameters.vm1name.value
$vm                   =  Get-AzVM -ResourceGroupName $rgname -Name $vmname
$rg | Out-String
$vm | Out-String
Get-ChildItem Env:\ | Format-Table -AutoSize

<#
$locname              = $rg.Location
$durationString       = "PT3H" # ISO 8601 spec for duration https://en.wikipedia.org/wiki/ISO_8601#Durations   [System.Xml.XmlConvert]::ToString($TimeSpan)
$protocol             = "*"
$from                 = "*"
$ports                = 22,3389,5985,5986
$JITPolName           = "default"
$jitPolicy            = Get-AzJitNetworkAccessPolicy -ResourceGroupName $rgname -Location $locname -Name $JITPolName -ErrorAction SilentlyContinue
if ($jitPolicy) {
    $JitPolicyVMList  = $jitPolicy.VirtualMachines}
else {
    $JitPolicyVMList  = @()}

$NewVMPolicy          = @{id = $vm.Id ; ports=@()}

foreach ($p in $ports) {
    $NewVMPolicy.ports += @{number   = $p
                            protocol = $protocol
                            allowedSourceAddressPrefix = $from;
                            maxRequestAccessDuration   = $durationString
    }
}
$JitPolicyVMList      += $NewVMPolicy
$jitPolicy            = Set-AzJitNetworkAccessPolicy -Kind "Basic" -Location $locname -Name $JITPolName -ResourceGroupName $rgname -VirtualMachine $JitPolicyVMList
#>
Set-Content   -Path .\remote.ps1 -Value @'
tzutil.exe /s            "GMT Standard Time"
tzutil.exe /g
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Reliability" /v ShutDownReasonOn /t REG_DWORD /d 0 /f

Update-Help -Force       -ErrorAction SilentlyContinue

Enable-PSRemoting       -SkipNetworkProfileCheck -Force
Import-Module           -Name NetSecurity
Get-NetFirewallRule     -Name winrm*public  | Set-NetFirewallRule -RemoteAddress any
Get-NetFirewallRule     -Name winrm*public  | Out-File c:\users\public\fwrule.txt


Get-NetFirewallRule -Name 'WINRM-HTTP-In-*'

Import-Module           -Name PackageManagement,PowerShellGet
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository        -Name PSGallery     -InstallationPolicy Trusted
Install-Script          -Name format-xml    -Scope AllUsers -Force -NoPathUpdate:$false
Install-module          -Name GetSql        -Scope AllUsers -Force -AllowClobber
Install-module          -Name ImportExcel   -Scope AllUsers -Force -AllowClobber
Install-module          -Name xComputerManagement
Install-Module          -Name xActiveDirectory
Install-Module          -Name xpendingreboot
Install-Module          -Name xsmbshare
Install-Module          -Name xwindowsupdate

Get-Service -Name winrm

Get-PSSessionConfiguration

Import-Module           -Name pki
$newCert = New-SelfSignedCertificate -Type Custom -TextExtension @("2.5.29.37={text}1.3.6.1.4.1.311.80.1" ) -KeyUsage DataEncipherment,KeyEncipherment -Subject "cn=$env:COMPUTERNAME" -CertStoreLocation "cert:\LocalMachine\My" -FriendlyName "Desired State Configuration"

Push-Location           -Path "C:\Program Files\WindowsPowerShell"
Configuration Baseline {
    node localhost {
        LocalConfigurationManager {
            ActionAfterReboot               = 'ContinueConfiguration'
            CertificateId                   =  $newCert.Thumbprint
            ConfigurationMode               = 'ApplyOnly'
            RebootNodeIfNeeded              =  $true
            AllowModuleOverWrite            =  $true
            ConfigurationModeFrequencyMins  =  120
            RefreshFrequencyMins            =  120
        }
    }
 }
$null = Baseline             # if it doesn't exist, this will create the folder for the DSC Cert
Set-DscLocalConfigurationManager -Path "C:\Program Files\WindowsPowerShell\Baseline" -ComputerName LocalHost
Get-DscLocalConfigurationManager
Remove-Item  -Force              -Path "C:\Program Files\WindowsPowerShell\Baseline\*.cer" -ErrorAction SilentlyContinue | Out-Null
$null = Export-Certificate   -FilePath "C:\Program Files\WindowsPowerShell\Baseline\$env:COMPUTERNAME.cer" -Cert $newCert
Pop-Location
'@
$remoteResult = Invoke-AzVMRunCommand -ResourceGroupName $rgname -VMName $vmname -ScriptPath .\remote.ps1 -CommandId "RunPowerShellScript"
Remove-Item   -Path  .\remote.ps1

$resultDir    = Join-Path      -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "results"
if (-not       (Test-Path      -Path $resultDir -PathType Container )) {
                 New-Item      -Path $resultDir -ItemType Directory 
}
$XmlPath      = Join-Path      -Path $resultDir -ChildPath 'remoteResult.xml'
Export-Clixml -Depth 5         -Path $XmlPath   -InputObject $remoteResult

$textPath     = Join-Path      -Path $resultDir  -ChildPath 'vm_and_rg.txt'
$rg             | Out-file -FilePath $textPath 
$vm             | Out-file -FilePath $textPath   -Append
$env:ARM_OUTPUT | Out-file -FilePath $textPath   -Append
$XmlPath     = Join-Path       -Path $resultDir  -ChildPath 'vm.xml'
Export-Clixml -Depth 5         -Path $XmlPath    -InputObject $vm

Stop-AzVm -ResourceGroupName $rgname -Name $vmname -Force -NoWait