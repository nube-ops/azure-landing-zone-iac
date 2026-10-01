targetScope = 'tenant'

// ==========================================
// Parameters (Pure Schema - Zero Hardcoded Data)
// ==========================================

@description('Enterprise regions configuration mapping locations to short codes and primary/failover roles')
param regionalConfig array

@description('Mandatory tags to enforce across all child subscriptions')
param requiredTags array

@description('List of resource types explicitly disallowed by enterprise security baselines')
param disallowedResourceTypes array

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

module geoComplianceInitiative '../../modules/governance/geo-compliance-initiative.bicep' = {
  name: 'deploy-geo-compliance-initiative'
  scope: managementGroup(rootManagementGroupName)
  params: {
    allowedLocations: [for region in regionalConfig: region.location]
    effect: 'Deny'
  }
  dependsOn: [managementGroupsModule]
}

module taggingInitiative '../../modules/governance/tagging-initiative.bicep' = {
  name: 'deploy-tagging-initiative'
  scope: managementGroup(rootManagementGroupName)
  params: {
    requiredTags: requiredTags
  }
  dependsOn: [managementGroupsModule]
}

module securityBenchmarkAssignment '../../modules/governance/microsoft-cloud-security-benchmark.bicep' = {
  name: 'deploy-security-benchmark-assignment'
  scope: managementGroup(rootManagementGroupName)
  dependsOn: [managementGroupsModule]
}

module storageInitiative '../../modules/governance/storage-hardening.bicep' = {
  name: 'deploy-storage-access-hardening-initiative'
  scope: managementGroup(rootManagementGroupName)
  params: {
    disallowedResourceTypes: disallowedResourceTypes
  }
  dependsOn: [managementGroupsModule]
}

module auditResourcesWithoutTags '../../modules/governance/audit-resources-without-tags.bicep' = {
  name: 'deploy-audit-resources-without-tags'
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
    geo-complianceInitiative
  ]
}]
