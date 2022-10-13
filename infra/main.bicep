targetScope = 'resourceGroup'

param location string = resourceGroup().location
param tags object = {
  provisioner: 'bicep'
  source: 'github.com/rjfmachado/cloudnative'
}

param deployNetwork bool = true
param virtualNetworkName string = 'network'
param virtualNetworkDNSServers array = []

param deployKeyvault bool = true
param keyvaultName string = 'ricardmakvakskms1'
param principalId string

param deployCluster bool = true
param clusterName string = 'cloudnative'
param aksAdminGroupId string = '7fea8567-e0aa-40dd-bcd6-cbb6d556b4d3'
param kubernetesVersion string = '1.24'
param kubernetesVersionSystemPool string = kubernetesVersion
param kubernetesVersionMonitoringPool string = kubernetesVersion
param kubernetesVersionAppsPool string = kubernetesVersion
param aksDnsPrefix string = 'ricardmacloudnative'

resource roleKeyVaultCryptoOfficer 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = if (deployKeyvault) {
  scope: subscription()
  name: '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'
}

resource roleKeyVaultSecretsOfficer 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = if (deployKeyvault) {
  scope: subscription()
  name: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
}

// resource roleKeyVaultSecretsUser 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
//   scope: subscription()
//   name: '4633458b-17de-408a-b874-0445c86b69e6'
// }

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
        name: 'aks-monitor-nodepool'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: 'aks-app1-nodepool'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: 'aks-pods'
        properties: {
          addressPrefix: '10.0.16.0/22'
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

  resource subnetAksMonitorNodepool 'subnets' existing = {
    name: 'aks-monitor-nodepool'
  }

  resource subnetAksApp1Nodepool 'subnets' existing = {
    name: 'aks-app1-nodepool'
  }

  resource subnetAksPods 'subnets' existing = {
    name: 'aks-pods'
  }

  resource subnetAzureBastion 'subnets' existing = {
    name: 'AzureBastionSubnet'
  }
}

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

resource keyAksCluster1kms 'Microsoft.KeyVault/vaults/keys@2022-07-01' = if (deployKeyvault) {
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

//Grant me rights to create keys
resource IamaCryptoOfficer 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (deployKeyvault) {
  name: guid(resourceGroup().id, subscription().id, 'Key Vault Crypto Officer')
  scope: keyvaultAks
  properties: {
    principalId: principalId
    roleDefinitionId: roleKeyVaultCryptoOfficer.id
    principalType: 'User'
  }
}

//Grant me rights to create secrets
resource IamaSecretsOfficer 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (deployKeyvault) {
  name: guid(resourceGroup().id, subscription().id, 'Key Vault Secrets Officer')
  scope: keyvaultAks
  properties: {
    principalId: principalId
    roleDefinitionId: roleKeyVaultSecretsOfficer.id
    principalType: 'User'
  }
}

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

resource aksclusterIsNetworkContributor 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(resourceGroup().id, subscription().id, 'Network Contributor')
  scope: virtualNetwork
  properties: {
    principalId: cluster1Identity.properties.principalId
    roleDefinitionId: roleNetworkContributor.id
    principalType: 'ServicePrincipal'
  }
}

resource aksclusterIsKeyCryptoUser 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(resourceGroup().id, subscription().id, 'Key Vault Crypto User')
  scope: keyAksCluster1kms
  properties: {
    principalId: cluster1Identity.properties.principalId
    roleDefinitionId: roleKeyVaultCryptoUser.id
    principalType: 'ServicePrincipal'
  }
}

resource managedCluster 'Microsoft.ContainerService/managedClusters@2022-06-02-preview' = if (deployCluster) {
  name: clusterName
  location: location
  tags: tags
  dependsOn: [
    aksclusterIsKeyCryptoUser
    aksclusterIsNetworkContributor
  ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${cluster1Identity.id}': {}
    }
  }
  properties: {
    dnsPrefix: aksDnsPrefix
    disableLocalAccounts: true
    enableRBAC: true
    aadProfile: {
      managed: true
      adminGroupObjectIDs: [
        aksAdminGroupId
      ]
      enableAzureRBAC: true
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      azureKeyVaultKms: {
        //keyVaultResourceId: null
        keyId: keyAksCluster1kms.properties.keyUriWithVersion
        //keyId: 'https://ricardmakvakskms.vault.azure.net/keys/cluster1kms/ebfef3a74d704c66b3b29e084dcfda73'
        keyVaultNetworkAccess: 'Public'
        enabled: false
      }
    }
    kubernetesVersion: kubernetesVersion
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
        type: 'VirtualMachineScaleSets'
        orchestratorVersion: kubernetesVersionSystemPool
        count: 1
        vmSize: 'Standard_B2s'
        osType: 'Linux'
        enableAutoScaling: true
        maxCount: 3
        minCount: 1
        osSKU: 'CBLMariner'
        vnetSubnetID: virtualNetwork::subnetAksApp1Nodepool.id
        podSubnetID: virtualNetwork::subnetAksPods.id
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        upgradeSettings: {
          maxSurge: '50%'
        }
        scaleDownMode: 'Deallocate'
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
      }
      {
        name: 'monitoring'
        mode: 'User'
        type: 'VirtualMachineScaleSets'
        orchestratorVersion: kubernetesVersionMonitoringPool
        count: 1
        vmSize: 'Standard_B2s'
        osType: 'Linux'
        enableAutoScaling: true
        maxCount: 3
        minCount: 1
        osSKU: 'CBLMariner'
        vnetSubnetID: virtualNetwork::subnetAksMonitorNodepool.id
        podSubnetID: virtualNetwork::subnetAksPods.id
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        upgradeSettings: {
          maxSurge: '50%'
        }
        scaleDownMode: 'Deallocate'
        nodeTaints: [
          'MonitoringOnly=true:NoSchedule'
        ]
      }
      {
        name: 'apps'
        mode: 'User'
        type: 'VirtualMachineScaleSets'
        orchestratorVersion: kubernetesVersionAppsPool
        count: 1
        vmSize: 'Standard_B2s'
        osType: 'Linux'
        enableAutoScaling: true
        maxCount: 3
        minCount: 1
        osSKU: 'CBLMariner'
        vnetSubnetID: virtualNetwork::subnetAksApp1Nodepool.id
        podSubnetID: virtualNetwork::subnetAksPods.id
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

  resource system 'agentPools' existing = {
    name: 'system'
  }

  resource monitoring 'agentPools' existing = {
    name: 'monitoring'
  }

  resource apps 'agentPools' existing = {
    name: 'apps'
  }
}

param fluxGitOpsAddon bool = true

resource fluxAddon 'Microsoft.KubernetesConfiguration/extensions@2020-07-01-preview' = if (fluxGitOpsAddon) {
  name: 'flux'
  scope: managedCluster
  properties: {
    extensionType: 'microsoft.flux'
    autoUpgradeMinorVersion: true
    releaseTrain: 'Stable'
    scope: {
      cluster: {
        releaseNamespace: 'flux-system'
      }
    }
    configurationProtectedSettings: {}
  }
}

output fluxReleaseNamespace string = fluxGitOpsAddon ? fluxAddon.properties.scope.cluster.releaseNamespace : ''

output kmsKeyUriVersion string = keyAksCluster1kms.properties.keyUriWithVersion
output aksoOidcIssuerURL string = managedCluster.properties.oidcIssuerProfile.issuerURL
