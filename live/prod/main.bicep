targetScope = 'tenant'

// 1. Organization Root
module orgRoot '../../modules/management-groups/managementGroup.bicep' = {
  name: 'deploy-org-root'
  params: {
    mgName: 'mg-contoso-us'
    mgDisplayName: 'Contoso US Organization Root'
    parentMgId: '/providers/Microsoft.Management/managementGroups/${tenant().tenantId}'
  }
}

// 2. Landing Zones Branch
module landingZones '../../modules/management-groups/managementGroup.bicep' = {
  name: 'deploy-landing-zones'
  params: {
    mgName: 'mg-contoso-us-landingzones'
    mgDisplayName: 'Contoso US Landing Zones'
    parentMgId: orgRoot.outputs.mgId
  }
}

module corpMg '../../modules/management-groups/managementGroup.bicep' = {
  name: 'deploy-corp'
  params: {
    mgName: 'mg-contoso-us-corp'
    mgDisplayName: 'Contoso US Corp'
    parentMgId: landingZones.outputs.mgId
  }
}

module onlineMg '../../modules/management-groups/managementGroup.bicep' = {
  name: 'deploy-online'
  params: {
    mgName: 'mg-contoso-us-online'
    mgDisplayName: 'Contoso US Online'
    parentMgId: landingZones.outputs.mgId
  }
}

// 3. Platform Branch
module platformMg '../../modules/management-groups/managementGroup.bicep' = {
  name: 'deploy-platform'
  params: {
    mgName: 'mg-contoso-us-platform'
    mgDisplayName: 'Contoso US Platform'
    parentMgId: orgRoot.outputs.mgId
  }
}

module connectivityMg '../../modules/management-groups/managementGroup.bicep' = {
  name: 'deploy-connectivity'
  params: {
    mgName: 'mg-contoso-us-connectivity'
    mgDisplayName: 'Contoso US Connectivity'
    parentMgId: platformMg.outputs.mgId
  }
}

module identityMg '../../modules/management-groups/managementGroup.bicep' = {
  name: 'deploy-identity'
  params: {
    mgName: 'mg-contoso-us-identity'
    mgDisplayName: 'Contoso US Identity'
    parentMgId: platformMg.outputs.mgId
  }
}

module managementMg '../../modules/management-groups/managementGroup.bicep' = {
  name: 'deploy-management'
  params: {
    mgName: 'mg-contoso-us-management'
    mgDisplayName: 'Contoso US Management'
    parentMgId: platformMg.outputs.mgId
  }
}
