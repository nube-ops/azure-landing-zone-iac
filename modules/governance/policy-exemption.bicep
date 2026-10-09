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

@description('Optional expiration date for temporal compliance exemptions (ISO 8601 format YYYY-MM-DDThh:mm:ssZ)')
param expiresOn string = ''

resource policyExemption 'Microsoft.Authorization/policyExemptions@2022-07-01-preview' = {
  name: exemptionName
  properties: {
    displayName: displayName
    description: exemptionDescription
    exemptionCategory: exemptionCategory
    policyAssignmentId: policyAssignmentId
    expiresOn: !empty(expiresOn) ? expiresOn : null
  }
}

output exemptionId string = policyExemption.id
