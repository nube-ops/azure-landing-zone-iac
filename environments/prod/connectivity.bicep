targetScope = 'subscription'

import { resolveTags } from '../../modules/resource-groups/tags.bicep'

param location string = deployment().location
param orgName string
param environment string
param regionCode string

// Workload key: must match its entry in workloads.json and its management group suffix.
var workload = 'connectivity'
var tags = resolveTags(loadJsonContent('workloads.json').workloads, workload, environment)

// CAF Standard: rg-<domain>-<function>-<env>-<region>-<nn>
var rgName = 'rg-net-hub-${environment}-${regionCode}-01'

module connectivityRg '../../modules/resource-groups/resourceGroup.bicep' = {
  name: 'deploy-${workload}-rg'
  params: {
    resourceGroupName: rgName
    location: location
    tags: tags
  }
}

output connectivityResourceGroupName string = connectivityRg.outputs.name
