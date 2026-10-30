targetScope = 'subscription'

import { rgName } from '../../modules/resource-groups/naming.bicep'   // adjust to your path
import { resolveTags } from '../../modules/resource-groups/tags.bicep'

param environment string
param regionCode string
param location string = deployment().location

var workloads = loadJsonContent('workloads.json').workloads

// rg-ops-deploy-* is NOT declared here: the bootstrap scripts own it,
// because the pipeline needs it to authenticate in the first place.
module logsRg '../../modules/resource-groups/resourceGroup.bicep' = {
  name: 'deploy-ops-logs-rg'
  params: {
    resourceGroupName: rgName('ops', 'logs', environment, regionCode, 1)
    location: location
    tags: resolveTags(workloads, 'operations', environment)
  }
}
