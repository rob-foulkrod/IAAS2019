targetScope = 'resourceGroup'

@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Premium_LRS'
])
param vmstorageType string = 'Premium_LRS'

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

@description('The location of resources, such as templates and DSC modules, that the template depends on')
param _artifactsLocation string = 'https://attdemodeploystoacc.blob.core.windows.net/deployartifacts/deploytemplateartifacts'

@description('Auto-generated token to access _artifactsLocation. Leave it blank unless you need to provide your own value.')
@secure()
param _artifactsLocationSasToken string = ''
param WebPackage string = 'https://attdemodeploystoacc.blob.core.windows.net/deployartifacts/eshoponweb_iissource.zip'

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
var vmstorageName = '${abbrs.storageStorageAccounts}${ResourceToken}'
var WebVMImagePublisher = 'MicrosoftWindowsServer'
var WebVMImageOffer = 'WindowsServer'
var WebVMOSDiskName = 'WebVMOSDisk'
var WebVMVmSize = 'Standard_D4lds_v5'
var WebVMVnetID = AzTrainingVNet.id
var WebVMSubnetRef = '${WebVMVnetID}/subnets/${AzTrainingVNetSubnet1Name}'
var WebVMStorageAccountContainerName = 'vhds'
var WebVMNicName = '${WebVMName}NetworkInterface'
var WebPublicIPName = 'WebPublicIP'
var WebDSCArchiveFolder = 'DSC'
var WebDSCArchiveFileName = 'WEBDSC.zip'
var SQLVMImagePublisher = 'MicrosoftSQLServer'
var SQLVMImageOffer = 'sql2019-ws2019'
var SQLVMOSDiskName = 'SQLVMOSDisk'
var SQLVMVmSize = 'Standard_D4lds_v5'
var SQLVMVnetID = AzTrainingVNet.id
var SQLVMSubnetRef = '${SQLVMVnetID}/subnets/${AzTrainingVNetSubnet2Name}'
var SQLVMStorageAccountContainerName = 'vhds'
var SQLVMNicName = '${SQLVMName}NetworkInterface'
var SQLDISK1 = 'http://${vmstorageName}.blob.core.windows.net/vhds/dataDisk1.vhd'
var SQLDISK2 = 'http://${vmstorageName}.blob.core.windows.net/vhds/dataDisk2.vhd'
var SQLDSCArchiveFolder = 'DSC'
var SQLDSCArchiveFileName = 'SQLDSC.zip'
var WebModulesURL = uri(_artifactsLocation, 'IAAS2019/.azure/DSC/WEBDSC.zip${_artifactsLocationSasToken}')
var WebConfigurationFunction = 'WEBDSC.ps1\\CREATEOUS'
var SQLModulesURL = uri(_artifactsLocation, 'IAAS2019/.azure/DSC/SQLDSC.zip${_artifactsLocationSasToken}')
var SQLConfigurationFunction = 'CREATEOUS.ps1\\CREATEOUS'

resource AzTrainingVNet 'Microsoft.Network/virtualNetworks@2016-03-30' = {
  name: 'AzTrainingVNet'
  location: resourceGroup().location
  tags: {
    displayName: 'AzTrainingVNet'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        AzTrainingVNetPrefix
      ]
    }
    subnets: [
      {
        name: AzTrainingVNetSubnet1Name
        properties: {
          addressPrefix: AzTrainingVNetSubnet1Prefix
        }
      }
      {
        name: AzTrainingVNetSubnet2Name
        properties: {
          addressPrefix: AzTrainingVNetSubnet2Prefix
        }
      }
    ]
  }
  dependsOn: []
}

resource vmstorage 'Microsoft.Storage/storageAccounts@2016-01-01' = {
  name: vmstorageName
  location: resourceGroup().location
  sku: {
    name: vmstorageType
  }
  tags: {
    displayName: 'vmstorage'
  }
  kind: 'Storage'
  dependsOn: []
}

resource WebVMNic 'Microsoft.Network/networkInterfaces@2016-03-30' = {
  name: WebVMNicName
  location: resourceGroup().location
  tags: {
    displayName: 'WebVMNic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: WebVMSubnetRef
          }
          publicIPAddress: {
            id: WebPublicIP.id
          }
        }
      }
    ]
  }
}

resource WebVM 'Microsoft.Compute/virtualMachines@2015-06-15' = {
  name: WebVMName
  location: resourceGroup().location
  tags: {
    displayName: 'WebVM'
  }
  properties: {
    hardwareProfile: {
      vmSize: WebVMVmSize
    }
    osProfile: {
      computerName: WebVMName
      adminUsername: WebVMAdminUserName
      adminPassword: WebVMAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: WebVMImagePublisher
        offer: WebVMImageOffer
        sku: WebVMWindowsOSVersion
        version: 'latest' //'17763.6659.241205'
      }
      osDisk: {
        name: 'WebVMOSDisk'
        vhd: {
          uri: '${vmstorage.properties.primaryEndpoints.blob}${WebVMStorageAccountContainerName}/${WebVMOSDiskName}.vhd'
        }
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: WebVMNic.id
        }
      ]
    }
  }
}

resource WebVMName_Microsoft_Powershell_DSC 'Microsoft.Compute/virtualMachines/extensions@2016-03-30' = {
  parent: WebVM
  name: 'Microsoft.Powershell.DSC'
  location: resourceGroup().location
  tags: {
    displayName: 'WebDSC'
  }
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.9'
    autoUpgradeMinorVersion: true
    settings: {
      configuration: {
        url: concat(WebModulesURL)
        script: 'WEBDSC.ps1'
        function: 'Main'
      }
      configurationArguments: {
        nodeName: WebVMName
        webDeployPackage: WebPackage
      }
    }
    protectedSettings: {
      configurationUrlSasToken: _artifactsLocationSasToken
    }
  }
}

resource WebVMName_Customize_WinVM 'Microsoft.Compute/virtualMachines/extensions@2016-03-30' = {
  parent: WebVM
  name: 'Customize-WinVM'
  location: resourceGroup().location
  tags: {
    displayName: 'Customize-WinVM'
  }
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.8'
    autoUpgradeMinorVersion: false
    settings: {
      fileUris: [
        'https://attdemodeploystoacc.blob.core.windows.net/deployartifacts/Customize-WinVM.ps1'
      ]
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File ./customize-WinVM.ps1'
    }
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
  dependsOn: []
}

resource SQLVMNic 'Microsoft.Network/networkInterfaces@2016-03-30' = {
  name: SQLVMNicName
  location: resourceGroup().location
  tags: {
    displayName: 'SQLVMNic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: SQLVMSubnetRef
          }
        }
      }
    ]
  }
}

resource SQLVM 'Microsoft.Compute/virtualMachines@2015-06-15' = {
  name: SQLVMName
  location: resourceGroup().location
  tags: {
    displayName: 'SQLVM'
  }
  properties: {
    hardwareProfile: {
      vmSize: SQLVMVmSize
    }
    osProfile: {
      computerName: SQLVMName
      adminUsername: SQLVMAdminUserName
      adminPassword: SQLVMAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: SQLVMImagePublisher
        offer: SQLVMImageOffer
        sku: SQLVMSKU
        version: 'latest' //'15.0.230214'
      }
      osDisk: {
        name: 'SQLVMOSDisk'
        vhd: {
          uri: '${vmstorage.properties.primaryEndpoints.blob}${SQLVMStorageAccountContainerName}/${SQLVMOSDiskName}.vhd'
        }
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
      dataDisks: [
        {
          name: 'datadisk1'
          diskSizeGB: 1023
          lun: 0
          vhd: {
            uri: SQLDISK1
          }
          createOption: 'Empty'
        }
        {
          name: 'datadisk2'
          diskSizeGB: 1023
          lun: 1
          vhd: {
            uri: SQLDISK2
          }
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: SQLVMNic.id
        }
      ]
    }
  }
}

resource SQLVMName_Microsoft_Powershell_DSC 'Microsoft.Compute/virtualMachines/extensions@2016-03-30' = {
  parent: SQLVM
  name: 'Microsoft.Powershell.DSC'
  location: resourceGroup().location
  tags: {
    displayName: 'SQLDSC'
  }
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.9'
    autoUpgradeMinorVersion: true
    settings: {
      configuration: {
        url: concat(SQLModulesURL)
        script: 'SQLDSC.ps1'
        function: 'Main'
      }
      configurationArguments: {
        nodeName: SQLVMName
      }
    }
    protectedSettings: {
      configurationUrlSasToken: _artifactsLocationSasToken
    }
  }
}
