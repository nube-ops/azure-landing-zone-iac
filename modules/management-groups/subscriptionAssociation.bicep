targetScope = 'tenant'

@description('Resource ID of the target Management Group')
param managementGroupId string

@description('Array of subscription IDs to associate with the Management Group')
param subscriptionIds array

// Loop through each subscription ID and associate it with the target management group
resource subscriptionAssociation 'Microsoft.Management/managementGroups/subscriptions@2023-04-01' = [for subscriptionId in subscriptionIds: {
  // Setting the name as 'managementGroupName/subscriptionId' moves the subscription
  name: '${last(split(managementGroupId, '/'))}/${subscriptionId}'
  scope: tenant()
}]
