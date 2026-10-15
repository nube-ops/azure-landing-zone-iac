targetScope = 'subscription'

param location string = deployment().location
param orgName string
param environment string

@description('Owner tag value injected dynamically from configuration')
param owner string = 'Platform-Networking-Team'

@description('Cost center tag value injected dynamically from configuration')
param costCenter string = 'cc-1000'

// Reusable module call adhering to DRY and CAF standards
module connectivityRg '../../modules/resource-groups/resourceGroup.bicep' = {
  name: 'deploy-connectivity-rg'
  params: {
    resourceGroupName: 'rg-net-hub-${environment}-${orgName}-01'
    location: location
    tags: {
      Environment: environment
      Owner: owner
      CostCenter: costCenter
      Domain: 'connectivity'
    }
  }
}

output connectivityResourceGroupName string = connectivityRg.outputs.name
