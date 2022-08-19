cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: quick-start
  namespace: default
spec:
  serviceAccountName: workload-identity-sa
  containers:
    - image: ghcr.io/azure/azure-workload-identity/msal-go
      name: oidc
      env:
      - name: KEYVAULT_NAME
        value: ricardmakvakskms
      - name: SECRET_NAME
        value: workloadIdentitySecret
  nodeSelector:
    kubernetes.io/os: linux
EOF