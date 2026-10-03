### Azure Enterprise-Scale Landing Zone (Bicep & PowerShell Automation)

This repository contains a production-grade, modular Infrastructure as Code (IaC) implementation of the Microsoft Cloud Adoption Framework (CAF) Enterprise-Scale Architecture using Azure Bicep, supported by robust PowerShell automation for secure CI/CD bootstrapping.  

Designed for tenant-level deployments, this codebase automates enterprise governance, management group hierarchies, identity foundations, and subscription associations securely and repeatably.

### 🏗️ Architecture Topology
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
### 📁 Repository Structure
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
│       ├── Initialize-SubscriptionSecrets.ps1  # Idempotent sub discovery & parameter sync
│       └── Initialize-OidcBootstrap.ps1        # Idempotent OIDC & automated secret sync script
├── .gitignore
└── README.md
```

### ⚙️ Prerequisites
Before executing this deployment, ensure you have the following permissions and tools configured:

Permissions:
-Tenant Root Group Owner or User Access Administrator permissions at the Azure AD Tenant root scope (/) to create top-level Management Groups.

Tools:
* Azure CLI (v2.20.0 or higher)
* GitHub CLI (gh) for automated secret synchronization and developer authentication  
* Bicep CLI (installed automatically with recent Azure CLI versions)  

### 🚀 Deployment Instructions
To maintain strict adherence to DRY, Idempotency, and Cloud Governance best practices, follow these sequential phases to bootstrap your enterprise landing zone environment.

### Phase 1: Pre-Provisioning & Subscription Naming Conventions
* Prior to running the bootstrap scripts or deployment pipeline, ensure your target enterprise subscriptions are pre-provisioned within your Azure tenant and that the `main.bicepparam` subscription associations align with your Azure subscription names.
* **Billing & Creation Constraints:** Standard Pay-As-You-Go or personal Azure accounts are typically capped at a maximum of 5 active subscriptions and often throttle rapid programmatic creation (limiting provisioning to one subscription per 24-hour window). For a complete landing zone rollout, ensure these subscriptions are created beforehand via your Azure Portal or enterprise agreement billing profile.
---
| Workload Domain | Required Naming Keyword | Example Subscription Name |
| :--- | :--- | :--- |
| **Connectivity** | `connectivity` | `mg-contoso-us-connectivity` |
| **Corp Landing Zones** | `corp` | `mg-contoso-us-corp` |
| **Online Landing Zones** | `online` | `mg-contoso-us-online` |
| **Identity** | `identity` | `mg-contoso-us-identity` |
| **Management** | `management` | `mg-contoso-us-management` |
---
* **Single Source of Truth (DRY Naming):** Changing `orgName` and `deploymentRegion` at the top of `environments/prod/main.bicepparam` automatically cascades custom naming across all management groups and resource hierarchies. The subscriptionAssociations block at the bottom maps explicit workload domains (such as corp, online, and connectivity), which are then automatically parsed and synchronized with your actual Azure Subscription IDs by the initialization script that .

### Phase 2: Automated Subscription Discovery & Parameter Synchronization
* Once your subscriptions are active, authenticate your CLI tools and run the subscription management script from your repository root:
```powershell
.\scripts\bootstrap\Initialize-SubscriptionSecrets.ps1
```
What Initialize-SubscriptionSecrets.ps1 Accomplishes:
* **Automated Preflight Diagnostics:** Validates active Azure CLI (az) and GitHub CLI (gh) sessions, verifying repository ownership context and failing fast with explicit remediation guides if missing.
* **Intelligent Context Auto-Discovery:** Natively resolves local Git remote repository metadata (Owner and Repository) to target the correct GitHub environment without hardcoded configurations.
* **Tenant Subscription Mapping:** Queries active enterprise Azure subscriptions, filtering dynamically across core workload domains (connectivity, corp, online, identity, management) and validating enabled states.
* **Idempotent Bicepparam Auto-Population (DRY Architecture):** Programmatically parses and injects discovered subscription IDs directly into target arrays within 'main.bicepparam' without manual input.
* **Content-Hash Convergence & Zero-Write Optimization:** Evaluates existing file contents before writing, skipping disk mutations if state is already fully synchronized to prevent unnecessary file lock churn.
* **Structural Diff Auditing:** Employs `git diff --no-index` against a temporary backup to prove isolated parameter modifications and guarantee absolute zero unintended drift.
* **Automated CI/CD Secret Syncing:** Authenticates via the GitHub CLI to securely upsert required workload subscription IDs straight into GitHub Actions repository settings, complete with live audit tables.

### Phase 3: Configure Primary & Multi-Region HA Architecture
* Designate your primary deployment location with `isPrimary: true` in your environment parameters file (`environments/prod/main.bicepparam`), while aligning your secondary region with its Azure-paired region for high availability (HA), disaster recovery (DR) readiness, and automated cross-region policy compliance.
* Execute the zero-touch, highly secure, and idempotent bootstrap script locally from your repository root:
```powershell
.\scripts\bootstrap\Initialize-OidcBootstrap.ps1
```
What Initialize-OidcBootstrap.ps1 Accomplishes:
* **Dynamic Bicepparam Integration (DRY Architecture):** Programmatically reads your environment's parameter file (`environments/prod/main.bicepparam`), isolating the configuration block where `isPrimary: true` is declared to automatically derive target regions and resource naming conventions (such as location and region codes) without hardcoded duplication.
* **Automated Preflight Diagnostics:** Validates active Azure CLI (`az`) and GitHub CLI (`gh`) sessions upfront, failing fast with precise remediation instructions if missing.
* **Intelligent Context Auto-Discovery:** Dynamically detects your active Azure Subscription ID, Tenant ID, and local Git remote metadata (Owner/Repository) with a graceful fallback safety net.
* **Resilient Transient Error Handling:** Built using a reusable retry wrapper helper function (`Invoke-WithRetry`) to gracefully ride out cloud and API network blips.
* **Advanced Security & Modern OIDC Federation:** Resolves immutable GitHub user and repository numeric IDs via the GitHub API to configure secure OpenID Connect (OIDC) federated credentials (`api://AzureADTokenExchange`), preventing common deployment authentication failures (`AADSTS700213`).
* **Idempotent Tenant Root RBAC & Upsert Architecture:** Safely checks for and provisions required resources (Resource Groups, User-Assigned Managed Identities, OIDC credentials, and tenant-root least-privilege role assignments) to ensure secure, repeatable multi-run execution without duplicate resource creation.
* **Automated Secret Syncing (Zero-Touch CI/CD):** Authenticates via the GitHub CLI to automatically push required configuration secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `TENANT_ROOT_MANAGEMENT_GROUP_ID`) straight into your GitHub repository settings.
* **Live Visual Verification:** Outputs formatted tabular Azure resource verifications and active repository secret lists upon completion for transparent auditing.

### Phase 4: resource groups topology in bicep param. can it be dryer?



🔒 Security & Best Practices
* Zero Hardcoded Secrets: All environment-specific subscription IDs, client IDs, and names are injected dynamically via parameters or parameter files.
* Idempotent Automation: PowerShell bootstrap scripts utilize defensive, state-aware checking to ensure safe, repeatable multi-run execution without manual state cleanup.
* Secure CI/CD Authentication: Avoids long-lived client secrets by leveraging GitHub OIDC Federated Credentials for secure, token-based cloud deployment.
* Modularization ("Don't Repeat Yourself"): Reusable modules decouple logic from configuration, minimizing code duplication and reducing human error.
* Least Privilege: Follows CAF guidelines for separating management concerns into dedicated administrative boundaries.