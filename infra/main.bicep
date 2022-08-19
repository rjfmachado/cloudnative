targetScope = 'resourceGroup'

param location string = resourceGroup().location
param tags object = {
  provisioner: 'bicep'
  source: 'github.com/rjfmachado/cloudnative'
}

// ## Network ##
param deployNetwork bool = true
param virtualNetworkName string = 'network'
param virtualNetworkDNSServers array = []

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = if (deployNetwork) {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    dhcpOptions: {
      dnsServers: virtualNetworkDNSServers
    }
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'aks-system-nodepool'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'aks-system-pods'
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: [
            {
              name: 'Microsoft.ContainerService/managedClusters'
              properties: {
                serviceName: 'Microsoft.ContainerService/managedClusters'
              }
            }
          ]
        }
      }
      {
        name: 'aks-monitor-nodepool'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: 'aks-monitor-pods'
        properties: {
          addressPrefix: '10.0.3.0/24'
          delegations: [
            {
              name: 'Microsoft.ContainerService/managedClusters'
              properties: {
                serviceName: 'Microsoft.ContainerService/managedClusters'
              }
            }
          ]
        }
      }
      {
        name: 'aks-app1-nodepool'
        properties: {
          addressPrefix: '10.0.4.0/24'
        }
      }
      {
        name: 'aks-app1-pods'
        properties: {
          addressPrefix: '10.0.5.0/24'
          delegations: [
            {
              name: 'Microsoft.ContainerService/managedClusters'
              properties: {
                serviceName: 'Microsoft.ContainerService/managedClusters'
              }
            }
          ]
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.254.0/24'
        }
      }
    ]
  }

  resource subnetAksSystemNodepool 'subnets' existing = {
    name: 'aks-system-nodepool'
  }

  resource subnetAksSystemPods 'subnets' existing = {
    name: 'aks-system-pods'
  }

  resource subnetAksMonitorNodepool 'subnets' existing = {
    name: 'aks-monitor-nodepool'
  }

  resource subnetAksMonitorPods 'subnets' existing = {
    name: 'aks-monitor-pods'
  }

  resource subnetAksApp1Nodepool 'subnets' existing = {
    name: 'aks-app1-nodepool'
  }

  resource subnetAksApp1Pods 'subnets' existing = {
    name: 'aks-app1-pods'
  }

  resource subnetAzureBastion 'subnets' existing = {
    name: 'AzureBastionSubnet'
  }
}

// ## Key Vault ##

param deployKeyvault bool = true
param keyvaultName string = 'ricardmakvakskms'
param principalId string
resource keyvaultAks 'Microsoft.KeyVault/vaults@2022-07-01' = if (deployKeyvault) {
  name: keyvaultName
  location: location
  tags: tags
  properties: {
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enablePurgeProtection: true
    enableRbacAuthorization: true
    enableSoftDelete: false
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
  }
}

resource aksCluster1kmskey 'Microsoft.KeyVault/vaults/keys@2022-07-01' = if (deployKeyvault) {
  name: 'cluster1kms'
  parent: keyvaultAks
  dependsOn: [
    IamaCryptoOfficer
  ]
  properties: {
    keySize: 2048
    kty: 'RSA'
    keyOps: [
      'decrypt'
      'encrypt'
      'sign'
      'unwrapKey'
      'verify'
      'wrapKey'
    ]
  }
}

resource azwiAppSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if (deployKeyvault) {
  name: 'workloadIdentitySecret'
  parent: keyvaultAks
  dependsOn: [
    IamaSecretsOfficer
  ]
  properties: {
    value: 'ThisIsSuperSecret!!!'
  }
}

resource roleKeyVaultCryptoOfficer 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = if (deployKeyvault) {
  scope: subscription()
  name: '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'
}

resource roleKeyVaultSecretsOfficer 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = if (deployKeyvault) {
  scope: subscription()
  name: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
}

resource IamaCryptoOfficer 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (deployKeyvault) {
  name: guid(resourceGroup().id, subscription().id, 'Key Vault Crypto Officer')
  scope: keyvaultAks
  properties: {
    principalId: principalId
    roleDefinitionId: roleKeyVaultCryptoOfficer.id
    principalType: 'User'
  }
}

resource IamaSecretsOfficer 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (deployKeyvault) {
  name: guid(resourceGroup().id, subscription().id, 'Key Vault Secrets Officer')
  scope: keyvaultAks
  properties: {
    principalId: principalId
    roleDefinitionId: roleKeyVaultSecretsOfficer.id
    principalType: 'User'
  }
}

// ## AKS ##
param deployCluster bool = true
param clusterName string = 'cloudnative'

resource cluster1Identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: clusterName
  location: location
  tags: tags
}

resource roleNetworkContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4d97b98b-1d4f-4787-a291-c67834d212e7'
}

resource roleKeyVaultCryptoUser 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '12338af0-0e69-4776-bea7-57ae8d297424'
}

resource roleKeyVaultSecretsUser 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

resource aksclusterIsNetworkContributor 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(resourceGroup().id, subscription().id, 'Network Contributor')
  scope: virtualNetwork
  properties: {
    principalId: cluster1Identity.properties.principalId
    roleDefinitionId: roleNetworkContributor.id
    principalType: 'ServicePrincipal'
  }
}

//Change to the key and retest
resource aksclusterIsKeyVaultCryptoUser 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(resourceGroup().id, subscription().id, 'Key Vault Crypto User')
  scope: keyvaultAks
  properties: {
    principalId: cluster1Identity.properties.principalId
    roleDefinitionId: roleKeyVaultCryptoUser.id
    principalType: 'ServicePrincipal'
  }
}

param azwi_APP_CLIENT_ID string
resource azwiIsKeyVaultSecretUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(azwiAppSecret.id, resourceGroup().id, subscription().id, 'Key Vault Secrets User')
  scope: azwiAppSecret
  properties: {
    principalId: azwi_APP_CLIENT_ID
    roleDefinitionId: roleKeyVaultSecretsUser.id
    principalType: 'ServicePrincipal'
  }
}

resource managedCluster 'Microsoft.ContainerService/managedClusters@2022-06-02-preview' = if (deployCluster) {
  name: clusterName
  location: location
  tags: tags
  dependsOn: [
    aksclusterIsKeyVaultCryptoUser
    aksclusterIsNetworkContributor
  ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${cluster1Identity.id}': {}
    }
  }
  properties: {
    dnsPrefix: 'ricardmamanaged'
    disableLocalAccounts: true
    enableRBAC: true
    aadProfile: {
      managed: true
      adminGroupObjectIDs: [
        '7fea8567-e0aa-40dd-bcd6-cbb6d556b4d3'
      ]
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      azureKeyVaultKms: {
        //keyVaultResourceId: null
        keyId: aksCluster1kmskey.properties.keyUriWithVersion
        //keyId: 'https://ricardmakvakskms.vault.azure.net/keys/cluster1kms/ebfef3a74d704c66b3b29e084dcfda73'
        keyVaultNetworkAccess: 'Public'
        enabled: false
      }
    }
    kubernetesVersion: '1.23'
    networkProfile: {
      networkMode: 'transparent'
      networkPlugin: 'azure'
      serviceCidr: '10.1.0.0/16'
      dnsServiceIP: '10.1.0.10'
    }
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
    }
    apiServerAccessProfile: {
      disableRunCommand: true
    }
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        count: 1
        vmSize: 'Standard_B2s'
        osType: 'Linux'
        enableAutoScaling: true
        maxCount: 3
        minCount: 1
        vnetSubnetID: virtualNetwork::subnetAksApp1Nodepool.id
        podSubnetID: virtualNetwork::subnetAksApp1Pods.id
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        upgradeSettings: {
          maxSurge: '50%'
        }
        scaleDownMode: 'Deallocate'
      }
      {
        name: 'monitoring'
        mode: 'User'
        count: 1
        vmSize: 'Standard_B2s'
        osType: 'Linux'
        enableAutoScaling: true
        maxCount: 3
        minCount: 1
        vnetSubnetID: virtualNetwork::subnetAksMonitorNodepool.id
        podSubnetID: virtualNetwork::subnetAksMonitorPods.id
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        upgradeSettings: {
          maxSurge: '50%'
        }
        scaleDownMode: 'Deallocate'
      }
      {
        name: 'app'
        mode: 'User'
        count: 1
        vmSize: 'Standard_B2s'
        osType: 'Linux'
        enableAutoScaling: true
        maxCount: 3
        minCount: 1
        vnetSubnetID: virtualNetwork::subnetAksApp1Nodepool.id
        podSubnetID: virtualNetwork::subnetAksApp1Pods.id
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        upgradeSettings: {
          maxSurge: '50%'
        }
        scaleDownMode: 'Deallocate'
      }
    ]
  }
}

// resource configStore 'Microsoft.AppConfiguration/configurationStores@2021-10-01-preview' = {
//   name: 'ricardmakms'
//   location: location
//   sku: {
//     name: 'standard'
//   }
// }

// resource configStoreKeyValue 'Microsoft.AppConfiguration/configurationStores/keyValues@2021-10-01-preview' = {
//   parent: configStore
//   name: 'ricardmakms'
//   properties: {
//     value: aksCluster1kmskey.properties.keyUriWithVersion
//   }
// }

output kmsKeyUriVersion string = aksCluster1kmskey.properties.keyUriWithVersion
output aksoOidcIssuerURL string = managedCluster.properties.oidcIssuerProfile.issuerURL
