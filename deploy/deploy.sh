[[ -z "${AZURE_RG_NAME}" ]] && export AZURE_RG_NAME='cloudnative'
[[ -z "${AZURE_LOCATION}" ]] && export AZURE_LOCATION='uksouth'

az group create --name $AZURE_RG_NAME --location $AZURE_LOCATION -o none
az deployment group create -g $AZURE_RG_NAME -o jsonc \
  --template-file infra/main.bicep \
  --parameters principalId=$(az ad signed-in-user show -o tsv --query id)
