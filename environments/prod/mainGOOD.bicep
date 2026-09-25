targetScope = 'tenant'

param connectivitySubscriptionIds array = []
param identitySubscriptionIds array = []
param managementSubscriptionIds array = []
param corpSubscriptionIds array = []
param onlineSubscriptionIds array = []

@description('The list of allowed enterprise regions for resource deployment')
param allowedLocations array = [
  'centralus'
  'eastus2'
]

@description('Mandatory tags to enforce across all child subscriptions')
param requiredTags array = [
  'Owner'
  'Environment'
  'CostCenter'
]

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

// 4. Governance & Compliance Layer (Targeting the Root Management Group Statically)
module geoComplianceInitiative '../../modules/governance/geoComplianceInitiative.bicep' = {
  name: 'deploy-geo-compliance-initiative'
  scope: managementGroup('mg-contoso-us')
  params: {
    allowedLocations: allowedLocations
    effect: 'Deny'
  }
}

module taggingInitiative '../../modules/governance/taggingInitiative.bicep' = {
  name: 'deploy-tagging-initiative'
  scope: managementGroup('mg-contoso-us')
  params: {
    requiredTags: requiredTags
  }
}

module securityBenchmarkAssignment '../../modules/governance/microsoftCloudSecurityBenchmark.bicep' = {
  name: 'deploy-security-benchmark-assignment'
  scope: managementGroup('mg-contoso-us')
}

// 5. Subscription Association
// Landing Zones Branch
module corpSubAssoc '../../modules/management-groups/subscriptionAssociation.bicep' = {
  name: 'deploy-corp-sub-assoc'
  params: {
    managementGroupId: corpMg.outputs.mgId
    subscriptionIds: corpSubscriptionIds
  }
}

module onlineSubAssoc '../../modules/management-groups/subscriptionAssociation.bicep' = {
  name: 'deploy-online-sub-assoc'
  params: {
    managementGroupId: onlineMg.outputs.mgId
    subscriptionIds: onlineSubscriptionIds
  }
}

// Platform Branch
module connectivitySubAssoc '../../modules/management-groups/subscriptionAssociation.bicep' = {
  name: 'deploy-connectivity-sub-assoc'
  params: {
    managementGroupId: connectivityMg.outputs.mgId
    subscriptionIds: connectivitySubscriptionIds
  }
}

module identitySubAssoc '../../modules/management-groups/subscriptionAssociation.bicep' = {
  name: 'deploy-identity-sub-assoc'
  params: {
    managementGroupId: identityMg.outputs.mgId
    subscriptionIds: identitySubscriptionIds
  }
}

module managementSubAssoc '../../modules/management-groups/subscriptionAssociation.bicep' = {
  name: 'deploy-management-sub-assoc'
  params: {
    managementGroupId: managementMg.outputs.mgId
    subscriptionIds: managementSubscriptionIds
  }
}
