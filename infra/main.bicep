targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param webVMName string = ''

param webVMAdminUserName string = ''

@secure()
param webVMAdminPassword string

@allowed([
  '2008-R2-SP1'
  '2012-Datacenter'
  '2012-R2-Datacenter'
  '2019-Datacenter'
])
param webVMWindowsOSVersion string = '2019-Datacenter'

param webPublicIPDnsName string = ''

param sqlVMName string = ''

param sqlVMAdminUserName string = ''

@secure()
param sqlVMAdminPassword string

@allowed([
  'Web'
  'Standard'
])
param sqlVMSKU string = 'Web'

param currentUserId string

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

//set the sqlvmname if blank
var derivedSQLVMName = sqlVMName == '' ? 'sqlvm-${environmentName}' : sqlVMName
var derivedWebVMName = webVMName == '' ? 'webvm-${environmentName}' : webVMName
var derivedWebPublicIPDnsName = webPublicIPDnsName == '' ? 'iaas2019-${resourceToken}' : webPublicIPDnsName

var abbrs = loadJsonContent('./abbreviations.json')

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module vault 'br/public:avm/res/key-vault/vault:0.11.0' = {
  scope: rg
  name: 'vaultDeployment'
  params: {
    name: '${abbrs.keyVaultVaults}${resourceToken}'
    enablePurgeProtection: false
    location: rg.location
    secrets: [
      {
        name: 'webVMAdminPassword'
        value: webVMAdminPassword
      }
      {
        name: 'sqlVMAdminPassword'
        value: sqlVMAdminPassword
      }
    ]
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Key Vault Secrets Officer'
        principalId: currentUserId
      }
    ]
  }
}

//call into the module to create the resources
module resources './resources.bicep' = {
  name: 'resources'
  scope: rg
  params: {
    webVMName: derivedWebVMName
    webVMAdminUserName: webVMAdminUserName
    webVMAdminPassword: webVMAdminPassword
    sqlVMName: derivedSQLVMName
    sqlVMAdminUserName: sqlVMAdminUserName
    sqlVMAdminPassword: sqlVMAdminPassword
    sqlVMSKU: sqlVMSKU
    webVMWindowsOSVersion: webVMWindowsOSVersion
    webPublicIPDnsName: derivedWebPublicIPDnsName
    resourceToken: resourceToken
  }
}

output APP_ENDPOINT string = resources.outputs.APP_ENDPOINT
output AZURE_KEY_VAULT_NAME string = vault.outputs.name
