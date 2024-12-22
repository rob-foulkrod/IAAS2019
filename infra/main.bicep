targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param WebVMName string = ''

param WebVMAdminUserName string = ''

@secure()
param WebVMAdminPassword string

@allowed([
  '2008-R2-SP1'
  '2012-Datacenter'
  '2012-R2-Datacenter'
  '2019-Datacenter'
])
param WebVMWindowsOSVersion string = '2019-Datacenter'

param WebPublicIPDnsName string = ''

param SQLVMName string = ''

param SQLVMAdminUserName string = ''

@secure()
param SQLVMAdminPassword string

@allowed([
  'Web'
  'Standard'
])
param SQLVMSKU string = 'Web'

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
var derivedSQLVMName = SQLVMName == '' ? 'sqlvm-${environmentName}' : SQLVMName
var derivedWebVMName = WebVMName == '' ? 'webvm-${environmentName}' : WebVMName
var derivedWebPublicIPDnsName = WebPublicIPDnsName == '' ? 'iaas2019-${resourceToken}' : WebPublicIPDnsName

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
        name: 'WebVMAdminPassword'
        value: WebVMAdminPassword
      }
      {
        name: 'SQLVMAdminPassword'
        value: SQLVMAdminPassword
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
    WebVMName: derivedWebVMName
    WebVMAdminUserName: WebVMAdminUserName
    WebVMAdminPassword: WebVMAdminPassword
    SQLVMName: derivedSQLVMName
    SQLVMAdminUserName: SQLVMAdminUserName
    SQLVMAdminPassword: SQLVMAdminPassword
    SQLVMSKU: SQLVMSKU
    WebVMWindowsOSVersion: WebVMWindowsOSVersion
    WebPublicIPDnsName: derivedWebPublicIPDnsName
    ResourceToken: resourceToken
  }
}

output APP_ENDPOINT string = resources.outputs.APP_ENDPOINT
output AZURE_KEY_VAULT_NAME string = vault.outputs.name
