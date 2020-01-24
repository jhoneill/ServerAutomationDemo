<#
  .SYNOPSIS
    Test Azure Resource Manager (ARM) template using Pester. 

 .DESCRIPTION
    The following tests are performed:
    * Template file validation
      * Test if the ARM template file exists
      * Test if the ARM template is a valid JSON file
    * Template content validation
      * Contains all required elements
      * Only contains valid elements
      * Has valid Content Version
      * Only has approved parameters
      * Only has approved variables
      * Only has approved functions
      * Only has approved resources
      * Only has approved outputs

  .PARAMETER -TemplatePath
    The path to the ARM Template that needs to be tested (required).

  .PARAMETER -parameters
    The names of all parameters the ARM template may contain.

  .PARAMETER -variables
    The names of all variables the ARM template may contain.

  .PARAMETER -functions
    The list of all the functions (namespace.member) the ARM template may contain

  .PARAMETER -resources
    The list of resources (of its type) the ARM template may contain. Only top level resources are supported. child resources defined in the templates are not supported.

  .PARAMETER -output
    The names of all outputs the ARM template may contain

 .EXAMPLE
  # Test ARM template file with parameters, variables, functions, resources and outputs:
   $params = @{
    TemplatePath = 'c:\temp\azuredeploy.json'
    parameters = 'virtualMachineNamePrefix', 'virtualMachineSize', 'adminUsername', 'virtualNetworkResourceGroup', 'virtualNetworkName', 'adminPassword', 'subnetName'
    variables = 'nicName', 'publicIpAddressName', 'publicIpAddressSku', 'publicIpAddressType', 'subnetRef', 'virtualMachineName', 'vnetId'
    functions = 'tyang.uniqueName'
    resources = 'Microsoft.Compute/virtualMachines', 'Microsoft.Network/networkInterfaces', 'Microsoft.Network/publicIpAddresses'
    outputs = 'adminUsername'
  }
  .\Test.ARMTemplate.ps1 @params

 .EXAMPLE
   # Test ARM template file with only the resources elements:
    $params = @{
    TemplatePath = 'c:\temp\azuredeploy.json'
    resources = 'Microsoft.Compute/virtualMachines', 'Microsoft.Network/networkInterfaces', 'Microsoft.Network/publicIpAddresses'
  }
  .\Test.ARMTemplate.ps1 @params
#>
<#
======================================
AUTHOR:  Tao Yang
DATE:    09/09/2018
Version: 1.0
Comment: Pester Test for ARM Template
======================================
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    $TemplatePath,
    $ParameterFilePath,
    $Parameters,
    $Variables,
    $Functions,
    $Resources         = @('Microsoft.Network/publicIPAddresses', 'Microsoft.Network/networkSecurityGroups',
                           'Microsoft.Network/virtualNetworks',   'Microsoft.Network/networkInterfaces',
                           'Microsoft.Compute/virtualMachines'),
    $Outputs
)
$requiredElements      = @('$schema',    'contentversion', 'resources')
$optionalElements      = @('parameters', 'variables',      'functions', 'outputs')

if ((-not $ParameterFilePath) -and (Test-Path -path ($TemplatePath -replace 'json$','parameters.json' ))) {
    $ParameterFilePath = $TemplatePath -replace 'json$','parameters.json' 
}

Describe 'ARM Template validation' {
    Context 'File Validation' {
        It "exists at $TemplatePath".PadRight(80) {
          Test-Path $TemplatePath -PathType Leaf                                          | Should      -Be $true
        }
        It 'is a valid JSON file'.PadRight(80)    {
          {$null = Get-Content $TemplatePath -Raw | ConvertFrom-Json -AsHashtable}        | Should -Not -Throw
        }
    }
    Context 'template Content Validation' {
        $templateJson = Get-Content $TemplatePath -Raw | ConvertFrom-Json -AsHashtable 
        It 'contains all required elements'.PadRight(80) {
            $requiredElements.where({$_ -notin $templateJson.Keys})                       | Should      -BeNullOrEmpty 
        }
        It 'only contains valid elements' {
            $templateJson.Keys.where({$_ -notin ($requiredElements + $optionalElements)}) | Should      -BeNullOrEmpty
        }
        It 'has a valid Content Version'.PadRight(80) { $templateJson.contentVersion      | Should      -Match '^[0-9]+.[0-9]+.[0-9]+.[0-9]+$'   }
        It "uses only approved resources" {
            $templateJson.resources.type.where({$_ -notin $Resources})                    | Should      -BeNullOrEmpty
        }      
        It 'only outputs approved fields'.PadRight(80) {
            $templateJson.outputs.keys.Where({$_ -notin $Outputs})                        | Should      -BeNullOrEmpty
        } -Skip:(-not $Outputs)
        It 'uses only uses approved parameters'.PadRight(80) {
            $templateJson.parameters.keys.where({$_ -notin $Parameters})                  | Should      -BeNullOrEmpty
        } -Skip:(-not $Parameters)
        It "supports all parameters in $ParameterFilePath".PadRight(80) {
          $paramJson = Get-Content $ParameterFilePath | ConvertFrom-Json -AsHashtable
          $paramJson.parameters.Keys.Where({$_ -notin $TemplateJson.parameters.Keys})     | Should      -BeNullOrEmpty
        } -Skip:(-not $ParameterFilePath)
        It 'uses only approved variables'.PadRight(80) {
            $templateJson.variables.Keys.where({$_ -notin $Variables})                    | Should      -BeNullOrEmpty
        } -skip:(-not $Variables)
        It 'uses only approved functions'.PadRight(80) {
            $templateJson.functions.members.psobject.properties.name.where(
                                                                  {$_ -notin $Functions}) | Should      -BeNullOrEmpty
       } -Skip:(-not $Functions)
    }
}
