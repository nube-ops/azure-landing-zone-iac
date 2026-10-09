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

@description('Geographical scope prefix for organizational tenant hierarchy (e.g., us, amer, global)')
param geoPrefix string

@description('Array of management groups defining the organizational hierarchy')
param managementGroups array

// Dynamic evaluation variables
var rootMgName = 'mg-${orgName}-${geoPrefix}'
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

// 1A. Deploy Root Management Group first
module rootManagementGroup '../../modules/management-groups/managementGroup.bicep' = {
  name: 'module-deploy-${rootMgName}'
  params: {
    mgName: rootMgName
    mgDisplayName: '${toUpper(orgName)} ${toUpper(geoPrefix)} Organization Root'
    parentMgId: ''
  }
}

// 1B. Deploy Child Management Groups depending explicitly on the Root
module level1ManagementGroups '../../modules/management-groups/managementGroup.bicep' = [for mg in managementGroups: if (mg.name != rootMgName && mg.parentMgId == '/providers/Microsoft.Management/managementGroups/${rootMgName}') {
  name: take('deploy-l1-${mg.name}', 64)
  params: {
    mgName: mg.name
    mgDisplayName: mg.displayName
    parentMgId: mg.parentMgId
  }
  dependsOn: [
    rootManagementGroup
  ]
}]

// 1C. Level 2 Leaf Child Groups (corp, online, connectivity, identity, management)
module level2ManagementGroups '../../modules/management-groups/managementGroup.bicep' = [for mg in managementGroups: if (mg.name != rootMgName && mg.parentMgId != '/providers/Microsoft.Management/managementGroups/${rootMgName}') {
  name: take('deploy-l2-${mg.name}', 64)
  params: {
    mgName: mg.name
    mgDisplayName: mg.displayName
    parentMgId: mg.parentMgId
  }
  dependsOn: [
    level1ManagementGroups
  ]
}]

// ==========================================
// 2. Governance & Compliance Layer 
// ==========================================

// Built-in Security Baseline Layer
module securityBenchmarkAssignment '../../modules/governance/cloud-security-benchmark.bicep' = {
  name: 'deploy-security-benchmark-assignment'
  scope: managementGroup(rootManagementGroupName)
  params: {
    enforcementMode: securityBenchmarkEnforcementMode
  }
  dependsOn: [level2ManagementGroups]
}


// A. Custom Policy Set Definitions (Initiative Layer)
module geoComplianceInitiative '../../modules/governance/geo-compliance-initiative.bicep' = {
  name: 'deploy-geo-compliance-initiative'
  scope: managementGroup(rootManagementGroupName)
  params: {
    allowedLocations: [for region in regionalConfig: region.location]
    effect: 'Deny'
  }
  dependsOn: [level2ManagementGroups]
}

module taggingInitiative '../../modules/governance/tagging-initiative.bicep' = {
  name: 'deploy-tagging-initiative'
  scope: managementGroup(rootManagementGroupName)
  params: {
    requiredTags: requiredTags
  }
  dependsOn: [level2ManagementGroups]
}

module storageInitiative '../../modules/governance/storage-hardening.bicep' = {
  name: 'deploy-storage-access-hardening-initiative'
  scope: managementGroup(rootManagementGroupName)
  params: {
    disallowedResourceTypes: disallowedResourceTypes
  }
  dependsOn: [level2ManagementGroups]
}

module auditResourcesWithoutTags '../../modules/governance/audit-resources-without-tags.bicep' = {
  name: 'deploy-audit-resources-without-tags'
  scope: managementGroup(rootManagementGroupName)
  dependsOn: [level2ManagementGroups]
}

// B. Custom Policy Assignments (Scope Enforcement Layer)

module geoComplianceAssignment '../../modules/governance/policy-assignment.bicep' = {
  name: 'deploy-geo-assignment'
  scope: managementGroup(rootManagementGroupName)
  params: {
    policyNameSlug: 'geo-guard'
    policyDefinitionId: geoComplianceInitiative.outputs.initiativeId
    policyDisplayName: 'Enforce Regional Location Restrictions'
    policyDescription: 'Enforces regional location restrictions across management group hierarchy'
  }
}

module taggingAssignment '../../modules/governance/policy-assignment.bicep' = {
  name: 'deploy-tagging-assignment'
  scope: managementGroup(rootManagementGroupName)
  params: {
    policyNameSlug: 'tag-guard'
    policyDefinitionId: taggingInitiative.outputs.initiativeId
    policyDisplayName: 'Enforce Enterprise Tagging Governance'
    policyDescription: 'Enforces enterprise tagging governance across management group hierarchy'
  }
}

module storageInitiativeAssignment '../../modules/governance/policy-assignment.bicep' = {
  name: 'deploy-storage-hardening-assignment'
  scope: managementGroup(rootManagementGroupName)
  params: {
    policyNameSlug: 'stg-harden' // Truncated slug enforces <= 24 character assignment name limit
    policyDefinitionId: storageInitiative.outputs.initiativeId
    policyDisplayName: 'Deploy Storage Access Hardening Policy Set'
    policyDescription: 'Enforces storage hardening baselines across management group hierarchy'
  }
}

module auditResourcesWithoutTagsAssignment '../../modules/governance/policy-assignment.bicep' = {
  name: 'deploy-audit-tags-assignment'
  scope: managementGroup(rootManagementGroupName)
  params: {
    policyNameSlug: 'audit-tags'
    policyDefinitionId: auditResourcesWithoutTags.outputs.policyDefinitionId
    policyDisplayName: 'Audit Resources Missing Mandatory Tags'
    policyDescription: 'Audits all deployed resources that do not satisfy required tag keys'
  }
}

// ==========================================
// 3. Data-Driven Policy Exemptions Layer
// ==========================================
// REMEDIATION: Retain the data-driven DRY loop while ensuring comprehensive governance dependencies.
module policyExemptionsModule '../../modules/governance/policy-exemption.bicep' = [for exemption in policyExemptions: {
  name: take('deploy-${exemption.name}', 64)
  scope: subscription(exemption.subscriptionId)
  params: {
    exemptionName: exemption.name
    displayName: exemption.displayName
    exemptionDescription: exemption.description
    exemptionCategory: exemption.exemptionCategory
    policyAssignmentId: storageInitiativeAssignment.outputs.policyAssignmentId
  }
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
    level2ManagementGroups
  ]
}]
