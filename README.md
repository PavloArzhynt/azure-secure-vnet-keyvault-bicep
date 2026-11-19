# Azure Secure Network & Key Vault Baseline (Bicep IaC)

A production-oriented **Infrastructure as Code (IaC)** template written in **Azure Bicep** that deploys a segmented Virtual Network, Network Security Groups (NSG), and a hardened **Azure Key Vault** protected by RBAC and network ACLs.

## Architecture Overview

```text
[Internet]
    │  (HTTPS 443 Allowed | SSH 22 & RDP 3389 Blocked)
    ▼
┌──────────────────────────────────────────────────────────┐
│ Virtual Network: az-dev-core-vnet (10.10.0.0/16)         │
│                                                          │
│  ┌─────────────────────────┐  ┌───────────────────────┐  │
│  │ snet-app (10.10.1.0/24) │  │ snet-private-endpoints│  │
│  │ + NSG Attached          │  │ (10.10.2.0/24)        │  │
│  │ + Service Endpoint: KV  │  └───────────────────────┘  │
│  └────────────┬────────────┘                             │
└───────────────┼──────────────────────────────────────────┘
                │ Trusted VNet Rule + RBAC
                ▼
      ┌───────────────────┐
      │  Azure Key Vault  │  (Public DefaultAction: Deny,
      │  (RBAC Enabled)   │   Soft-Delete Enabled)
      └───────────────────┘
```

## Key Security & Cloud Engineering Practices Demonstrated
* **Network Segmentation:** Separates application workloads (`10.10.1.0/24`) from private endpoints (`10.10.2.0/24`).
* **Zero-Trust NSG Rules:** Explicitly blocks inbound SSH (`22`) and RDP (`3389`) from the internet while permitting HTTPS (`443`).
* **Hardened Key Vault:** Replaces legacy access policies with **Azure RBAC** (`Key Vault Secrets Officer`), enables **Soft Delete**, and restricts network access (`defaultAction: 'Deny'`) exclusively to the trusted application subnet.
* **Declarative IaC:** Parameterized Bicep template supporting multi-environment deployments (`dev` / `prod`).

## Quick Deployment (Azure CLI)

```bash
# 1. Create a Resource Group
az group create --name rg-secure-core-dev --location westeurope

# 2. Get your Entra ID Object ID
ADMIN_ID=\$(az ad signed-in-user show --query id -o tsv)

# 3. Validate & Deploy the Bicep template
az deployment group create \
  --resource-group rg-secure-core-dev \
  --template-file main.bicep \
  --parameters environment=dev adminObjectId=\$ADMIN_ID
```

