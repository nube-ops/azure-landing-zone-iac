targetScope = 'tenant'

@description('Name of the Management Group ID')
param mgName string

@description('Friendly display name of the Management Group')
param mgDisplayName string

@description('Resource ID of the parent Management Group')
param parentMgId string

resource managementGroup 'Microsoft.Management/managementGroups@2024-02-01-preview' = {
  name: mgName
  properties: {
    displayName: mgDisplayName
    details: {
      parent: {
        id: parentMgId
      }
    }
  }
}

output mgId string = managementGroup.id
