targetScope = 'tenant'

// ==========================================
// Parameters (Pure Schema - Zero Hardcoded Data)
// ==========================================

param connectivitySubscriptionIds array = []
param identitySubscriptionIds array = []
param managementSubscriptionIds array = []
param corpSubscriptionIds array = []
param onlineSubscriptionIds array = []

@description('Enterprise regions configuration mapping locations to short codes and primary/failover roles')
param regionalConfig array

@description('Mandatory tags to enforce across all child subscriptions')
param requiredTags array

@description('Name of the organizational root management group for policy scoping')
param rootManagementGroupName string

@description('Array of management groups defining the organizational hierarchy')
param managementGroups array

@description('Array mapping target management groups to their respective subscription IDs')
param subscriptionAssociations array

// ==========================================
// 1. Data-Driven Management Groups Deployment
// ==========================================

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
  scope: managementGroup(rootManagementGroupName)
  params: {
    allowedLocations: [for region in regionalConfig: region.location]
    effect: 'Deny'
  }
  dependsOn: [managementGroupsModule]
}

module taggingInitiative '../../modules/governance/taggingInitiative.bicep' = {
  name: 'deploy-tagging-initiative'
  scope: managementGroup(rootManagementGroupName)
  params: {
    requiredTags: requiredTags
  }
  dependsOn: [managementGroupsModule]
}

module securityBenchmarkAssignment '../../modules/governance/microsoftCloudSecurityBenchmark.bicep' = {
  name: 'deploy-security-benchmark-assignment'
  scope: managementGroup(rootManagementGroupName)
  dependsOn: [managementGroupsModule]
}

// ==========================================
// 3. Data-Driven Subscription Associations
// ==========================================

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
