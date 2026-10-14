targetScope = 'subscription'

@description('The name of the resource group to be created.')
param resourceGroupName string

@description('The target Azure region where the resource group will be provisioned.')
param location string

@description('Key-value pairs of tags to apply to the resource group for governance and billing.')
param tags object = {}

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

@description('The name of the deployed resource group.')
output name string = rg.name

@description('The resource ID of the deployed resource group.')
output id string = rg.id
