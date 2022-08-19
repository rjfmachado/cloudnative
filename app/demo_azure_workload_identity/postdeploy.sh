azwi serviceaccount create phase app --aad-application-name "azwi"

azwi serviceaccount create phase sa \
  --aad-application-name "azwi" \
  --service-account-namespace "default" \
  --service-account-name "workload-identity-sa"

azwi serviceaccount create phase federated-identity \
  --aad-application-name "azwi" \
  --service-account-namespace "default" \
  --service-account-name "workload-identity-sa" \
  --service-account-issuer-url "https://oidc.prod-aks.azure.com/baa6f725-d7e2-412a-9ea7-c62c6621a124/"