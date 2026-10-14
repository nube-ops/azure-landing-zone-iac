targetScope = 'subscription'

param location string = deployment().location
param orgName string
param environment string

// Reusable module call adhering to DRY and CAF standards
module connectivityRg '../../modules/networking/resource-group.bicep' = {
  name: 'deploy-connectivity-rg'
  params: {
    resourceGroupName: 'rg-net-hub-${environment}-${orgName}-01'
    location: location
    tags: {
      environment: environment
      domain: 'connectivity'
    }
  }
}

output connectivityResourceGroupName string = connectivityRg.outputs.name
