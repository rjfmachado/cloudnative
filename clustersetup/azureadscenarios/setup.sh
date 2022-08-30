export USER_DEVELOPER_DISPLAY_NAME='developer'
export USER_DEVELOPER_UPN='developer@ricardomachado.net'
read -s -p "Password: "
az ad user create --display-name $USER_DEVELOPER_DISPLAY_NAME --user-principal-name $USER_DEVELOPER_UPN --password $REPLY
unset REPLY

export USER_DEVELOPER_ID=$(az ad user list --upn $USER_DEVELOPER_UPN -o tsv --query [0].id)