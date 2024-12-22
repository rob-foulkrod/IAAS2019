targetScope = 'resourceGroup'

@minLength(1)
param WebVMName string

@minLength(1)
param WebVMAdminUserName string

@secure()
param WebVMAdminPassword string

@allowed([
  '2008-R2-SP1'
  '2012-Datacenter'
  '2012-R2-Datacenter'
  '2019-Datacenter'
])
param WebVMWindowsOSVersion string = '2019-Datacenter'

@minLength(1)
param WebPublicIPDnsName string

param WebPackage string = 'https://github.com/rob-foulkrod/IAAS2019/raw/refs/heads/main/infra/artifacts/eshoponweb_iissource.zip'

@minLength(1)
param SQLVMName string

@minLength(1)
param SQLVMAdminUserName string

@secure()
param SQLVMAdminPassword string

@allowed([
  'Web'
  'Standard'
])
param SQLVMSKU string = 'Web'

param ResourceToken string

var abbrs = loadJsonContent('./abbreviations.json')

var AzTrainingVNetPrefix = '10.0.0.0/16'
var AzTrainingVNetSubnet1Name = 'FrontendNetwork'
var AzTrainingVNetSubnet1Prefix = '10.0.0.0/24'
var AzTrainingVNetSubnet2Name = 'BackendNetwork'
var AzTrainingVNetSubnet2Prefix = '10.0.1.0/24'
var WebVMImagePublisher = 'MicrosoftWindowsServer'
var WebVMImageOffer = 'WindowsServer'
var WebVMVmSize = 'Standard_D4lds_v5'
var WebPublicIPName = 'WebPublicIP'
var SQLVMImagePublisher = 'MicrosoftSQLServer'
var SQLVMImageOffer = 'sql2019-ws2019'
var SQLVMVmSize = 'Standard_D4lds_v5'
var WebModulesURL = 'https://github.com/rob-foulkrod/IAAS2019/raw/refs/heads/main/infra/artifacts/WEBDSC.zip'
//var WebConfigurationFunction = 'WEBDSC.ps1\\CREATEOUS'
var SQLModulesURL = 'https://github.com/rob-foulkrod/IAAS2019/raw/refs/heads/main/infra/artifacts/SQLDSC.zip'
//var SQLConfigurationFunction = 'SQLDSC.ps1\\CREATEOUS'

module monitoring 'br/public:avm/ptn/azd/monitoring:0.1.0' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${ResourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}${ResourceToken}'
    location: resourceGroup().location
  }
}

module AzTrainingVNet 'br/public:avm/res/network/virtual-network:0.5.1' = {
  name: 'AzTrainingVNetDeployment'
  params: {
    // Required parameters
    addressPrefixes: [AzTrainingVNetPrefix]
    name: '${abbrs.networkVirtualNetworks}${ResourceToken}'
    // Non-required parameters
    location: resourceGroup().location
    tags: {
      displayName: 'AzTrainingVNet'
    }
    subnets: [
      {
        name: AzTrainingVNetSubnet1Name
        addressPrefix: AzTrainingVNetSubnet1Prefix
      }
      {
        name: AzTrainingVNetSubnet2Name
        addressPrefix: AzTrainingVNetSubnet2Prefix
      }
    ]
    diagnosticSettings: [
      {
        workspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
      }
    ]
  }
}

resource WebPublicIP 'Microsoft.Network/publicIPAddresses@2016-03-30' = {
  name: WebPublicIPName
  location: resourceGroup().location
  tags: {
    displayName: 'WebPublicIP'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: WebPublicIPDnsName
    }
  }
}
module WebVM 'br/public:avm/res/compute/virtual-machine:0.10.1' = {
  name: 'WebvirtualMachineDeployment'
  params: {
    name: WebVMName
    osType: 'Windows'
    vmSize: WebVMVmSize
    zone: 0
    adminUsername: WebVMAdminUserName
    adminPassword: WebVMAdminPassword
    encryptionAtHost: false
    location: resourceGroup().location
    imageReference: {
      offer: WebVMImageOffer
      publisher: WebVMImagePublisher
      sku: WebVMWindowsOSVersion
      version: 'latest'
    }
    nicConfigurations: [
      {
        deleteOption: 'Delete'
        diagnosticSettings: [
          {
            workspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
          }
        ]
        ipConfigurations: [
          {
            name: 'ipconfig1'
            pipConfiguration: {
              publicIPAddressResourceId: WebPublicIP.id
            }
            subnetResourceId: AzTrainingVNet.outputs.subnetResourceIds[0]
            privateIPAllocationMethod: 'Dynamic'
            diagnosticSettings: [
              {
                workspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
              }
            ]
          }
        ]
      }
    ]
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    extensionDSCConfig: {
      enabled: true
      autoUpgradeMinorVersion: true
      settings: {
        configuration: {
          url: WebModulesURL
          script: 'WEBDSC.ps1'
          function: 'Main'
        }
        configurationArguments: {
          nodeName: WebVMName
          webDeployPackage: WebPackage
        }
      }
      diagnosticSettings: [
        {
          workspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
        }
      ]
    }
    //Seems to be a bug in extensionCustomScriptConfig
    // extensionCustomScriptConfig: {
    //   enabled: true
    //   name: 'Customize-WinVM'
    //   tags: {
    //     displayName: 'Customize-WinVM'
    //   }
    //   location: resourceGroup().location
    //   fileData: {
    //     storageAccountId: storageAccount.outputs.resourceId
    //     uri: storageAccount.outputs.primaryBlobEndpoint
    //   }
    //   settings: {
    //     fileUris: [
    //       'https://github.com/rob-foulkrod/IAAS2019/raw/refs/heads/main/infra/artifacts/Customize-WinVM.ps1'
    //     ]
    //     commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File ./customize-WinVM.ps1'
    //   }
    // }
  }
}

// // 'https://github.com/rob-foulkrod/IAAS2019/raw/refs/heads/main/infra/artifacts/Customize-WinVM.ps1'
// resource WebVMName_Customize_WinVM 'Microsoft.Compute/virtualMachines/extensions@2016-03-30' = {
//   //match the name of the VM for a child of the VM
//   name: '${WebVMName}/CustomizeWinVM'
//   location: resourceGroup().location
//   tags: {
//     displayName: 'Customize-WinVM'
//   }
//   properties: {
//     publisher: 'Microsoft.Compute'
//     type: 'CustomScriptExtension'
//     typeHandlerVersion: '1.8'
//     autoUpgradeMinorVersion: false
//     settings: {
//       fileUris: [
//         'https://attdemodeploystoacc.blob.core.windows.net/deployartifacts/Customize-WinVM.ps1'
//       ]
//       commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File ./customize-WinVM.ps1'
//     }
//   }
//   dependsOn: [
//     WebVM
//   ]
// }

module SQLVM 'br/public:avm/res/compute/virtual-machine:0.10.1' = {
  name: 'SQLvirtualMachineDeployment'
  params: {
    // Required parameters
    name: SQLVMName
    osType: 'Windows'
    vmSize: SQLVMVmSize

    zone: 0
    adminUsername: SQLVMAdminUserName
    adminPassword: SQLVMAdminPassword
    encryptionAtHost: false
    location: resourceGroup().location
    imageReference: {
      offer: SQLVMImageOffer
      publisher: SQLVMImagePublisher
      sku: SQLVMSKU
      version: 'latest'
    }
    nicConfigurations: [
      {
        deleteOption: 'Delete'
        diagnosticSettings: [
          {
            workspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
          }
        ]
        ipConfigurations: [
          {
            name: 'ipconfig1'
            subnetResourceId: AzTrainingVNet.outputs.subnetResourceIds[1]
            privateIPAllocationMethod: 'Dynamic'
            diagnosticSettings: [
              {
                workspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
              }
            ]
          }
        ]
      }
    ]
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    dataDisks: [
      {
        name: 'datadisk1'
        diskSizeGB: 1023
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        lun: 0
        createOption: 'Empty'
      }
      {
        name: 'datadisk2'
        diskSizeGB: 1023
        lun: 1
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        createOption: 'Empty'
      }
    ]
    extensionDSCConfig: {
      enabled: true
      publisher: 'Microsoft.Powershell'
      type: 'DSC'
      typeHandlerVersion: '2.9'
      autoUpgradeMinorVersion: true
      diagnosticSettings: [
        {
          workspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
        }
      ]
      settings: {
        configuration: {
          url: SQLModulesURL
          script: 'SQLDSC.ps1'
          function: 'Main'
        }
        configurationArguments: {
          nodeName: SQLVMName
        }
      }
    }
  }
}

output APP_ENDPOINT string = 'http://${WebPublicIP.properties.dnsSettings.fqdn}'
