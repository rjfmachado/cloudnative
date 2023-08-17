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
param kubernetesVersion string = '1.27'
param kubernetesVersionSystemPool string = kubernetesVersion
param kubernetesVersionMonitoringPool string = kubernetesVersion
param kubernetesVersionAppsPool string = kubernetesVersion
param aksDnsPrefix string = 'ricardmacloudnative'

param workspaceName string = 'azuremonitor'

param deployOmsagent bool = true

param deployApplicationGatewayContainers bool = true
param ApplicationGatewayContainersName string = 'application-gateway-containers'

@description('Diagnostic categories to log')
param AksDiagCategories array = [
  'kube-apiserver'
  'kube-audit'
  'kube-audit-admin'
  'kube-controller-manager'
  'kube-scheduler'
  'cluster-autoscaler'
  'cloud-controller-manager'
  'guard'
  'csi-azuredisk-controller'
  'csi-azurefile-controller'
  'csi-snapshot-controller'
]

resource roleKeyVaultCryptoOfficer 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = if (deployKeyvault) {
  scope: subscription()
  name: '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'
}

resource roleKeyVaultSecretsOfficer 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = if (deployKeyvault) {
  scope: subscription()
  name: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
}

resource roleMonitoringMetricsPublisher 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '3913510d-42f4-4e42-8a64-420c390055eb'
}

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
        name: 'aks-application-gateway'
        properties: {
          addressPrefix: '10.0.253.0/24'
          delegations: [
            {
              name: 'Microsoft.ServiceNetworking/trafficControllers'
              properties: {
                serviceName: 'Microsoft.ServiceNetworking/trafficControllers'
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

  resource subnetApplicationGatewayContainers 'subnets' existing = {
    name: 'aks-application-gateway'
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
resource IamaCryptoOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployKeyvault) {
  name: guid(resourceGroup().id, subscription().id, 'Key Vault Crypto Officer')
  scope: keyvaultAks
  properties: {
    principalId: principalId
    roleDefinitionId: roleKeyVaultCryptoOfficer.id
    principalType: 'User'
  }
}

//Grant me rights to create secrets
resource IamaSecretsOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployKeyvault) {
  name: guid(resourceGroup().id, subscription().id, 'Key Vault Secrets Officer')
  scope: keyvaultAks
  properties: {
    principalId: principalId
    roleDefinitionId: roleKeyVaultSecretsOfficer.id
    principalType: 'User'
  }
}

resource cluster1Identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
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

resource aksclusterIsNetworkContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('aksclusterIsNetworkContributor', resourceGroup().id, subscription().id, 'Network Contributor')
  scope: virtualNetwork
  properties: {
    principalId: cluster1Identity.properties.principalId
    roleDefinitionId: roleNetworkContributor.id
    principalType: 'ServicePrincipal'
  }
}

resource aksclusterIsKeyCryptoUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployKeyvault) {
  name: guid(resourceGroup().id, subscription().id, 'Key Vault Crypto User')
  scope: keyAksCluster1kms
  properties: {
    principalId: cluster1Identity.properties.principalId
    roleDefinitionId: roleKeyVaultCryptoUser.id
    principalType: 'ServicePrincipal'
  }
}

resource monitorresourcegroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: 'monitoring'
  scope: subscription('7efaa91f-4e11-4abd-86dc-bc40075afeec')
}

resource monitorworkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
  scope: monitorresourcegroup
}

resource managedCluster 'Microsoft.ContainerService/managedClusters@2023-06-01' = if (deployCluster) {
  name: clusterName
  location: location
  tags: tags
  dependsOn: [
    aksclusterIsKeyCryptoUser
    aksclusterIsNetworkContributor
    ApplicationGatewayContainersAssociation
  ]
  sku: {
    name: 'Base'
    tier: 'Free'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${cluster1Identity.id}': {}
    }
  }
  properties: {
    kubernetesVersion: kubernetesVersion
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
      azureKeyVaultKms: deployKeyvault ? {
        keyId: keyAksCluster1kms.properties.keyUriWithVersion
        keyVaultNetworkAccess: 'Public'
        enabled: true
      } : {}
      workloadIdentity: {
        enabled: true
      }
      defender: {
        logAnalyticsWorkspaceResourceId: monitorworkspace.id
        securityMonitoring: {
          enabled: true
        }
      }
    }
    networkProfile: {
      networkPolicy: 'azure'
      networkPluginMode: 'Overlay'
      networkPlugin: 'azure'
      serviceCidr: '10.253.0.0/16'
      dnsServiceIP: '10.253.0.10'
      podCidr: '10.254.0.0/16'
    }
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
    }
    apiServerAccessProfile: {
      disableRunCommand: true
    }
    storageProfile: {
      blobCSIDriver: {
        enabled: false
      }
      diskCSIDriver: {
        enabled: true
      }
      fileCSIDriver: {
        enabled: false
      }
    }
    addonProfiles: {
      omsagent: {
        enabled: deployOmsagent
        config: {
          logAnalyticsWorkspaceResourceID: monitorworkspace.id

        }
      } }
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        orchestratorVersion: kubernetesVersionSystemPool
        count: 3
        vmSize: 'Standard_B2s'
        osType: 'Linux'
        enableAutoScaling: true
        maxCount: 4
        minCount: 3
        osSKU: 'AzureLinux'
        vnetSubnetID: virtualNetwork::subnetAksApp1Nodepool.id
        //podSubnetID: virtualNetwork::subnetAksSystemPods.id
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
        osSKU: 'AzureLinux'
        vnetSubnetID: virtualNetwork::subnetAksMonitorNodepool.id
        //podSubnetID: virtualNetwork::subnetAksMonitoringPods.id
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
        count: 2
        vmSize: 'Standard_B2s'
        osType: 'Linux'
        enableAutoScaling: true
        maxCount: 3
        minCount: 1
        osSKU: 'AzureLinux'
        vnetSubnetID: virtualNetwork::subnetAksApp1Nodepool.id
        //podSubnetID: virtualNetwork::subnetAksPods.id
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

resource fluxAddon 'Microsoft.KubernetesConfiguration/extensions@2023-05-01' = if (fluxGitOpsAddon) {
  name: 'fluxAddon'
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
  }
}

resource fluxcluster 'Microsoft.KubernetesConfiguration/fluxConfigurations@2023-05-01' = if (fluxGitOpsAddon) {
  name: 'cluster-configuration'
  scope: managedCluster
  dependsOn: [
    fluxAddon
  ]
  properties: {
    scope: 'cluster'
    sourceKind: 'GitRepository'
    namespace: 'flux-system'
    suspend: false
    gitRepository: {
      url: 'https://github.com/rjfmachado/cloudnative'
      repositoryRef: {
        branch: 'main'
      }
    }
    configurationProtectedSettings: {
      albidentityclientid: base64(ApplicationGatewayContainersIdentity.properties.clientId)
    }
    kustomizations: {
      infra: {
        path: './gitops/cluster'
        prune: true
        syncIntervalInSeconds: 120
      }
    }
  }
}

//This role assignment enables AKS->LA Fast Alerting experience
resource FastAlertingRole_Aks_Law 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployOmsagent) {
  scope: managedCluster
  name: guid(managedCluster.id, 'omsagent', roleMonitoringMetricsPublisher.id)
  properties: {
    roleDefinitionId: roleMonitoringMetricsPublisher.id
    principalId: managedCluster.properties.addonProfiles.omsagent.identity.objectId
    principalType: 'ServicePrincipal'
  }
}

resource AksDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (deployOmsagent) {
  name: 'aksDiags'
  scope: managedCluster
  properties: {
    workspaceId: monitorworkspace.id
    logs: [for aksDiagCategory in AksDiagCategories: {
      category: aksDiagCategory
      enabled: true
    }]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource roleAppGwforContainersConfigurationManager 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = if (deployApplicationGatewayContainers) {
  scope: subscription()
  name: 'fbc52c3f-28ad-4303-a892-8a056630b8f1'
}

resource ApplicationGatewayContainersIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: ApplicationGatewayContainersName
  location: location
  tags: tags
}
resource ApplicationGatewayContainersIdentityFederatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = if (deployApplicationGatewayContainers) {
  name: 'azure-alb-identity'
  parent: ApplicationGatewayContainersIdentity
  properties: {
    audiences: [ 'api://AzureADTokenExchange' ]
    issuer: managedCluster.properties.oidcIssuerProfile.issuerURL
    subject: 'system:serviceaccount:azure-alb-system:alb-controller-sa'
  }
}

resource ApplicationGatewayContainersIsNetworkContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('ApplicationGatewayContainersIsNetworkContributor', resourceGroup().id, subscription().id, 'Network Contributor')
  scope: virtualNetwork::subnetApplicationGatewayContainers
  properties: {
    principalId: ApplicationGatewayContainersIdentity.properties.principalId
    roleDefinitionId: roleNetworkContributor.id
    principalType: 'ServicePrincipal'
  }
}

resource ApplicationGatewayContainersIsConfigurationManager 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('ApplicationGatewayContainersIsConfigurationManager', resourceGroup().id, subscription().id, 'AppGw for Containers Configuration Manager')
  scope: resourceGroup()
  properties: {
    principalId: ApplicationGatewayContainersIdentity.properties.principalId
    roleDefinitionId: roleAppGwforContainersConfigurationManager.id
    principalType: 'ServicePrincipal'
  }
}

resource ApplicationGatewayContainers 'Microsoft.ServiceNetworking/trafficControllers@2023-05-01-preview' = if (deployApplicationGatewayContainers) {
  name: ApplicationGatewayContainersName
  location: location
  properties: {}
}

resource ApplicationGatewayContainersAssociation 'Microsoft.ServiceNetworking/trafficControllers/associations@2023-05-01-preview' = {
  name: guid('ApplicationGatewayContainersAssociation', resourceGroup().id, subscription().id, 'ApplicationGatewayContainersAssociation')
  location: location
  parent: ApplicationGatewayContainers
  properties: {
    associationType: 'subnets'
    subnet: {
      id: virtualNetwork::subnetApplicationGatewayContainers.id
    }
  }
}

output fluxReleaseNamespace string = fluxGitOpsAddon ? fluxAddon.properties.scope.cluster.releaseNamespace : ''
//output kmsKeyUriVersion string = deployKeyvault ? keyAksCluster1kms.properties.keyUriWithVersion : ''
//output aksoOidcIssuerURL string = managedCluster.properties.oidcIssuerProfile.issuerURL
