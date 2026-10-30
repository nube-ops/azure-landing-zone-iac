### Azure Enterprise-Scale Landing Zone (Bicep & PowerShell Automation)
* This repository contains a production-grade, enterprise-grade multi-tenant implementation of the Microsoft Cloud Adoption Framework (CAF) Enterprise-Scale Architecture using Azure Bicep, supported by robust PowerShell automation for secure CI/CD bootstrapping.
* Designed for tenant-level deployments, this codebase automates enterprise governance, management group hierarchies, identity foundations, and subscription associations securely and repeatably.

### Engineering Highlights & Architecture Principles
* **100% DRY Parameterization:** Tenant hierarchy and subscription mappings are dynamically synthesized from a single `orgName` variable.
* **Zero-Touch Security:** Eliminates long-lived service principal secrets entirely using GitHub OIDC Federated Credentials (`api://AzureADTokenExchange`).
* **Idempotent Automation:** PowerShell bootstrap scripts feature state-aware content-hash convergence and zero-write optimizations.
* **Enterprise Governance:** Implements CAF-aligned management group structures, automated subscription discovery, and policy inheritance out-of-the-box.
* **Policy-as-Code Governance:** Enforces mandatory security benchmarks, compliance standards, and automated tagging rules directly at the management group root.

### Architecture Topology
```text
Tenant Root Group 
├── mg-contoso-us (Organization Root)
│   ├─ mg-contoso-us-platform
│   │  ├─ mg-contoso-us-connectivity
│   │  │  └─ sub-contoso-us-connectivity (Subscription)
│   │  │     └─ rg-net-hub-prod-cus-01 # Core Hub VNet, Azure Firewall, VPN Gateways
│   │  ├─ mg-contoso-us-identity
│   │  │  └─ sub-contoso-us-identity (Subscription)
│   │  │     ├─ rg-core-identity-cus-01 # Core Domain Controllers & Directory Sync
│   │  │     └─ rg-mgmt-identity-cus-01 # CI/CD Bootstrap, UMI, & OIDC Trust Foundation
│   │  └─ mg-contoso-us-operations
│   │     └─ sub-contoso-us-operations (Subscription)
│   │        └─ rg-ops-logs-prod-cus-01 # Central Log Analytics, Automation, & Monitor Dashboards
│   │        └─ rg-ops-deploy-prod-cus-01 # 
│   └─ mg-contoso-us-landingzones
│      ├─ mg-contoso-us-corp
│      │  └─ sub-contoso-us-corp (Subscription)
│      │     ├─ rg-corp-workloads-prod-cus-01 # Internal Line-of-Business Application Workloads
│      │     └─ rg-corp-data-prod-cus-01 # Backend Databases & Persistent Storage Tiers
│      └─ mg-contoso-us-online
│         └─ sub-contoso-us-online (Subscription)
│            ├─ rg-online-web-prod-cus-01 # Public-Facing Web Apps & Microservices
│            └─ rg-online-edge-prod-cus-01 # Application Gateways, CDNs, & Front-End Routing
```
### Repository Structure
Configuration Management: Fully DRY parameterization allows enterprise deployment naming and hierarchy trees to be dynamically synthesized from a single orgName variable declaration inside main.bicepparam.
```text
azure-landing-zone-iac/
│
├── .github/
│   └── workflows/
│       ├── deploy-foundation.yml   <-- Handles MGs, Policies & Governance, and Sub association
│       └── deploy-resources.yml    <-- Handles subscription-scoped VNets, NSGs, and workload RGs
├── environments/
│   ├── dev/
│   └── prod/
│       ├── main.bicep              <-- Master Tenant Orchestration Entry Point
│       ├── main.bicepparam         <-- Production Single Source of Truth Parameters
│       ├── main.bicepparam.example <-- Parameter Template for Developers
│       ├── connectivity.bicep      <-- Subscription Scope: Hub & Networking
│       ├── corp.bicep              <-- Subscription Scope: Internal Workloads
│       ├── identity.bicep          <-- Subscription Scope: Identity & Directory Services
│       ├── operations.bicep        <-- Subscription Scope: Logs & Automation
│       ├── online.bicep            <-- Subscription Scope: Public Web & Edge Routing
│       └── platform-teams.json     <-- Single source of truth for identity and metadata
├── modules/
│   ├── management-groups/
│   │   ├── managementGroup.bicep
│   │   └── subscriptionAssociation.bicep
│   ├── governance/
│   ├── resource-groups/
│   ├── networking/
│   ├── key-vault/
│   └── landing-zones/
├── scripts/
│   ├── bootstrap/
│   │   ├── Initialize-TenantOidc.ps1       <-- Handles Tenant Root & Deployer Group UMI/OIDC
│   │   ├── Initialize-SubscriptionSecrets.ps1 <-- Synchronizes IDs to GitHub Secrets
│   │   ├── Initialize-SubscriptionOidc.ps1    <-- Handles Subscription-Scoped Workload UMI & RBAC
│   │   ├── Initialize-PlatformTeams.ps1    <-- Handles Core Identity Foundations
│   └── common/
│       ├── Test-EnvironmentPreflight.ps1
│       └── Invoke-WithRetry.ps1
├── .gitignore
└── README.md
```

### Prerequisites
Minimum tool versions are defined in `scripts/common/prerequisites.psd1` and enforced by: `./scripts/bootstrap/Test-Prerequisites.ps1`

#### **Permissions:**
* **Tenant Root Scope (`/`):** Owner or User Access Administrator permissions at the Azure AD Tenant root scope to create top-level Management Groups and assign tenant-level RBAC roles.

#### **Required Tools & Versions:**
* **Minimum versions are defined in** `scripts/LandingZone.Bootstrap/prerequisites.psd1`. Run the following command to update the table below. 
```
pwsh ./scripts/tools/Update-ReadmePrerequisites.ps1
```
<!-- prerequisites:start -->
| Tool | Minimum version | Install |
| :--- | :--- | :--- |
| PowerShell | 7.4.0 | `winget install --id Microsoft.PowerShell` |
| az | 2.20.0 | `winget install --id Microsoft.AzureCLI` |
| bicep | 0.20.0 | `az bicep install` |
| gh | 2.0.0 | `winget install --id GitHub.Cli` |
| git | 2.30.0 | `winget install --id Git.Git` |
<!-- prerequisites:end -->

#### **Security & Best Practices:**
* **Zero Hardcoded Secrets:** All environment-specific subscription IDs, client IDs, and names are injected dynamically via parameters or parameter files.
* **Idempotent Automation:** PowerShell bootstrap scripts utilize defensive, state-aware checking to ensure safe, repeatable multi-run execution without manual state cleanup.
* **Secure CI/CD Authentication:** Avoids long-lived client secrets by leveraging GitHub OIDC Federated Credentials for secure, token-based cloud deployment.
* **Modularization ("Don't Repeat Yourself"):** Reusable modules decouple logic from configuration, minimizing code duplication and reducing human error.
* **Least Privilege:** Follows CAF guidelines for separating management concerns into dedicated administrative boundaries.

### 🚀 Deployment Instructions
To maintain strict adherence to DRY, Idempotency, and Cloud Governance best practices, follow these sequential phases to bootstrap your enterprise landing zone environment.

### SECTION 1: Platform Foundation & Governance
* **Phase 1:** Pre-Provisioning & Subscription Naming Conventions
* **Phase 2:** Automated Subscription Discovery & Parameter Synchronization (`Initialize-SubscriptionSecrets.ps1`)
* **Phase 3:** OIDC Bootstrap & Identity Trust Configuration (`Initialize-TenantOidc.ps1`)
* **Phase 4:** Management Group Hierarchy & Policy-as-Code Deployment (`main.bicep`)

### Phase 1: Pre-Provisioning & Subscription Naming Conventions
* Prior to running the bootstrap scripts or deployment pipeline, ensure your target enterprise subscriptions are pre-provisioned within your Azure tenant and that the `main.bicepparam` subscription associations align with your Azure subscription names.
* **Billing & Creation Constraints:** Standard Pay-As-You-Go or personal Azure accounts are typically capped at a maximum of 5 active subscriptions and often throttle rapid programmatic creation (limiting provisioning to one subscription per 24-hour window). For a complete landing zone rollout, ensure these subscriptions are created beforehand via your Azure Portal or enterprise agreement billing profile.
---
| Workload Domain | Required Naming Keyword | Example Subscription Name |
| :--- | :--- | :--- |
| **Connectivity** | `connectivity` | `sub-contoso-us-connectivity` |
| **Corp Landing Zones** | `corp` | `sub-contoso-us-corp` |
| **Online Landing Zones** | `online` | `sub-contoso-us-online` |
| **Identity** | `identity` | `sub-contoso-us-identity` |
| **Operations** | `operations` | `sub-contoso-us-operations` |
---
* **Single Source of Truth (DRY Naming):** Changing `orgName` and `deploymentRegion` at the top of `environments/prod/main.bicepparam` automatically cascades custom naming across all management groups and resource hierarchies. The subscriptionAssociations block at the bottom maps explicit workload domains (such as corp, online, and connectivity), which are then automatically parsed and synchronized with your actual Azure Subscription IDs by the initialization script in Phase 2.

### Phase 2: Automated Subscription Discovery & Parameter Synchronization
* Once your subscriptions are active, authenticate your CLI tools and run the subscription management script from your repository root:
```powershell
.\scripts\bootstrap\Initialize-SubscriptionSecrets.ps1
```
What Initialize-SubscriptionSecrets.ps1 Accomplishes:
* **Automated Preflight Diagnostics:** Validates active Azure CLI (az) and GitHub CLI (gh) sessions, verifying repository ownership context and failing fast with explicit remediation guides if missing.
* **Intelligent Context Auto-Discovery:** Natively resolves local Git remote repository metadata (Owner and Repository) to target the correct GitHub environment without hardcoded configurations.
* **Tenant Subscription Mapping:** Queries active enterprise Azure subscriptions, filtering dynamically across core workload domains (connectivity, corp, online, identity, operations) and validating enabled states.
* **Idempotent Bicepparam Auto-Population (DRY Architecture):** Programmatically parses and injects discovered subscription IDs directly into target arrays within 'main.bicepparam' without manual input.
* **Content-Hash Convergence & Zero-Write Optimization:** Evaluates existing file contents before writing, skipping disk mutations if state is already fully synchronized to prevent unnecessary file lock churn.
* **Structural Diff Auditing:** Employs `git diff --no-index` against a temporary backup to prove isolated parameter modifications and guarantee absolute zero unintended drift.
* **Automated CI/CD Secret Syncing:** Authenticates via the GitHub CLI to securely upsert required workload subscription IDs straight into GitHub Actions repository settings, complete with live audit tables.

### Phase 3: Configure Primary & Multi-Region HA Architecture
* Designate your primary deployment location with `isPrimary: true` in your environment parameters file (`environments/prod/main.bicepparam`), while aligning your secondary region with its Azure-paired region for high availability (HA), disaster recovery (DR) readiness, and automated cross-region policy compliance.
* Execute the zero-touch, highly secure, and idempotent bootstrap script locally from your repository root:
```powershell
.\scripts\bootstrap\Initialize-TenantOidc.ps1
```
What Initialize-TenantOidc.ps1 Accomplishes:
* **Dynamic Bicepparam Integration (DRY Architecture):** Programmatically reads your environment's parameter file (`environments/prod/main.bicepparam`), isolating the configuration block where `isPrimary: true` is declared to automatically derive target regions and resource naming conventions (such as location and region codes) without hardcoded duplication.
* **Automated Preflight Diagnostics:** Validates active Azure CLI (`az`) and GitHub CLI (`gh`) sessions upfront, failing fast with precise remediation instructions if missing.
* **Intelligent Context Auto-Discovery:** Dynamically detects your active Azure Subscription ID, Tenant ID, and local Git remote metadata (Owner/Repository) with a graceful fallback safety net.
* **Resilient Transient Error Handling:** Built using a reusable retry wrapper helper function (`Invoke-WithRetry`) to gracefully ride out cloud and API network blips.
* **Advanced Security & Modern OIDC Federation:** Resolves immutable GitHub user and repository numeric IDs via the GitHub API to configure secure OpenID Connect (OIDC) federated credentials (`api://AzureADTokenExchange`), preventing common deployment authentication failures (AADSTS700213).
* **Idempotent Tenant Root RBAC & Upsert Architecture:** Safely checks for and provisions required resources (Resource Groups, User-Assigned Managed Identities, OIDC credentials, and tenant-root role assignments—including Contributor, Resource Policy Contributor, and User Access Administrator for dynamic RBAC delegation) to ensure secure, repeatable multi-run execution without duplicate resource creation.
* **Automated Secret Syncing (Zero-Touch CI/CD):** Authenticates via the GitHub CLI to automatically push required configuration secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `TENANT_ROOT_MANAGEMENT_GROUP_ID`) straight into your GitHub repository settings.
* **Live Visual Verification:** Outputs formatted tabular Azure resource verifications and active repository secret lists upon completion for transparent auditing.

### Phase 4: Management Group Topology & Deployment Execution
> **⚠️ Architectural Note on Sequencing:** Phase 3 (`Initialize-TenantOidc.ps1`) must be completed prior to executing Phase 4. Once `main.bicep` deploys the `Root-Tagging-Initiative` policy set at the management group root level, any subsequent foundational resource provisioning must strictly adhere to enterprise tag compliance guardrails.
* **Customizing the Architecture Topology:** If organizational modifications are required, edit the Management Group Hierarchy (Topology Mapping) section and subscription associations inside `environments/prod/main.bicepparam`.
* **Default Out-of-the-Box Deployment:** If no custom modifications are necessary, the pipeline deploys the enterprise-scale landing zone architecture topology exactly as documented out-of-the-box.
* **Execution Workflow:** The parameter file feeds directly into the tenant-level Bicep orchestration template (`main.bicep`), driving data-driven creation of management groups, governance policies, and subscription associations.
* **Pipeline Monitoring & Verification:** Execute the following automation command block via the GitHub CLI to trigger the deployment workflow, stream real-time execution status, validate convergence, and automatically dump logs if any failure occurs:
```powershell
gh workflow run deploy-foundation.yml; gh run watch --exit-status; gh run view $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId') --log-failed
```
### Post-Deployment Verification
To empirically verify that your tenant-level orchestration, policy assignments, and subscription associations have successfully converged, execute the following Azure CLI verification commands:

* **Validate Management Group Hierarchy:**
```powershell
az account management-group list --query "[].{Name:name, DisplayName:displayName, ID:id}" --output table
```
* **Verify Tenant Subscription Inventory:**
```powershell
az account list --all --output table
```
* **Audit Inherited Policy Assignments at Root Scope:**
```powershell
az policy assignment list --scope "/providers/Microsoft.Management/managementGroups/mg-contoso-us" --query "[].{Name:name, DisplayName:displayName, Enforcement:enforcementMode}" --output table
```
* **Confirm Scoped Policy Exemption Lifecycle:**
```powershell
az policy exemption show --name "exemption-allow-hub-public-ips" --scope "/subscriptions/11111111-1111-1111-1111-111111111111" --output table
```

### Section 2: Core Infrastructure & Connectivity
* **Phase 5:** Subscription-Scoped Connectivity Hub Deployment (`connectivity.bicep` & `modules/networking/`)
