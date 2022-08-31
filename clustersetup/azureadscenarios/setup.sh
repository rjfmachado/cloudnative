export USER_DEVELOPER_DISPLAY_NAME='developer'
export USER_DEVELOPER_UPN='developer@ricardomachado.net'
read -s -p "Password: "
az ad user create --display-name $USER_DEVELOPER_DISPLAY_NAME --user-principal-name $USER_DEVELOPER_UPN --password $REPLY
unset REPLY

export USER_DEVELOPER_ID=$(az ad user list --upn $USER_DEVELOPER_UPN -o tsv --query [0].id)

kubectl create namespace testdeveloper
kubectl run my-nginx --image=nginx --port=80 --namespace testdeveloper

export AKS_ID=$(az aks show -g cloudnative -n cloudnative --query id -o tsv)

# get access to kubeconfig
az role assignment create --role "Azure Kubernetes Service Cluster User Role" --assignee $USER_DEVELOPER_ID --scope "$AKS_ID"
# get read access to cluster objects (makes portal happy, kubectl does not need this)
az role assignment create --role "Azure Kubernetes Service RBAC Reader" --assignee $USER_DEVELOPER_ID --scope "$AKS_ID"
# get write access to namespace
az role assignment create --role "Azure Kubernetes Service RBAC Admin" --assignee $USER_DEVELOPER_ID --scope "$AKS_ID/namespaces/testdeveloper"

#view the roles
az role definition list | grep Kubernetes
az role definition list -n "Azure Kubernetes Service RBAC Reader" -o jsonc

# wee bit of powershell
Get-AzRoleAssignment | where {$_.SignInName -eq 'developer@ricardomachado.net'} | Remove-AzRoleAssignment