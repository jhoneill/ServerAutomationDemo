param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$RGName ,
    [ValidateNotNullOrEmpty()]
    [string]$Subscription = $env:SUBSCRIPTION_ID

)
if (-not (Get-Module -ListAvailable Az.Network ))  {Install-Module -Name Az.Network   -Force -SkipPublisherCheck}
if (-not (Get-Module -ListAvailable Az.Resources)) {Install-Module -Name Az.Resources -Force -SkipPublisherCheck}
if (-not (Get-Module -ListAvailable Az.Security )) {Install-Module -Name Az.Security  -Force -SkipPublisherCheck}
if (-not (Get-Module -ListAvailable Az.Compute  )) {Install-Module -Name Az.Compute   -Force -SkipPublisherCheck}


describe "Configuration" {
    $rg     =  Get-AzResourceGroup -Name $RGName
    $params = (Get-Content .\server.parameters.json | ConvertFrom-Json)
    $vmname = $params.parameters.vm1Name.value
    it 'created the resource group.            ' {
        $rg.ProvisioningState                           | Should      -Be "Succeeded"
        $rg.ResourceId                                  | Should      -BeLike ("*$subscription*")
    }
    it 'created the VM.                        ' {
        $vmname                                         | Should -not -BeNullOrEmpty
        $vm = Get-AzVM -ResourceGroupName  $RGName -Name $vmname
        $vm.name                                        | Should      -Be $vmname
        $vm.location                                    | Should      -Be $rg.Location
        $vm.OSProfile.ComputerName                      | Should      -Be $vmname
        $vm.OSProfile.AdminUsername                     | Should      -Be $params.parameters.adminUsername.value
        $vm.NetworkProfile.NetworkInterfaces.id         | Should -not -BeNullOrEmpty
        $nic = (Get-AzNetworkInterface -ResourceId  $vm.NetworkProfile.NetworkInterfaces.id)
        $nic.IpConfigurations[0].PublicIpAddress.Id     | Should -not -BeNullOrEmpty
        #$vm.HardwareProfile.vmsize
        #$vm.StorageProfile.ImageReference.sku
    }
    it 'created the virtual network.           ' {
        $azvn = Get-AzVirtualNetwork -ResourceGroupName $RGName
        $azvn.count                                     | Should       -Be 1
        $azvn.AddressSpace.AddressPrefixes.Count        | Should       -Be 1
        $azvn.AddressSpace.AddressPrefixes[0]           | Should       -Be      '10.0.0.0/16'
        $azvn.Subnets.AddressPrefix                     | Should       -Contain '10.0.0.0/24'
        $azvn.Subnets.AddressPrefix                     | Should       -Contain '10.0.1.0/24'
    }
    it 'created the Network Security Group.    ' {
        $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName  $RGName
        $nsg.count                                      | Should       -Be 1
        $nsg.SecurityRules[0].name                      | Should       -Be 'default-allow-3389'
        $nsg.SecurityRules[0].DestinationPortRange[0]   | Should       -Be '3389'
    }
    it 'enabled RDP Access                     ' {
        $ArmDeploymentOutput = $env:ARM_OUTPUT | convertfrom-json
        $ArmDeploymentOutput                            | Should -not -BeNullOrEmpty
        Test-Connection -TCPPort 3389 -TargetName $ArmDeploymentOutput.hostname.value -Quiet |
                                                          Should      -Be $true
    }
}