Azure Enterprise-Scale Landing Zone (Bicep & PowerShell Automation)

This repository contains a production-grade, modular Infrastructure as Code (IaC) implementation of the Microsoft Cloud Adoption Framework (CAF) Enterprise-Scale Architecture using Azure Bicep, supported by robust PowerShell automation for secure CI/CD bootstrapping.  

Designed for tenant-level deployments, this codebase automates enterprise governance, management group hierarchies, identity foundations, and subscription associations securely and repeatably.

🏗️ Architecture Topology
The deployment establishes a hierarchical Management Group structure rooted at the tenant level, separating platform governance from application landing zones-

Tenant Root Group
└── mg-contoso-us (Organization Root)
    ├── mg-contoso-us-platform
    │   ├── mg-contoso-us-connectivity
    │   │   └── sub-contoso-us-connectivity (Subscription)
    │   │       ├── rg-net-hub-prod-cus-01        # Core Hub VNet, Azure Firewall, VPN Gateways
    │   │       └── rg-net-telemetry-prod-cus-01  # Network Analytics, Flow Logs, & Traffic Insights
    │   ├── mg-contoso-us-identity
    │   │   └── sub-contoso-us-identity (Subscription)
    │   │       ├── rg-core-identity-cus-01       # Core Domain Controllers & Directory Sync
    │   │       └── rg-mgmt-identity-cus-01       # CI/CD Bootstrap, UMI, & OIDC Trust Foundation
    │   └── mg-contoso-us-management
    │       └── sub-contoso-us-management (Subscription)
    │           └── rg-mgmt-logs-prod-cus-01      # Central Log Analytics, Automation, & Monitor Dashboards
    └── mg-contoso-us-landingzones
        ├── mg-contoso-us-corp
        │   └── sub-contoso-us-corp (Subscription)
        │       ├── rg-corp-workloads-prod-cus-01 # Internal Line-of-Business Application Workloads
        │       └── rg-corp-data-prod-cus-01      # Backend Databases & Persistent Storage Tiers
        └── mg-contoso-us-online
            └── sub-contoso-us-online (Subscription)
                ├── rg-online-web-prod-cus-01     # Public-Facing Web Apps & Microservices
                └── rg-online-edge-prod-cus-01    # Application Gateways, CDNs, & Front-End Routing

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
Step 1: Run the Bootstrap Script (Identity & OIDC Setup)
Before running Bicep deployments from GitHub Actions, execute the idempotent bootstrap script locally. This auto-discovers your subscription and git remote context, provisions the deployment resource group (rg-mgmt-identity-cus-01), creates a User-Assigned Managed Identity, configures GitHub OIDC federation, and assigns the necessary Management Group Contributor role at the tenant root.

cd scripts/bootstrap
.\New-ContosoManagementGroupDeployer.ps1

Note: Store the output values (AZURE_CLIENT_ID, AZURE_TENANT_ID, TENANT_ROOT_MANAGEMENT_GROUP_ID) as GitHub Environment secrets.

Step 2: Configure Parameters for Bicep Deployment
Navigate to the production environment directory and configure your subscription parameter file:

Step 3: Execute the Infrastructure DeploymentBecause this template deploys resources at the tenant scope, deployments must be initiated targeting the tenant level rather than a specific subscription or resource group.  Bashaz deployment tenant create \
  --name "deploy-caf-root-structure" \
  --location "centralus" \
  --template-file main.bicep \
  --parameters main.bicepparam
🔒 Security & Best PracticesZero Hardcoded Secrets: All environment-specific subscription IDs, client IDs, and names are injected dynamically via parameters or parameter files.  Idempotent Automation: PowerShell bootstrap scripts utilize defensive, state-aware checking to ensure safe, repeatable multi-run execution without manual state cleanup.Secure CI/CD Authentication: Avoids long-lived client secrets by leveraging GitHub OIDC Federated Credentials for secure, token-based cloud deployment.Modularization: Reusable modules decouple logic from configuration, minimizing code duplication and reducing human error.  Least Privilege: Follows CAF guidelines for separating management concerns into dedicated administrative boundaries.  