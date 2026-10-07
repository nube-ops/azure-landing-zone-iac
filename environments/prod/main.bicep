targetScope = 'tenant'

// ==========================================
// Parameters (Pure Schema - Zero Hardcoded Data)
// ==========================================

// 1. Global & Regional Baseline
@description('Enterprise regions configuration mapping locations to short codes and primary/failover roles')
param regionalConfig array

// 2. Management Group Topology & Scoping
@description('Name of the organizational root management group for policy scoping')
param rootManagementGroupName string

@description('Array of management groups defining the organizational hierarchy')
param managementGroups array

// 3. Governance & Security Policy Inputs
@description('Mandatory tags to enforce across all child subscriptions')
param requiredTags array

@description('Array of governance policies driven by the universal policy assignment wrapper')
param governancePolicies array

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
var computedAllowedLocations = [for region in regionalConfig: region.location]

module governancePolicyAssignments '../../modules/governance/policy-assignment.bicep' = [for policy in governancePolicies: {
  name: 'deploy-${policy.name}'
  scope: managementGroup(rootManagementGroupName)
  params: {
    policyNameSlug: policy.name
    policyDefinitionId: policy.definitionId
    policyDisplayName: policy.displayName
    policyDescription: policy.description
    // Dynamically injects computed runtime regions for geo-compliance while falling back cleanly
    policyParameters: policy.name == 'geo-compliance-assignment' ? {
      listOfAllowedLocations: {
        value: computedAllowedLocations
      }
    } : (policy.parameters ?? {})
    enforcementEffect: policy.effect
  }
  dependsOn: [managementGroupsModule]
}]

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
    governancePolicyAssignments  // Correctly points to the unified data-driven policy loop
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
    managementGroupsModule
  ]
}]
