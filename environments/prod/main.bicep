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

// ==========================================
// 1. Data-Driven Management Groups Deployment
// ==========================================

@description('Array of management groups defining the organizational hierarchy')
param managementGroups array = [
  {
    name: 'mg-contoso-us'
    displayName: 'Contoso US Organization Root'
    parentMgId: '/providers/Microsoft.Management/managementGroups/${tenant().tenantId}'
  }
  {
    name: 'mg-contoso-us-landingzones'
    displayName: 'Contoso US Landing Zones'
    parentMgId: '/providers/Microsoft.Management/managementGroups/mg-contoso-us'
  }
  {
    name: 'mg-contoso-us-corp'
    displayName: 'Contoso US Corp'
    parentMgId: '/providers/Microsoft.Management/managementGroups/mg-contoso-us-landingzones'
  }
  {
    name: 'mg-contoso-us-online'
    displayName: 'Contoso US Online'
    parentMgId: '/providers/Microsoft.Management/managementGroups/mg-contoso-us-landingzones'
  }
  {
    name: 'mg-contoso-us-platform'
    displayName: 'Contoso US Platform'
    parentMgId: '/providers/Microsoft.Management/managementGroups/mg-contoso-us'
  }
  {
    name: 'mg-contoso-us-connectivity'
    displayName: 'Contoso US Connectivity'
    parentMgId: '/providers/Microsoft.Management/managementGroups/mg-contoso-us-platform'
  }
  {
    name: 'mg-contoso-us-identity'
    displayName: 'Contoso US Identity'
    parentMgId: '/providers/Microsoft.Management/managementGroups/mg-contoso-us-platform'
  }
  {
    name: 'mg-contoso-us-management'
    displayName: 'Contoso US Management'
    parentMgId: '/providers/Microsoft.Management/managementGroups/mg-contoso-us-platform'
  }
]

module managementGroupsModule '../../modules/management-groups/managementGroup.bicep' = [for mg in managementGroups: {
  name: 'deploy-${mg.name}'
  params: {
    mgName: mg.name
    mgDisplayName: mg.displayName
    parentMgId: mg.parentMgId
  }
}]

// ==========================================
// 2. Governance & Compliance Layer 
// ==========================================

module geoComplianceInitiative '../../modules/governance/geoComplianceInitiative.bicep' = {
  name: 'deploy-geo-compliance-initiative'
  scope: managementGroup('mg-contoso-us')
  params: {
    allowedLocations: allowedLocations
    effect: 'Deny'
  }
  dependsOn: [managementGroupsModule]
}

module taggingInitiative '../../modules/governance/taggingInitiative.bicep' = {
  name: 'deploy-tagging-initiative'
  scope: managementGroup('mg-contoso-us')
  params: {
    requiredTags: requiredTags
  }
  dependsOn: [managementGroupsModule]
}

module securityBenchmarkAssignment '../../modules/governance/microsoftCloudSecurityBenchmark.bicep' = {
  name: 'deploy-security-benchmark-assignment'
  scope: managementGroup('mg-contoso-us')
  dependsOn: [managementGroupsModule]
}

// ==========================================
// 3. Data-Driven Subscription Associations
// ==========================================

@description('Array mapping target management groups to their respective subscription IDs')
param subscriptionAssociations array = [
  {
    mgName: 'mg-contoso-us-corp'
    subscriptionIds: corpSubscriptionIds
  }
  {
    mgName: 'mg-contoso-us-online'
    subscriptionIds: onlineSubscriptionIds
  }
  {
    mgName: 'mg-contoso-us-connectivity'
    subscriptionIds: connectivitySubscriptionIds
  }
  {
    mgName: 'mg-contoso-us-identity'
    subscriptionIds: identitySubscriptionIds
  }
  {
    mgName: 'mg-contoso-us-management'
    subscriptionIds: managementSubscriptionIds
  }
]

module subscriptionAssociationsModule '../../modules/management-groups/subscriptionAssociation.bicep' = [for assoc in subscriptionAssociations: if (!empty(assoc.subscriptionIds)) {
  name: 'deploy-${assoc.mgName}-sub-assoc'
  params: {
    managementGroupId: '/providers/Microsoft.Management/managementGroups/${assoc.mgName}'
    subscriptionIds: assoc.subscriptionIds
  }
  dependsOn: [
    managementGroupsModule
    geoComplianceInitiative
  ]
}]
