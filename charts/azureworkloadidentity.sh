export AZURE_TENANT_ID="$(az account show --query tenantId -otsv)"
helm install workload-identity-webhook azure-workload-identity/workload-identity-webhook \
   --namespace azure-workload-identity-system \
   --create-namespace \
   --set azureTenantID="${AZURE_TENANT_ID}"

azwi serviceaccount create phase app --aad-application-name azwi