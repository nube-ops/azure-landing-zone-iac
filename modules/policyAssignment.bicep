targetScope = 'managementGroup'

@description('Name or ID of the policy definition or initiative definition')
param policyDefinitionId string

@description('Friendly display name of the policy assignment')
param policyDisplayName string

@description('Description of the policy assignment')
param policyDescription string

@description('Enforcement mode: Default or DoNotEnforce')
@allowed([
  'Default'
  'DoNotEnforce'
])
param enforcementMode string = 'Default'

@description('Optional parameters for the policy assignment')
param parameters object = {}

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
  name: uniqueString(policyDefinitionId, managementGroup().id)
  properties: {
    displayName: policyDisplayName
    description: policyDescription
    policyDefinitionId: policyDefinitionId
    enforcementMode: enforcementMode
    parameters: empty(parameters) ? null : parameters
  }
}

output policyAssignmentId string = policyAssignment.id
