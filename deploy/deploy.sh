[[ -z "${AZURE_RG_NAME}" ]] && export AZURE_RG_NAME='cloudnative'
[[ -z "${AZURE_LOCATION}" ]] && export AZURE_LOCATION='uksouth'

export AZWI_CLIENT_ID="$(az ad sp list --display-name azwi -o tsv --query '[0].appId')"
export MY_SERVICE_PRINCIPAL_ID=$(az ad signed-in-user show -o tsv --query id)

az group create --name $AZURE_RG_NAME --location $AZURE_LOCATION -o none
az deployment group create -g $AZURE_RG_NAME \
  -o jsonc \
  --template-file infra/main.bicep \
  --parameters principalId=$MY_SERVICE_PRINCIPAL_ID \
  --parameters azwi_APP_CLIENT_ID=$AZWI_CLIENT_ID
