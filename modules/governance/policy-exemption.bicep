targetScope = 'subscription'

@description('Name of the policy exemption resource')
param exemptionName string

@description('Display name of the policy exemption')
param displayName string

@description('Detailed description of why this exemption is granted')
param exemptionDescription string

@description('Exemption category determining behavior')
@allowed([
  'Waiver'
  'Mitigated'
])
param exemptionCategory string

@description('Fully qualified resource ID of the policy assignment being exempted')
param policyAssignmentId string

resource policyExemption 'Microsoft.Authorization/policyExemptions@2024-04-01' = {
  name: exemptionName
  properties: {
    displayName: displayName
    description: exemptionDescription
    exemptionCategory: exemptionCategory
    policyAssignmentId: policyAssignmentId
  }
}

output exemptionId string = policyExemption.id
