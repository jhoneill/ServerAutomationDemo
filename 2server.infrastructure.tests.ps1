
#Az.Resources    Az.Compute   Az.Network
Get-AzResourceGroup -Name 'ServerProvisionTesting-221'

$vm = Get-AzVM -ResourceGroupName  'ServerProvisionTesting-221' -Name TESTVMDEPLOY1 
$vm.name
$vm.location
$vm.HardwareProfile.vmsize
$vm.OSProfile.ComputerName
$vm.OSProfile.AdminUsername
$vm.StorageProfile.ImageReference.sku

(Get-AzPublicIpAddress -ResourceGroupName "ServerProvisionTesting-221").name

$azvn = Get-AzVirtualNetwork -ResourceGroupName  'ServerProvisionTesting-221'
$azvn.AddressSpace.AddressPrefixes
$azvn.Subnets | Select-Object name,addressprefix
$azvn.name

$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName 'ServerProvisionTesting-221'
$nsg.name
$nsg.SecurityRules[0].name
$nsg.SecurityRules[0].DestinationPortRange[0]

