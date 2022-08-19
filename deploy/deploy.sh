[[ -z "${AZURE_RG_NAME}" ]] && export AZURE_RG_NAME='cloudnative'
[[ -z "${AZURE_LOCATION}" ]] && export AZURE_LOCATION='uksouth'

# Grant myself rights to create secrets via Key Vault RBAC
export MY_SERVICE_PRINCIPAL_ID=$(az ad signed-in-user show -o tsv --query id)

az group create --name $AZURE_RG_NAME --location $AZURE_LOCATION -o none

#USING RBAC
az deployment group create -g $AZURE_RG_NAME \
  -o none \
  --template-file infra/main.bicep \
  --parameters principalId=$MY_SERVICE_PRINCIPAL_ID
