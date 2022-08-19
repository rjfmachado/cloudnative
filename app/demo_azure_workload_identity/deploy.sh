[[ -z "${AZURE_RG_NAME}" ]] && export AZURE_RG_NAME='cloudnative'
[[ -z "${AZURE_LOCATION}" ]] && export AZURE_LOCATION='uksouth'

export AZWI_OBJECT_ID="$(az ad sp list --display-name azwi -o tsv --query '[0].id')"

#USING RBAC
az deployment group create -g $AZURE_RG_NAME \
  -o tsv \
  --template-file app/demo_azure_workload_identity/azwi.bicep \
  --parameters azwi_APP_ID=$AZWI_OBJECT_ID
