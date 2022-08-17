az aks show --name cloudnative -g cloudnative -o jsonc | jq .securityProfile.azureKeyVaultKms
export KEY_ID=$(az keyvault key show --name cluster1kms --vault-name ricardmakvakskms --query 'key.kid' -o tsv)

echo $KEY_ID
az aks update --name cloudnative --resource-group cloudnative --enable-azure-keyvault-kms --azure-keyvault-kms-key-vault-network-access "Public" --azure-keyvault-kms-key-id $KEY_ID
az aks show --name cloudnative -g cloudnative -o jsonc | jq .securityProfile.azureKeyVaultKms