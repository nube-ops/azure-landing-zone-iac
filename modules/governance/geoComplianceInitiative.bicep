targetScope = 'managementGroup'

@description('Display name of the geo-compliance policy set definition (initiative).')
param initiativeDisplayName string = 'Root-Geo-Compliance-Initiative'

@description('Description of the geo-compliance initiative.')
param initiativeDescription string = 'Enforces organization-wide geo-compliance and allowed locations for both resources and resource groups.'

@description('The shared list of allowed locations for your enterprise deployment.')
param allowedLocations array = [
  'centralus'
  'eastus2'
]

@description('The policy effect applied when a resource or resource group is created outside allowed regions.')
@allowed([
  'Audit'
  'Deny'
  'Disabled'
])
param effect string = 'Deny'

// Built-in Policy Definition IDs based on the provided schemas
var policyAllowedLocationsId = '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'
var policyAllowedLocationsRgId = '/providers/Microsoft.Authorization/policyDefinitions/e765b5de-1225-4ba3-bd56-1ac6695af988'

resource rootGeoComplianceInitiative 'Microsoft.Authorization/policySetDefinitions@2023-04-01' = {
  name: 'root-geo-compliance-initiative'
  properties: {
    displayName: initiativeDisplayName
    description: initiativeDescription
    policyType: 'Custom'
    metadata: {
      category: 'General'
      version: '1.0.0'
    }
    // Bind both distinct policy rules into a unified, DRY initiative structure
    policyDefinitions: [
      {
        policyDefinitionId: policyAllowedLocationsId
        policyDefinitionReferenceId: 'AllowedLocationsResources'
        definitionVersion: '1.1.0'
        parameters: {
          listOfAllowedLocations: {
            value: allowedLocations
          }
          effect: {
            value: effect
          }
        }
      }
      {
        policyDefinitionId: policyAllowedLocationsRgId
        policyDefinitionReferenceId: 'AllowedLocationsResourceGroups'
        definitionVersion: '1.1.0'
        parameters: {
          listOfAllowedLocations: {
            value: allowedLocations
          }
          effect: {
            value: effect
          }
        }
      }
    ]
  }
}

output initiativeId string = rootGeoComplianceInitiative.id
