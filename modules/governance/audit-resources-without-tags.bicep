targetScope = 'managementGroup'

@description('Name of the custom policy definition.')
param policyDefinitionName string = 'audit-resources-without-tags'

@description('Display name for the custom policy definition.')
param policyDisplayName string = 'Audit resources missing a required tag'

@description('Description for the custom policy definition.')
param policyDescription string = 'Audits resources that do not contain the required tag.'

resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: policyDefinitionName
  properties: {
    displayName: policyDisplayName
    description: policyDescription
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'Tags'
      version: '1.0.0'
    }
    policyRule: {
      if: {
        field: 'tags'
        exists: 'false'
      }
      then: {
        effect: 'audit'
      }
    }
  }
}

output policyDefinitionId string = policyDefinition.id
