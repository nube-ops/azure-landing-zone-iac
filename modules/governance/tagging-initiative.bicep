targetScope = 'managementGroup'

@description('Display name of the policy set definition (initiative).')
param initiativeDisplayName string = 'Root-Tagging-Initiative'

@description('Description of the tagging initiative.')
param initiativeDescription string = 'Enforces enterprise-wide baseline tag governance across all child subscriptions under the root management group.'

@description('List of tag names to enforce governance on.')
param requiredTags array = [
  'Owner'
  'Environment'
  'CostCenter'
]

// Built-in Policy Definition IDs used across the initiative
var policyRequireOnResources = '/providers/microsoft.authorization/policydefinitions/871b6d14-10aa-478d-b590-94f262ecfa99'
var policyRequireOnResourceGroups = '/providers/microsoft.authorization/policydefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025'
var policyInheritFromResourceGroup = '/providers/microsoft.authorization/policydefinitions/ea3f2387-9b95-492a-a190-fcdc54f7b070'

// 1. Loop through tags in a variable to generate a nested array of policy definitions
var policyDefinitionsList = [
  for tag in requiredTags: [
    {
      policyDefinitionId: policyRequireOnResources
      policyDefinitionReferenceId: 'Require_tag_on_resources_${tag}'
      definitionVersion: '1.0.*'
      parameters: {
        tagName: {
          value: tag
        }
      }
    }
    {
      policyDefinitionId: policyRequireOnResourceGroups
      policyDefinitionReferenceId: 'Require_tag_on_resource_groups_${tag}'
      definitionVersion: '1.0.*'
      parameters: {
        tagName: {
          value: tag
        }
      }
    }
    {
      policyDefinitionId: policyInheritFromResourceGroup
      policyDefinitionReferenceId: 'Inherit_tag_from_rg_${tag}'
      definitionVersion: '1.0.*'
      parameters: {
        tagName: {
          value: tag
        }
      }
    }
  ]
]

resource rootTaggingInitiative 'Microsoft.Authorization/policySetDefinitions@2023-04-01' = {
  name: 'root-tagging-initiative'
  properties: {
    displayName: initiativeDisplayName
    description: initiativeDescription
    policyType: 'Custom'
    metadata: {
      category: 'Tags'
    }
    // 2. Flatten the nested array into a single flat list required by Azure
    policyDefinitions: flatten(policyDefinitionsList)
  }
}

output initiativeId string = rootTaggingInitiative.id
