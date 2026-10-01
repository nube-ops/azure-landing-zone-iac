targetScope = 'managementGroup'

@description('Display name of the security hardening policy set definition.')
param initiativeDisplayName string = 'Storage-Access-Hardening'

@description('Description of the security hardening initiative.')
param initiativeDescription string = 'Enforces enterprise-wide security hardening baselines by proactively blocking high-risk configurations, including public storage access and restricted resource types across all child management groups and subscriptions.'

@description('List of resource types that are explicitly disallowed by the security baseline.')
param disallowedResourceTypes array = [
  'Microsoft.Network/publicIPAddresses'
]

resource storageAccessHardeningInitiative 'Microsoft.Authorization/policySetDefinitions@2023-04-01' = {
  name: 'storage-access-hardening'
  properties: {
    displayName: initiativeDisplayName
    description: initiativeDescription
    policyType: 'Custom'
    metadata: {
      category: 'Security Center'
    }
    policyDefinitions: [
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/4fa4b6c0-31ca-4c0d-b10d-24b96f62a751'
        policyDefinitionReferenceId: 'Storage_account_public_access_disallowed'
        definitionVersion: '3.1.*'
      }
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/6c112d4e-5bc7-47ae-a041-ea2d9dccd749'
        policyDefinitionReferenceId: 'Not_allowed_resource_types'
        definitionVersion: '2.0.*'
        parameters: {
          listOfResourceTypesNotAllowed: {
            value: disallowedResourceTypes
          }
        }
      }
    ]
  }
}

output initiativeId string = storageAccessHardeningInitiative.id
