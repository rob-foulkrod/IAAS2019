targetScope = 'subscription'

@minLength(1)
@maxLength(10)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string = 'dev'

@minLength(1)
@description('Primary location for all resources')
param location string = 'eastus'

@description('The name of the web Virtual Machine')
@maxLength(15)
param webVMName string = take('webvm-${environmentName}', 15)

@description('The name of the web Virtual Machine Admin User')
@secure()
param webVMAdminUserName string = newGuid()

@description('Password for the web Virtual Machine Admin User')
@secure()
param webVMAdminPassword string = newGuid()

@description('The name of the SQL Virtual Machine')
@maxLength(15)
@minLength(1)
param sqlVMName string = take('sqlvm-${environmentName}', 15)

@description('The name of the SQL Virtual Machine Admin User')
@secure()
param sqlVMAdminUserName string = newGuid()

@description('Password for the SQL Virtual Machine Admin User')
@secure()
param sqlVMAdminPassword string = newGuid()

@allowed([
  '2008-R2-SP1'
  '2012-Datacenter'
  '2012-R2-Datacenter'
  '2019-Datacenter'
])
@description('Windows OS version for the web Virtual Machine')
param webVMWindowsOSVersion string = '2019-Datacenter'

@description('DNS name for the web Public IP where the application will be exposed')
@maxLength(61)
@minLength(1)
param webPublicIPDnsName string = take('dns-${environmentName}', 61)

@allowed([
  'Web'
  'Standard'
])
@description('SKU for the SQL Virtual Machine')
param sqlVMSKU string = 'Web'

@description('The current user id. Will be supplied by azd')
param currentUserId string = newGuid()

// Tags that should be applied to all resources.
var tags = {
  'azd-env-name': environmentName
}

var resourceUniquifier = toLower(uniqueString(subscription().id, environmentName, location))

var derivedWebPublicIPDnsName = webPublicIPDnsName == '' ? 'iaas-${resourceUniquifier}' : webPublicIPDnsName

var abbrs = loadJsonContent('./abbreviations.json')

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

@description('A Log Analytics Wrokspace and App Insights component for monitoring')
module monitoring 'br/public:avm/ptn/azd/monitoring:0.1.0' = {
  name: 'monitoring'
  scope: rg
  params: {
    tags: tags
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceUniquifier}'
    applicationInsightsName: '${abbrs.insightsComponents}${resourceUniquifier}'
  }
}

@description('the vault used to store the sql and vm passwords')
#disable-next-line secure-secrets-in-params - Individual secrets are marked
module vault 'br/public:avm/res/key-vault/vault:0.11.1' = {
  scope: rg
  name: 'vaultDeployment'
  params: {
    name: '${abbrs.keyVaultVaults}${resourceUniquifier}'
    enablePurgeProtection: false
    location: rg.location
    tags: tags
    diagnosticSettings: [
      {
        workspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
      }
    ]
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

@description('Demo Resources ')
module resources './resources.bicep' = {
  name: 'resources'
  scope: rg
  params: {
    webVMName: webVMName
    webVMAdminUserName: webVMAdminUserName
    webVMAdminPassword: webVMAdminPassword
    sqlVMName: sqlVMName
    sqlVMAdminUserName: sqlVMAdminUserName
    sqlVMAdminPassword: sqlVMAdminPassword
    sqlVMSKU: sqlVMSKU
    webVMWindowsOSVersion: webVMWindowsOSVersion
    webPublicIPDnsName: derivedWebPublicIPDnsName
    resourceUniquifier: resourceUniquifier
    logAnalyticsId: monitoring.outputs.logAnalyticsWorkspaceResourceId
    tags: tags
  }
}

output APP_ENDPOINT string = resources.outputs.APP_ENDPOINT
output AZURE_KEY_VAULT_NAME string = vault.outputs.name
