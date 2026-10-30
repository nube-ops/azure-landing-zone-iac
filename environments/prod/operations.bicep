targetScope = 'subscription'

import { rgName } from '../../modules/resource-groups/naming.bicep'

param location string = deployment().location
param environment string
param regionCode string
param owner string
param costCenter string

var domain = 'ops'
var tags = {
  Environment: environment
  Owner: owner
  CostCenter: costCenter
  Domain: 'operations'
}

// NOTE: rg-ops-deploy-prod-cus-01 is intentionally NOT declared here.
// Bootstrap owns it (it hosts the pipeline's identity); the pipeline must never be able to delete it.

var logsRgName = rgName(domain, 'logs', environment, regionCode, 1)

module logsRg '../../modules/resource-groups/resourceGroup.bicep' = {
  name: 'deploy-rg-ops-logs'
  params: {
    resourceGroupName: logsRgName
    location: location
    tags: tags
  }
}

// Add resources here as they become real, e.g.:
// module workspace '../../modules/monitoring/logAnalytics.bicep' = {
//   scope: resourceGroup(logsRgName)
//   dependsOn: [logsRg]
// }
