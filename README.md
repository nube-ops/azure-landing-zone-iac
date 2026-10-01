Azure Enterprise-Scale Landing Zone (Bicep & PowerShell Automation)

This repository contains a production-grade, modular Infrastructure as Code (IaC) implementation of the Microsoft Cloud Adoption Framework (CAF) Enterprise-Scale Architecture using Azure Bicep, supported by robust PowerShell automation for secure CI/CD bootstrapping.  

Designed for tenant-level deployments, this codebase automates enterprise governance, management group hierarchies, identity foundations, and subscription associations securely and repeatably.

🏗️ Architecture Topology
The deployment establishes a hierarchical Management Group structure rooted at the tenant level, separating platform governance from application landing zones-
```text
Tenant Root Group 
 ├── mg-contoso-us (Organization Root)
 │    ├── mg-contoso-us-platform
 │    │    ├── mg-contoso-us-connectivity (Subscription)
 │    │    │    └── rg-net-hub-prod-cus-01 # Core Hub VNet, Azure Firewall, VPN Gateways
 │    │    ├── mg-contoso-us-identity (Subscription)
 │    │    │    ├── rg-core-identity-cus-01 # Core Domain Controllers & Directory Sync
 │    │    │    └── rg-mgmt-identity-cus-01 # CI/CD Bootstrap, UMI, & OIDC Trust Foundation
 │    │    └── mg-contoso-us-management (Subscription)
 │    │         └── rg-mgmt-logs-prod-cus-01 # Central Log Analytics, Automation, & Monitor Dashboards
 │    └── mg-contoso-us-landingzones
 │         ├── mg-contoso-us-corp (Subscription)
 │         │    ├── rg-corp-workloads-prod-cus-01 # Internal Line-of-Business Application Workloads
 │         │    └── rg-corp-data-prod-cus-01 # Backend Databases & Persistent Storage Tiers
 │         └── mg-contoso-us-online (Subscription)
 │              ├── rg-online-web-prod-cus-01 # Public-Facing Web Apps & Microservices
 │              └── rg-online-edge-prod-cus-01 # Application Gateways, CDNs, & Front-End Routing
```
📁 Repository Structure
Configuration Management: Fully DRY parameterization allows enterprise deployment naming and hierarchy trees to be dynamically synthesized from a single orgName variable declaration inside main.bicepparam.
```text
azure-landing-zone-iac/
│
├── .github/
│   └── workflows/              # CI/CD pipelines (Deployment automation)
├── environments/               # Environment-specific orchestrations
│   ├── dev/
│   └── prod/
│       ├── main.bicep          # Tenant-level entry point orchestration
│       ├── main.bicepparam     # Production parameter file
│       └── main.bicepparam.example   # Template parameter reference
├── modules/                    # Reusable, DRY Bicep modules
│   ├── governance/             # Compliance, security benchmarks, policies, & tagging
│   ├── key-vault/              # Key Vault deployment modules
│   ├── landing-zones/          # Landing zone specific configurations
│   └── management-groups/      # Reusable management group & subscription association modules
├── scripts/
│   └── bootstrap/
│       └── Initialize-OidcBootstrap.ps1 # Idempotent OIDC & automated secret sync script
├── .gitignore
└── README.md
```

⚙️ Prerequisites
Before executing this deployment, ensure you have the following permissions and tools configured:

Permissions:
-Tenant Root Group Owner or User Access Administrator permissions at the Azure AD Tenant root scope (/) to create top-level Management Groups.

Tools:
* Azure CLI (v2.20.0 or higher)
* GitHub CLI (gh) for automated secret synchronization and developer authentication  
* Bicep CLI (installed automatically with recent Azure CLI versions)  

🚀 Deployment Instructions
Step 1: Configure Primary Region & Run the Bootstrap Script
1. Ensure your primary region is designated with `isPrimary: true` in your environment parameters file (`environments/prod/main.bicepparam`).
2. Execute the zero-touch, highly secure, and idempotent bootstrap script locally from your repository root:
```powershell
.\scripts\bootstrap\Initialize-OidcBootstrap.ps1
```
**What this enhanced script automates:**
* **Dynamic Bicepparam Integration (DRY Architecture):** Programmatically reads your environment's parameter file (`environments/prod/main.bicepparam`), isolating the configuration block where `isPrimary: true` is declared to automatically derive target regions and resource naming conventions (such as location and region codes) without hardcoded duplication.
* **Automated Preflight Diagnostics:** Validates active Azure CLI (`az`) and GitHub CLI (`gh`) sessions upfront, failing fast with precise remediation instructions if missing.
* **Intelligent Context Auto-Discovery:** Dynamically detects your active Azure Subscription ID, Tenant ID, and local Git remote metadata (Owner/Repository) seamlessly.
* **Resilient Transient Error Handling:** Built using a reusable retry wrapper helper function (`Invoke-WithRetry`) to gracefully ride out cloud and API network blips.
* **Advanced Security & Modern OIDC Federation:** Resolves immutable GitHub user and repository numeric IDs via the GitHub API to configure secure OpenID Connect (OIDC) federated credentials (`api://AzureADTokenExchange`), preventing common deployment authentication failures (`AADSTS700213`).
* **Idempotent Tenant Root RBAC & Upsert Architecture:** Safely checks for and provisions required resources (Resource Groups, User-Assigned Managed Identities, OIDC credentials, and tenant-root least-privilege role assignments) to ensure that once executed, the deployment principal is fully authorized to orchestrate the downstream management group hierarchy and governance policies.
* **Automated Secret Syncing (Zero-Touch CI/CD):** Authenticates via the GitHub CLI to automatically push required configuration secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `TENANT_ROOT_MANAGEMENT_GROUP_ID`) straight into your GitHub repository settings.
* **Live Visual Verification:** Outputs formatted tabular Azure resource verifications and active repository secret lists upon completion for transparent auditing.

Step 2: Configure Parameters for Bicep Deployment
Navigate to the production environment directory and configure your subscription parameter file:

Step 3:

🔒 Security & Best Practices
* Zero Hardcoded Secrets: All environment-specific subscription IDs, client IDs, and names are injected dynamically via parameters or parameter files.
* Idempotent Automation: PowerShell bootstrap scripts utilize defensive, state-aware checking to ensure safe, repeatable multi-run execution without manual state cleanup.
* Secure CI/CD Authentication: Avoids long-lived client secrets by leveraging GitHub OIDC Federated Credentials for secure, token-based cloud deployment.
* Modularization ("Don't Repeat Yourself"): Reusable modules decouple logic from configuration, minimizing code duplication and reducing human error.
* Least Privilege: Follows CAF guidelines for separating management concerns into dedicated administrative boundaries.