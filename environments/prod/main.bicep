targetScope = 'tenant'

// ==========================================
// Parameters (Pure Schema - Zero Hardcoded Data)
// ==========================================

// 1. Global & Regional Baseline
@description('Enterprise regions configuration mapping locations to short codes and primary/failover roles')
param regionalConfig array

// 2. Management Group Topology & Scoping
@description('Organization name for resource naming')
param orgName string

@description('Deployment region code')
param deploymentRegion string

@description('Array of management groups defining the organizational hierarchy')
param managementGroups array

var rootMgName = 'mg-${orgName}-${deploymentRegion}'
var rootManagementGroupName = rootMgName

// 3. Governance & Security Policy Inputs
@description('Mandatory tags to enforce across all child subscriptions')
param requiredTags array

@description('List of resource types explicitly disallowed by enterprise security baselines')
param disallowedResourceTypes array

@description('Enforcement mode for the Microsoft Cloud Security Benchmark')
@allowed([
  'Default'
  'DoNotEnforce'
])
param securityBenchmarkEnforcementMode string = 'DoNotEnforce'

@description('Array of policy exemptions for scoped operational exceptions')
param policyExemptions array = []

// 4. Subscription Workload Associations
@description('Array mapping target management groups to their respective subscription IDs')
param subscriptionAssociations array

// ==========================================
// 1. Data-Driven Management Groups Deployment
// ==========================================

// A. Deploy Root Management Group first
module rootManagementGroup '../../modules/management-groups/managementGroup.bicep' = {
  name: 'deploy-${rootMgName}'
  params: {
    mgName: rootMgName
    mgDisplayName: '${toUpper(orgName)} ${toUpper(deploymentRegion)} Organization Root'
    parentMgId: ''
  }
}

// B. Deploy Child Management Groups depending explicitly on the Root
module childManagementGroupsModule '../../modules/management-groups/managementGroup.bicep' = [for mg in managementGroups: if (mg.name != rootMgName) {
  name: 'deploy-${mg.name}'
  params: {
    mgName: mg.name
    mgDisplayName: mg.displayName
    parentMgId: mg.parentMgId
  }
  dependsOn: [
    rootManagementGroup
  ]
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
  dependsOn: [childManagementGroupsModule]
}

module taggingInitiative '../../modules/governance/tagging-initiative.bicep' = {
  name: 'deploy-tagging-initiative'
  scope: managementGroup(rootManagementGroupName)
  params: {
    requiredTags: requiredTags
  }
  dependsOn: [childManagementGroupsModule]
}

module securityBenchmarkAssignment '../../modules/governance/microsoft-cloud-security-benchmark.bicep' = {
  name: 'deploy-security-benchmark-assignment'
  scope: managementGroup(rootManagementGroupName)
  params: {
    enforcementMode: securityBenchmarkEnforcementMode
  }
  dependsOn: [childManagementGroupsModule]
}

module storageInitiative '../../modules/governance/storage-hardening.bicep' = {
  name: 'deploy-storage-access-hardening-initiative'
  scope: managementGroup(rootManagementGroupName)
  params: {
    disallowedResourceTypes: disallowedResourceTypes
  }
  dependsOn: [childManagementGroupsModule]
}

module auditResourcesWithoutTags '../../modules/governance/audit-resources-without-tags.bicep' = {
  name: 'deploy-audit-resources-without-tags'
  scope: managementGroup(rootManagementGroupName)
  dependsOn: [childManagementGroupsModule]
}

// ==========================================
// 3. Data-Driven Policy Exemptions Layer
// ==========================================

module policyExemptionsModule '../../modules/governance/policy-exemption.bicep' = [for exemption in policyExemptions: {
  name: 'deploy-${exemption.name}'
  scope: subscription(exemption.subscriptionId)
  params: {
    exemptionName: exemption.name
    displayName: exemption.displayName
    exemptionDescription: exemption.description
    exemptionCategory: exemption.exemptionCategory
    policyAssignmentId: exemption.policyAssignmentId
  }
  dependsOn: [
    storageInitiative
    securityBenchmarkAssignment
  ]
}]

// ==========================================
// 4. Subscription Workload Associations
// ==========================================

module subscriptionAssociationsModule '../../modules/management-groups/subscriptionAssociation.bicep' = [for assoc in subscriptionAssociations: if (!empty(assoc.subscriptionIds)) {
  name: 'deploy-${assoc.mgName}-sub-assoc'
  params: {
    managementGroupId: '/providers/Microsoft.Management/managementGroups/${assoc.mgName}'
    subscriptionIds: assoc.subscriptionIds
  }
  dependsOn: [
    childManagementGroupsModule
  ]
}]
