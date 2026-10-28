targetScope = 'subscription'

import { resolveTags } from '../../modules/resource-groups/tags.bicep'

param location string = deployment().location
param orgName string
param environment string

// Workload key: must match its entry in workloads.json and its management group suffix.
var workload = 'connectivity'
var tags = resolveTags(loadJsonContent('workloads.json').workloads, workload, environment)

// Reusable module call adhering to DRY and CAF standards
module connectivityRg '../../modules/resource-groups/resourceGroup.bicep' = {
  name: 'deploy-${workload}-rg'
  params: {
    resourceGroupName: 'rg-net-hub-${environment}-${orgName}-01'
    location: location
    tags: tags
  }
}

output connectivityResourceGroupName string = connectivityRg.outputs.name
