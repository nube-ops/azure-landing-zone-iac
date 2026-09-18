targetScope = 'managementGroup'

@description('Custom policy definition resource ID.')
param policyDefinitionId string

@description('Unique name for the policy assignment.')
param assignmentName string = 'audit-required-tag'

@description('Display name for the policy assignment.')
param assignmentDisplayName string = 'Audit resources missing a required tag'

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: assignmentName
  properties: {
    displayName: assignmentDisplayName
    description: 'Audits resources that do not contain the required tag.'
    policyDefinitionId: policyDefinitionId
  }
}

output policyAssignmentId string = policyAssignment.id
