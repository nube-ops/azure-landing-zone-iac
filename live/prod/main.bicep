targetScope = 'tenant'

// 1. Organization Root
module orgRoot '../../modules/management-groups/managementGroup.bicep' = {
  name: 'deploy-org-root'
  params: {
    mgName: 'mg-nube-us'
    mgDisplayName: 'Nube US Organization Root'
    parentMgId: '/providers/Microsoft.Management/managementGroups/${tenant().tenantId}'
  }
}

// 2. Landing Zones Branch
module landingZones '../../modules/management-groups/managementGroup.bicep' = {
  name: 'deploy-landing-zones'
  params: {
    mgName: 'mg-nube-us-landingzones'
    mgDisplayName: 'Nube US Landing Zones'
    parentMgId: orgRoot.outputs.mgId
  }
}

module corpMg '../../modules/management-groups/managementGroup.bicep' = {
  name: 'deploy-corp'
  params: {
    mgName: 'mg-nube-us-corp'
    mgDisplayName: 'Nube US Corp'
    parentMgId: landingZones.outputs.mgId
  }
}

module onlineMg '../../modules/management-groups/managementGroup.bicep' = {
  name: 'deploy-online'
  params: {
    mgName: 'mg-nube-us-online'
    mgDisplayName: 'Nube US Online'
    parentMgId: landingZones.outputs.mgId
  }
}

// 3. Platform Branch
module platformMg '../../modules/management-groups/managementGroup.bicep' = {
  name: 'deploy-platform'
  params: {
    mgName: 'mg-nube-us-platform'
    mgDisplayName: 'Nube US Platform'
    parentMgId: orgRoot.outputs.mgId
  }
}

module connectivityMg '../../modules/management-groups/managementGroup.bicep' = {
  name: 'deploy-connectivity'
  params: {
    mgName: 'mg-nube-us-connectivity'
    mgDisplayName: 'Nube US Connectivity'
    parentMgId: platformMg.outputs.mgId
  }
}

module identityMg '../../modules/management-groups/managementGroup.bicep' = {
  name: 'deploy-identity'
  params: {
    mgName: 'mg-nube-us-identity'
    mgDisplayName: 'Nube US Identity'
    parentMgId: platformMg.outputs.mgId
  }
}

module managementMg '../../modules/management-groups/managementGroup.bicep' = {
  name: 'deploy-management'
  params: {
    mgName: 'mg-nube-us-management'
    mgDisplayName: 'Nube US Management'
    parentMgId: platformMg.outputs.mgId
  }
}
