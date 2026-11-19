@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Environment prefix (e.g., dev, prod)')
@allowed([
  'dev'
  'prod'
])
param environment string = 'dev'

@description('Object ID of the admin user/principal for Key Vault RBAC access')
param adminObjectId string

var prefix = 'az-${environment}-core'
var vnetName = '${prefix}-vnet'
var nsgAppName = '${prefix}-app-nsg'
var keyVaultName = 'kv-${environment}-${uniqueString(resourceGroup().id)}'

// 1. Network Security Group (Zero-Trust baseline: deny public RDP/SSH, allow HTTPS)
resource appNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgAppName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'Deny-SSH-RDP-Internet'
        properties: {
          priority: 200
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
        }
      }
    ]
  }
}

// 2. Segmented Virtual Network (Application Subnet + Private Endpoints Subnet)
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-app'
        properties: {
          addressPrefix: '10.10.1.0/24'
          networkSecurityGroup: {
            id: appNsg.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
            }
          ]
        }
      }
      {
        name: 'snet-private-endpoints'
        properties: {
          addressPrefix: '10.10.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// 3. Azure Key Vault with RBAC authorization & Soft Delete enabled
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      virtualNetworkRules: [
        {
          id: vnet.properties.subnets[0].id
        }
      ]
    }
  }
}

// 4. Assign Key Vault Secrets Officer role to Admin Principal
var kvSecretsOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'

resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, adminObjectId, kvSecretsOfficerRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvSecretsOfficerRoleId)
    principalId: adminObjectId
    principalType: 'User'
  }
}

output vnetId string = vnet.id
output keyVaultUri string = keyVault.properties.vaultUri
