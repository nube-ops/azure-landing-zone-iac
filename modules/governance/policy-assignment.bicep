targetScope = 'managementGroup'

@description('The fully qualified ID of the Azure Policy definition or initiative definition')
param policyDefinitionId string

@description('The display name of the policy assignment')
param policyDisplayName string

@description('The description of the policy assignment')
param policyDescription string

@description('Parameter values for the policy assignment rule evaluation')
param policyParameters object = {}

@description('Enforcement effect or mode for the policy assignment')
param enforcementEffect string = 'Deny'

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: uniqueString(policyDefinitionId, scopeTypeFlag ?? 'mg')
  displayName: policyDisplayName
  description: policyDescription
  properties: {
    policyDefinitionId: policyDefinitionId
    parameters: notEmpty(policyParameters) ? policyParameters : null
    nonComplianceMessages: [
      {
        message: 'Resource violates organizational governance baseline: ${policyDisplayName}'
      }
    ]
  }
}

output policyAssignmentId string = policyAssignment.id
