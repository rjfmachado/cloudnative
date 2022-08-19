targetScope = 'resourceGroup'

param tags object = {
  provisioner: 'bicep'
  source: 'github.com/rjfmachado/cloudnative'
}

param keyvaultName string = 'ricardmakvakskms'
param azwi_APP_ID string

resource keyvault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyvaultName
  scope: resourceGroup()
}

resource roleKeyVaultSecretsUser 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

resource azwiAppSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: 'workloadIdentitySecret'
  parent: keyvault
  tags: tags
  properties: {
    value: 'ThisIsSuperSecret!!!'
  }
}

//assign read to the secret
resource azwiIsKeyVaultSecretUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(azwiAppSecret.id, resourceGroup().id, subscription().id, 'Key Vault Secrets User')
  scope: azwiAppSecret
  properties: {
    principalId: azwi_APP_ID
    roleDefinitionId: roleKeyVaultSecretsUser.id
    principalType: 'ServicePrincipal'
  }
}
