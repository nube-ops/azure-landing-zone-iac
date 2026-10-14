# 1. Create the Microsoft Entra ID Security Group for the Networking Team
$groupName = "SG-Platform-Networking-Admins"
$groupId = (az ad group create --display-name $groupName --mail-nickname "net-platform-admins" --query id -o tsv)

# 2. Get the Subscription ID for Connectivity
$subId = (az account subscription list --query "[?contains(name, 'connectivity')].id" -o tsv)

# 3. Assign Network Contributor RBAC at the Subscription Scope (Control Plane)
az role assignment create `
    --role "Network Contributor" `
    --assignee-object-id $groupId `
    --assignee-principal-type Group `
    --scope "/subscriptions/$subId"