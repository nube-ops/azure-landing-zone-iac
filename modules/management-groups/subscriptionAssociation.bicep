targetScope = 'tenant'

param managementGroupId string
param subscriptionIds array

// Loop through each subscription ID and associate it with the target management group
resource subscriptionAssociation 'Microsoft.Management/managementGroups/subscriptions@2023-04-01' = [for subscriptionId in subscriptionIds: {
  name: '${managementGroupId}/${subscriptionId}'
  scope: tenant()
}]
