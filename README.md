Azure Enterprise-Scale Landing Zone (Bicep)
This repository contains a production-grade, modular Infrastructure as Code (IaC) implementation of the Microsoft Cloud Adoption Framework (CAF) Enterprise-Scale Architecture using Azure Bicep.

Designed for tenant-level deployments, this codebase automates enterprise governance, management group hierarchies, and subscription associations securely and repeatably.

🏗️ Architecture Topology
The deployment establishes a hierarchical Management Group structure rooted at the tenant level, separating platform governance from application landing zones:

Tenant Root Group
└── mg-contoso-us (Organization Root)
    ├── mg-contoso-us-platform
    │   ├── mg-contoso-us-connectivity
    │   ├── mg-contoso-us-identity
    │   └── mg-contoso-us-management
    └── mg-contoso-us-landingzones
        ├── mg-contoso-us-corp
        └── mg-contoso-us-online

📁 Repository Structure

azure-landing-zone-iac/
│
├── .github/workflows/          # CI/CD pipelines (Linting & Deployment)
├── live/
│   └── prod/
│       ├── main.bicep          # Tenant-level entry point orchestration
│       ├── main.bicepparam     # Parameter file for production environment
│       └── main.bicepparam.example # Template parameter reference
├── modules/
│   ├── key-vault/              # Key Vault deployment modules
│   ├── landing-zones/          # Landing zone specific configurations
│   ├── management-groups/      # Reusable management group & association modules
│   └── policies/               # Azure Policy definitions and assignments
├── .gitignore
└── README.md

⚙️ Prerequisites

Before executing this deployment, ensure you have the following permissions and tools configured:
Permissions:
Tenant Root Group Owner or User Access Administrator permissions at the Azure AD Tenant root scope (/) to create top-level Management Groups.

Tools:
Azure CLI (v2.20.0 or higher)
Bicep CLI ( installed automatically with recent Azure CLI versions)

🚀 Deployment Instructions
Because this template deploys resources at the tenant scope, deployments must be initiated targeting the tenant level rather than a specific subscription or resource group.

1. Clone the Repository
*git clone https://github.com/your-username/azure-landing-zone-iac.git
cd azure-landing-zone-iac/live/prod

2. Authenticate to Azure
az login

3. Configure Parameters
*Copy the example parameter file and populate your target subscription IDs:
*main.bicepparam to include your specific subscription IDs for Connectivity, Identity, Management, Corp, and Online workloads.
cp main.bicepparam.example main.bicepparam

4. Execute the Deployment
*Run the deployment command targeting the tenant scope:
az deployment tenant create \
  --name "deploy-caf-root-structure" \
  --location "eastus" \
  --template-file main.bicep \
  --parameters main.bicepparam

🔒 Security & Best Practices
*Zero Hardcoded Secrets: All environment-specific subscription IDs and names are injected via parameters or parameter files.
*Modularization: Reusable modules decouple logic from configuration, minimizing code duplication and reducing human error.
*Least Privilege: Follows CAF guidelines for separating management concerns into dedicated administrative boundaries.

