targetScope = 'managementGroup'

@description('A short, human-readable slug for the policy assignment resource name (Max 10 chars recommended)')
param policyNameSlug string

@description('The fully qualified ID of the Azure Policy definition or initiative definition')
param policyDefinitionId string

@description('The display name of the policy assignment')
param policyDisplayName string

@description('The description of the policy assignment')
param policyDescription string

@description('Optional scope flag for unique string generation')
param scopeTypeFlag string = 'mg'

@description('Parameter values for the policy assignment rule evaluation')
param policyParameters object = {}

@description('Enforcement effect or mode for the policy assignment')
param enforcementEffect string = 'Deny'

// Defensive Engineering: Guarantee 10-char max slug prefix so the 13-char uniqueString hash is never truncated
var safeSlug = take(policyNameSlug, 10)
var assignmentHash = uniqueString(policyDefinitionId, scopeTypeFlag)
var assignmentName = take('${safeSlug}-${assignmentHash}', 24)

// The policy assignment name length must not exceed '24' characters.
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: assignmentName
  properties: {
    displayName: policyDisplayName
    description: policyDescription
    policyDefinitionId: policyDefinitionId
    parameters: !empty(policyParameters) ? policyParameters : null
    enforcementMode: enforcementEffect == 'Deny' ? 'Default' : 'DoNotEnforce'
    nonComplianceMessages: [
      {
        message: 'Resource violates organizational governance baseline: ${policyDisplayName}'
      }
    ]
  }
}

output policyAssignmentId string = policyAssignment.id
