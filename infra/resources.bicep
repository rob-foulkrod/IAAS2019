targetScope = 'resourceGroup'

@minLength(1)
param webVMName string

@minLength(1)
param webVMAdminUserName string

@secure()
param webVMAdminPassword string

@allowed([
  '2008-R2-SP1'
  '2012-Datacenter'
  '2012-R2-Datacenter'
  '2019-Datacenter'
])
param webVMWindowsOSVersion string = '2019-Datacenter'

@minLength(1)
param webPublicIPDnsName string

@minLength(1)
param sqlVMName string

@minLength(1)
param sqlVMAdminUserName string

@secure()
param sqlVMAdminPassword string

@allowed([
  'Web'
  'Standard'
])
param sqlVMSKU string = 'Web'

param resourceToken string

var abbrs = loadJsonContent('./abbreviations.json')

var azTrainingVNetPrefix = '10.0.0.0/16'
var azTrainingVNetSubnet1Name = 'FrontendNetwork'
var azTrainingVNetSubnet1Prefix = '10.0.0.0/24'
var azTrainingVNetSubnet2Name = 'BackendNetwork'
var azTrainingVNetSubnet2Prefix = '10.0.1.0/24'
var webVMImagePublisher = 'MicrosoftWindowsServer'
var webVMImageOffer = 'WindowsServer'
var webVMVmSize = 'Standard_D4lds_v5'
var webPublicIPName = 'WebPublicIP'
var sqlVMImagePublisher = 'MicrosoftSQLServer'
var sqlVMImageOffer = 'sql2019-ws2019'
var sqlVMVmSize = 'Standard_D4lds_v5'
var webApplicationToDeploy = 'https://https://github.com/rob-foulkrod/IAAS2019/raw/refs/heads/main/infra/artifacts/eshoponweb_iissosurce.zip'
var webDscFile = 'https://github.com/rob-foulkrod/IAAS2019/raw/refs/heads/main/infra/artifacts/WEBDSC.zip'
var sqlDscFile = 'https://github.com/rob-foulkrod/IAAS2019/raw/refs/heads/main/infra/artifacts/SQLDSC.zip'

module monitoring 'br/public:avm/ptn/azd/monitoring:0.1.0' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}${resourceToken}'
    location: resourceGroup().location
  }
}

module azTrainingVNet 'br/public:avm/res/network/virtual-network:0.5.1' = {
  name: 'azTrainingVNetDeployment'
  params: {
    // Required parameters
    addressPrefixes: [azTrainingVNetPrefix]
    name: '${abbrs.networkVirtualNetworks}${resourceToken}'
    // Non-required parameters
    location: resourceGroup().location
    tags: {
      displayName: 'AzTrainingVNet'
    }
    subnets: [
      {
        name: azTrainingVNetSubnet1Name
        addressPrefix: azTrainingVNetSubnet1Prefix
      }
      {
        name: azTrainingVNetSubnet2Name
        addressPrefix: azTrainingVNetSubnet2Prefix
      }
    ]
    diagnosticSettings: [
      {
        workspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
      }
    ]
  }
}

resource webPublicIP 'Microsoft.Network/publicIPAddresses@2016-03-30' = {
  name: webPublicIPName
  location: resourceGroup().location
  tags: {
    displayName: 'webPublicIP'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: webPublicIPDnsName
    }
  }
}
module webVM 'br/public:avm/res/compute/virtual-machine:0.10.1' = {
  name: 'WebvirtualMachineDeployment'
  params: {
    name: webVMName
    osType: 'Windows'
    vmSize: webVMVmSize
    zone: 0
    adminUsername: webVMAdminUserName
    adminPassword: webVMAdminPassword
    encryptionAtHost: false
    location: resourceGroup().location
    imageReference: {
      offer: webVMImageOffer
      publisher: webVMImagePublisher
      sku: webVMWindowsOSVersion
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
              publicIPAddressResourceId: webPublicIP.id
            }
            subnetResourceId: azTrainingVNet.outputs.subnetResourceIds[0]
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
          url: webDscFile
          script: 'WEBDSC.ps1'
          function: 'Main'
        }
        configurationArguments: {
          nodeName: webVMName
          webDeployPackage: webApplicationToDeploy
        }
      }
      diagnosticSettings: [
        {
          workspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
        }
      ]
    }
  }
}
module SQLVM 'br/public:avm/res/compute/virtual-machine:0.10.1' = {
  name: 'SQLvirtualMachineDeployment'
  params: {
    // Required parameters
    name: sqlVMName
    osType: 'Windows'
    vmSize: sqlVMVmSize

    zone: 0
    adminUsername: sqlVMAdminUserName
    adminPassword: sqlVMAdminPassword
    encryptionAtHost: false
    location: resourceGroup().location
    imageReference: {
      offer: sqlVMImageOffer
      publisher: sqlVMImagePublisher
      sku: sqlVMSKU
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
            subnetResourceId: azTrainingVNet.outputs.subnetResourceIds[1]
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
          url: sqlDscFile
          script: 'SQLDSC.ps1'
          function: 'Main'
        }
        configurationArguments: {
          nodeName: sqlVMName
        }
      }
    }
  }
}

output APP_ENDPOINT string = 'http://${webPublicIP.properties.dnsSettings.fqdn}'
