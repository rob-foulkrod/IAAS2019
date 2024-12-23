targetScope = 'resourceGroup'

@minLength(1)
@maxLength(15)
@description('Name of the web Virtual Machine')
param webVMName string = 'webvm'

@minLength(1)
@description('Name of the web Virtual Machine Admin User')
param webVMAdminUserName string = newGuid()

@description('Password for the web Virtual Machine Admin User')
@secure()
param webVMAdminPassword string = newGuid()

@allowed([
  '2008-R2-SP1'
  '2012-Datacenter'
  '2012-R2-Datacenter'
  '2019-Datacenter'
])
@description('Windows OS version for the web Virtual Machine')
param webVMWindowsOSVersion string = '2019-Datacenter'

@minLength(1)
@maxLength(61)
@description('DNS name for the web Public IP where the application will be exposed')
param webPublicIPDnsName string = 'some-dns-name'

@minLength(1)
@maxLength(15)
@description('Name of the SQL Virtual Machine')
param sqlVMName string = 'sqlvm'

@minLength(1)
@description('Name of the SQL Virtual Machine Admin User')
param sqlVMAdminUserName string = newGuid()

@secure()
@description('Password for the SQL Virtual Machine Admin User')
param sqlVMAdminPassword string = newGuid()

@allowed([
  'Web'
  'Standard'
])
@description('SKU for the SQL Virtual Machine')
param sqlVMSKU string = 'Web'

@description('a unique string to ensure resource uniqueness')
param resourceUniquifier string = 'abc1234'

@description('The name of the Log Analytics Workspace created for monitoring')
param logAnalyticsId string = newGuid()

@description('Tags to be applied to all resources')
param tags object = {
  'azd-env-name': 'dev'
}

var abbrs = loadJsonContent('./abbreviations.json')

var azTrainingVNetPrefix = '10.0.0.0/16'
var azTrainingVNetSubnet1Name = 'FrontendNetwork'
var azTrainingVNetSubnet1Prefix = '10.0.0.0/24'
var azTrainingVNetSubnet2Name = 'BackendNetwork'
var azTrainingVNetSubnet2Prefix = '10.0.1.0/24'
var webVMImagePublisher = 'MicrosoftWindowsServer'
var webVMImageOffer = 'WindowsServer'
var webVMVmSize = 'Standard_D4lds_v5'
var sqlVMImagePublisher = 'MicrosoftSQLServer'
var sqlVMImageOffer = 'sql2019-ws2019'
var sqlVMVmSize = 'Standard_D4lds_v5'
var webApplicationToDeploy = 'https://github.com/rob-foulkrod/IAAS2019/raw/main/infra/artifacts/eshoponweb_iissource.zip'
var webDscFile = 'https://github.com/rob-foulkrod/IAAS2019/raw/refs/heads/main/infra/artifacts/WEBDSC.zip'
var sqlDscFile = 'https://github.com/rob-foulkrod/IAAS2019/raw/refs/heads/main/infra/artifacts/SQLDSC.zip'

@description('A Virtual Network with two subnets')
module azTrainingVNet 'br/public:avm/res/network/virtual-network:0.5.1' = {
  name: 'azTrainingVNetDeployment'
  params: {
    // Required parameters
    addressPrefixes: [azTrainingVNetPrefix]
    name: '${abbrs.networkVirtualNetworks}${resourceUniquifier}'
    location: resourceGroup().location
    tags: union(tags, { displayName: 'azTrainingVNet' })

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
        workspaceResourceId: logAnalyticsId
      }
    ]
  }
}

@description('A Public IP address for the web Virtual Machine')
resource webPublicIP 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${abbrs.networkPublicIPAddresses}${resourceUniquifier}'
  location: resourceGroup().location
  tags: union(tags, {
    displayName: 'WebPublicIP'
  })
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: webPublicIPDnsName
    }
  }
  dependsOn: []
}

@description('A Virtual Machine for the web application')
module webVM 'br/public:avm/res/compute/virtual-machine:0.10.1' = {
  name: 'WebvirtualMachineDeployment'
  params: {
    tags: tags
    name: webVMName
    computerName: webVMName
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
            workspaceResourceId: logAnalyticsId
          }
        ]
        ipConfigurations: [
          {
            tags: tags
            name: 'webipconfig1'
            nicIpConfigName: 'webipconfig1'
            pipConfiguration: {
              publicIPAddressResourceId: webPublicIP.id
              publicIpNameSuffix: '-pip-01'
            }
            subnetResourceId: azTrainingVNet.outputs.subnetResourceIds[0]
            privateIPAllocationMethod: 'Dynamic'
            diagnosticSettings: [
              {
                workspaceResourceId: logAnalyticsId
              }
            ]
          }
        ]
        nicSuffix: '-nic-01'
      }
    ]
    osDisk: {
      name: 'webosdisk'
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
          workspaceResourceId: logAnalyticsId
        }
      ]
    }
  }
}
@description('A Virtual Machine for the SQL Server')
module SQLVM 'br/public:avm/res/compute/virtual-machine:0.10.1' = {
  name: 'SQLvirtualMachineDeployment'
  params: {
    tags: tags
    // Required parameters
    name: sqlVMName
    computerName: sqlVMName
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
            workspaceResourceId: logAnalyticsId
          }
        ]
        ipConfigurations: [
          {
            name: 'sqlipconfig'
            nicIpConfigName: 'sqlipconfig'
            subnetResourceId: azTrainingVNet.outputs.subnetResourceIds[1]
            privateIPAllocationMethod: 'Dynamic'
            diagnosticSettings: [
              {
                workspaceResourceId: logAnalyticsId
              }
            ]
          }
        ]
      }
    ]
    osDisk: {
      name: 'sqlosdisk'
      caching: 'ReadWrite'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    dataDisks: [
      {
        name: 'webdatadisk1'
        diskSizeGB: 1023
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        lun: 0
        createOption: 'Empty'
        tags: tags
      }
      {
        name: 'webdatadisk2'
        diskSizeGB: 1023
        lun: 1
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        createOption: 'Empty'
        tags: tags
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
          workspaceResourceId: logAnalyticsId
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
