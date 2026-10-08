targetScope = 'managementGroup'

@description('Name of the policy assignment (Max 24 characters for Azure Policy Assignment names)')
@maxLength(24)
param policyAssignmentName string = 'mcsb-assignment'

@description('Enforcement mode: Default audits/denies or DoNotEnforce tests without action')
@allowed([
  'Default'
  'DoNotEnforce'
])
param enforcementMode string = 'DoNotEnforce'

// Assign the built-in Microsoft Cloud Security Benchmark initiative at the management group scope
resource securityBenchmarkAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: policyAssignmentName
  properties: {
    displayName: 'Microsoft cloud security benchmark'
    description: 'Automatically toggle on the built-in security benchmark at the root management group scope.'
    policyDefinitionId: '/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8'
    enforcementMode: enforcementMode
  }
}
