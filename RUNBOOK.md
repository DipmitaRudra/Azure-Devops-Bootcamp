# Runbook: Rebuild the Project From Scratch

This runbook explains how another developer can recreate the **Azure DevOps Bootcamp** project from an empty environment: a containerized portfolio website, hosted on a private Azure Web App behind an Application Gateway, provisioned with Terraform and deployed by GitHub Actions using OIDC.

Follow the steps **in order**. The sequence matters because later components depend on resources created in earlier steps.

> **Cost warning:** this project creates billable Azure resources (Application Gateway, App Service Plan, public IP, Container Registry, storage). Build it when you need it and tear it down when you are done. See [Part G: Cleanup](#part-g--cleanup).

**Conventions used below**

* Commands are written for **PowerShell** (the backtick `` ` `` continues a line).
* Anything in `<ANGLE_BRACKETS>` is a placeholder you must replace.
* Names such as `acrazuredevopsbootcamp` come from `project_name = "azuredevopsbootcamp"`. If you pick a different project name, the names change with it (see the [resource name reference](#appendix-a--resource-name-reference)). Azure Container Registry and storage account names must be **globally unique**, so you may need to choose your own.

---

## Contents

| Part | Steps | What you do |
| ---- | ----- | ----------- |
| [A. Prepare](#part-a--prepare) | 1-4 | Tools, repository, application, Dockerfile, local test |
| [B. Terraform state backend](#part-b--terraform-state-backend) | 5-6 | Resource group, storage account and container for remote state |
| [C. Terraform infrastructure](#part-c--terraform-infrastructure) | 7-13 | Backend, variables, modules, wiring, plan, apply, verify |
| [D. GitHub Actions pipeline](#part-d--github-actions-pipeline) | 14-18 | OIDC, permissions, secrets, workflow, first push |
| [E. Verify everything](#part-e--verify-everything) | 19-23 | Pipeline, image, Web App, traffic path, state, CI/CD test |
| [F. Troubleshooting](#part-f--troubleshooting) | | Common failures and fixes |
| [G. Cleanup](#part-g--cleanup) | 24-26 | Destroy the application, then the state |
| [Appendices](#appendix-a--resource-name-reference) | | Resource names, build order, philosophy |

---

# Part A: Prepare

## 1. Prerequisites

Install:

* Git and a GitHub account
* An Azure account with an active subscription
* Azure CLI
* Terraform (`>= 1.16.0`, as required by `provider.tf`)
* Docker Desktop
* A code editor such as Visual Studio Code
* Optional: GitHub CLI (`gh`), used to set repository secrets from the terminal

Verify the installations:

```powershell
git --version
az --version
terraform version
docker --version
```

Authenticate to Azure and check the active subscription:

```powershell
az login
az account show
```

If you have several subscriptions, select the one to use:

```powershell
az account set --subscription "<SUBSCRIPTION_ID>"
```

**Register the Azure resource providers** the project uses (a brand-new subscription often has some unregistered):

```powershell
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.Storage
```

Registration runs in the background and can take a few minutes. Check it with `az provider show --namespace Microsoft.Web --query registrationState`.

## 2. Create the GitHub repository

Create a new GitHub repository and clone it:

```powershell
git clone <YOUR_REPOSITORY_URL>
cd <YOUR_REPOSITORY_NAME>
```

Create the project structure:

```text
.github/
    workflows/
application/
architecture/
terraform/
    modules/
        resource_group/
        vnet/
        container_registry/
        web_app/
        application_gateway/
```

Create a `.gitignore` early so Terraform files never get committed:

```text
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
tfplan
crash.log
```

> Commit `.terraform.lock.hcl`. It pins the exact provider build and keeps everyone on the same version. Do **not** commit `.terraform/` or any state file.

## 3. Add the portfolio application

Place the website files inside `application/`:

```text
application/
├── Dockerfile
├── index.html
├── main.js
├── stylesheet.css
└── Assets/
    ├── Background pic/
    └── Profile Photo/
```

Test the site locally **before** involving Azure. This separates application problems from infrastructure problems:

```text
Application works locally -> Docker image works locally -> Azure deployment
```

## 4. Create the Dockerfile and test it locally

Create `application/Dockerfile`. It should package the website into an **Nginx** container that serves the files on port 80.

Build and run it:

```powershell
docker build -t azuredevopsbootcampapp ./application
docker run --name azuredevopsbootcampapp -p 8080:80 azuredevopsbootcampapp
```

Open `http://localhost:8080` and confirm the portfolio loads. Then clean up the test container:

```powershell
docker stop azuredevopsbootcampapp
docker rm azuredevopsbootcampapp
```

---

# Part B: Terraform state backend

The state storage is created **by hand (Azure CLI), not by Terraform**. Terraform needs the backend to exist before `terraform init` can run, so it cannot create its own backend.

## 5. Create the resource group for Terraform state

```powershell
az group create `
  --name rg-terraform-state `
  --location centralindia
```

This is deliberately **separate** from the application resource group (`rg-azuredevopsbootcamp`). Deleting the application environment must not delete the Terraform state.

## 6. Create the state storage account and container

```powershell
az storage account create `
  --name stterraformstatebootcamp `
  --resource-group rg-terraform-state `
  --location centralindia `
  --sku Standard_LRS `
  --kind StorageV2 `
  --min-tls-version TLS1_2 `
  --allow-blob-public-access false

az storage container create `
  --name tfstate `
  --account-name stterraformstatebootcamp `
  --auth-mode login
```

Give **yourself** data access to the container (needed for `--auth-mode login`, and for Terraform if it uses Entra ID authentication):

```powershell
$STATE_SA_ID = az storage account show `
  --name stterraformstatebootcamp `
  --resource-group rg-terraform-state `
  --query id -o tsv

$MY_OBJECT_ID = az ad signed-in-user show --query id -o tsv

az role assignment create `
  --assignee-object-id $MY_OBJECT_ID `
  --assignee-principal-type User `
  --role "Storage Blob Data Contributor" `
  --scope $STATE_SA_ID
```

Role assignments can take a few minutes to take effect. If the container creation says you are not authorized, wait and retry.

The resulting structure is:

```text
rg-terraform-state -> stterraformstatebootcamp -> tfstate -> azuredevopsbootcamp.tfstate
```

The `azuredevopsbootcamp.tfstate` blob appears after the first `terraform init`/`apply`. Never commit it to Git.

---

# Part C: Terraform infrastructure

## 7. Configure the provider and backend

Create `terraform/provider.tf`:

```hcl
# Azure Provider source and version being used
terraform {
  required_version = ">=1.16.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=5.0.0"
    }
  }

  # Configure remote backend for storing Terraform state in Azure Storage
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstatebootcamp"
    container_name       = "tfstate"
    key                  = "azuredevopsbootcamp.tfstate"
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}
```

The provider is pinned to exactly `5.0.0` so everyone gets identical behavior.

## 8. Declare and set the root variables

Create `terraform/variables.tf`:

```hcl
variable "project_name" {
  type        = string
  description = "Project name used for resource naming."
}

variable "environment" {
  type        = string
  description = "Deployment environment (e.g., dev, test, prod)."
}

variable "azure_location" {
  type        = string
  description = "Azure location where resources will be deployed."
}

variable "vnet_address_space" {
  type        = list(string)
  description = "The address space for the Virtual Network."
}

variable "pub_sub_address_space" {
  type        = list(string)
  description = "The address spaces for the public subnets."
}

variable "priv_sub_address_space" {
  type        = list(string)
  description = "The address spaces for the private subnets."
}

variable "container_image_tag" {
  type        = string
  description = "Tag for the container image used in deployments."
  default     = "latest"
}
```

Create `terraform/dev.tfvars` (the actual values):

```hcl
project_name           = "azuredevopsbootcamp"
environment            = "dev"
azure_location         = "Central India"
vnet_address_space     = ["10.0.0.0/24"]
pub_sub_address_space  = ["10.0.0.0/26", "10.0.0.64/26"]
priv_sub_address_space = ["10.0.0.128/26", "10.0.0.192/26"]
container_image_tag    = "latest"
```

The pipeline later overrides `container_image_tag` with the Git commit SHA. (`environment` is declared and set but not used by any module.)

## 9. Build the five Terraform modules

Each module has the same three-file shape: resources in a `.tf` file, inputs in `variables.tf`, outputs in `outputs.tf`.

```text
terraform/modules/
├── resource_group/        rg.tf · variables.tf · outputs.tf
├── vnet/                  vnet.tf · nsg.tf · route.tf · public_ip.tf · variables.tf · outputs.tf
├── container_registry/    acr.tf · variables.tf · outputs.tf
├── web_app/               web_app.tf · variables.tf · outputs.tf
└── application_gateway/   agw.tf · variables.tf · outputs.tf
```

The modules are only useful if their **input and output names** match what `main.tf` (step 10) passes between them. The tables below are the contract each module must satisfy.

### `resource_group`

| | |
| --- | --- |
| **Creates** | `azurerm_resource_group` named `rg-<project_name>` |
| **Inputs** | `project_name`, `resource_group_location` |
| **Outputs** | `az_rg_name_out`, `az_rg_location_out` |

### `vnet`

| | |
| --- | --- |
| **Creates** | Virtual network (`vnet-<project_name>`); one subnet per entry in `pub_sub_address_space` and in `priv_sub_address_space`; two NSGs and their subnet associations; two route tables and their associations; a static public IP (`pub-ip-<project_name>`) |
| **Inputs** | `project_name`, `resource_group_name`, `resource_group_location`, `vnet_address_space`, `pub_sub_address_space`, `priv_sub_address_space`, plus optional ones with defaults: `internet_address_space` (`["0.0.0.0/0"]`), `destination_port_range` (`[80]`), `delegation_service_name` (`Microsoft.Web/serverFarms`), `delegation_actions` (`["Microsoft.Network/virtualNetworks/subnets/action"]`) |
| **Outputs** | `az_vnet_id_out`, `az_pub_sub_id_out` (public subnet 1), `az_priv_sub_id_vnet_intgr_out` (private subnet 1), `az_priv_sub_id_ep_out` (private subnet 2), `az_public_ip_id_out`, `az_public_ip_out`, `az_public_ip_fqdn_out` |

Key details to get right:

* **Private subnet 1** (`10.0.0.128/26`) is **delegated** to `Microsoft.Web/serverFarms`. It is used for the Web App's VNet Integration (outbound traffic).
* **Private subnet 2** (`10.0.0.192/26`) has `private_endpoint_network_policies` **disabled**. It hosts the Web App's Private Endpoint (inbound traffic).
* **NSG for the gateway** (applied to public subnet 1): inbound TCP 80 from the Internet, and inbound TCP `65200-65535` from `GatewayManager` (required for Application Gateway v2).
* **NSG for the app** (applied to both private subnets): inbound TCP 80 from the public subnet address range.
* **Route tables:** public subnet 1 gets `0.0.0.0/0 -> Internet`; both private subnets get a route table with no custom routes.
* **Outputs `az_public_ip_out` and `az_public_ip_fqdn_out`** are used by `main.tf` to print `http://...` URLs. For the FQDN output to contain a value, the public IP needs a `domain_name_label`.

### `container_registry`

| | |
| --- | --- |
| **Creates** | `azurerm_container_registry` named `acr<project_name>` (SKU `Basic`, admin user **disabled**) and an `azurerm_role_assignment` giving the Web App's identity the **`AcrPull`** role on the registry |
| **Inputs** | `project_name`, `resource_group_name`, `resource_group_location`, `webapp_identity_principal_id`, plus `acr_sku` (default `Basic`) and `acr_admin_enabled` (default `false`) |
| **Outputs** | `az_acr_id_out`, `az_acr_name_out`, `az_acr_login_server_out` |

### `web_app`

| | |
| --- | --- |
| **Creates** | App Service Plan (Linux, `B1`); Private DNS zone `privatelink.azurewebsites.net` and its VNet link; Linux Web App; Private Endpoint (sub-resource `sites`) with a DNS zone group |
| **Inputs** | `project_name`, `resource_group_name`, `resource_group_location`, `web_app_vnet_id`, `web_app_vnet_integration_subnet_id`, `web_app_private_subnet_id`, `web_app_container_login_server`, `webapp_docker_image_tag`, plus defaults such as `webapp_docker_image_name` (`azuredevopsbootcampapp`), `web_app_os`, `web_app_sku_name`, `webapp_identity_type` (`SystemAssigned`), `acr_use_managed_identity` (`true`), `webapp_ftps_state` (`Disabled`), `webapp_http2_enable`, `webapp_minimum_tls_version` (`1.2`), `webapp_websockets_enable` |
| **Outputs** | `az_webapp_id_out`, `az_webapp_hostname_out`, `az_webapp_private_endpoint_id_out`, `az_webapp_private_endpoint_ip_out`, `az_webapp_identity_principal_id_out` |

Key details to get right:

* `public_network_access_enabled = false`: the Web App is **not** reachable on its public endpoint.
* `virtual_network_subnet_id` = `web_app_vnet_integration_subnet_id` (outbound, private subnet 1).
* The Private Endpoint uses `web_app_private_subnet_id` (inbound, private subnet 2).
* The image is `"<webapp_docker_image_name>:<webapp_docker_image_tag>"` pulled from `https://<web_app_container_login_server>`, with `container_registry_use_managed_identity = true`.

### `application_gateway`

| | |
| --- | --- |
| **Creates** | One `azurerm_application_gateway` (`agw-<project_name>`): SKU `Standard_v2`, autoscale 0 to 2; frontend IP using the public IP; listener on port 80 (HTTP); backend pool containing the Web App's **private endpoint IP**; backend HTTP settings with `host_name` set to the Web App hostname; health probe; routing rule |
| **Inputs** | `project_name`, `resource_group_name`, `resource_group_location`, `agw_subnet_id`, `public_ip_id`, `web_app_backend_priv_ip`, `web_app_backend_hostname`, plus defaults for SKU, ports, protocol and probe settings |
| **Outputs** | `az_agw_id_out` |

Default settings: port `80`, protocol `Http`, cookie affinity `Disabled`, request timeout `60`, probe path `/` with interval `30`, timeout `30`, unhealthy threshold `3`, routing rule type `Basic` with priority `9`. The probe picks its host name from the backend HTTP settings.

## 10. Connect the modules in `main.tf`

Create `terraform/main.tf`. This is the **only** file that wires modules to each other: every module-to-module link happens because one block passes `module.<name>.<output>` into another block's argument.

```hcl
module "resource-group" {
  source                  = "./modules/resource_group"
  project_name            = var.project_name
  resource_group_location = var.azure_location
}

module "vnet" {
  source                  = "./modules/vnet"
  project_name            = var.project_name
  resource_group_name     = module.resource-group.az_rg_name_out
  resource_group_location = module.resource-group.az_rg_location_out
  vnet_address_space      = var.vnet_address_space
  pub_sub_address_space   = var.pub_sub_address_space
  priv_sub_address_space  = var.priv_sub_address_space
}

module "acr" {
  source                       = "./modules/container_registry"
  project_name                 = var.project_name
  resource_group_name          = module.resource-group.az_rg_name_out
  resource_group_location      = module.resource-group.az_rg_location_out
  webapp_identity_principal_id = module.web_app.az_webapp_identity_principal_id_out
}

module "web_app" {
  source                             = "./modules/web_app"
  project_name                       = var.project_name
  resource_group_name                = module.resource-group.az_rg_name_out
  resource_group_location            = module.resource-group.az_rg_location_out
  web_app_vnet_id                    = module.vnet.az_vnet_id_out
  web_app_private_subnet_id          = module.vnet.az_priv_sub_id_ep_out
  web_app_vnet_integration_subnet_id = module.vnet.az_priv_sub_id_vnet_intgr_out
  web_app_container_login_server     = module.acr.az_acr_login_server_out
  webapp_docker_image_tag            = var.container_image_tag
}

module "agw" {
  source                   = "./modules/application_gateway"
  project_name             = var.project_name
  resource_group_name      = module.resource-group.az_rg_name_out
  resource_group_location  = module.resource-group.az_rg_location_out
  public_ip_id             = module.vnet.az_public_ip_id_out
  agw_subnet_id            = module.vnet.az_pub_sub_id_out
  web_app_backend_priv_ip  = module.web_app.az_webapp_private_endpoint_ip_out
  web_app_backend_hostname = module.web_app.az_webapp_hostname_out
}

output "az_public_ip_show" {
  value = "http://${module.vnet.az_public_ip_out}"
}

output "az_public_ip_fqdn_show" {
  value = "http://${module.vnet.az_public_ip_fqdn_out}"
}
```

### The wiring, in build order

![Azure DevOps Project Wiring Diagram](terraform-wiring-diagram.png)

| Step | Connection | Output -> Input |
| ---- | ---------- | --------------- |
| 1 | `resource_group` -> `vnet`, `acr`, `web_app`, `agw` | `az_rg_name_out` -> `resource_group_name`<br>`az_rg_location_out` -> `resource_group_location` |
| 2 | `vnet` -> `web_app` | `az_vnet_id_out` -> `web_app_vnet_id`<br>`az_priv_sub_id_ep_out` -> `web_app_private_subnet_id`<br>`az_priv_sub_id_vnet_intgr_out` -> `web_app_vnet_integration_subnet_id` |
| 3 | `vnet` -> `agw` | `az_public_ip_id_out` -> `public_ip_id`<br>`az_pub_sub_id_out` -> `agw_subnet_id` |
| 4 | `web_app` -> `acr` | `az_webapp_identity_principal_id_out` -> `webapp_identity_principal_id` |
| 5 | `acr` -> `web_app` | `az_acr_login_server_out` -> `web_app_container_login_server` |
| 6 | `web_app` -> `agw` | `az_webapp_private_endpoint_ip_out` -> `web_app_backend_priv_ip`<br>`az_webapp_hostname_out` -> `web_app_backend_hostname` |
| 7 | `vnet` -> root outputs | `az_public_ip_out` -> `az_public_ip_show`<br>`az_public_ip_fqdn_out` -> `az_public_ip_fqdn_show` |

Rather than hard-coding IDs or names, always pass outputs from one module into the next. That is what lets Terraform work out the creation order by itself.

> **Why `acr` and `web_app` can reference each other.** Terraform builds its dependency graph from individual *resources*, not whole modules. The actual order is: Container Registry (needs only the resource group) -> Linux Web App (needs the ACR login server) -> `AcrPull` role assignment (needs the registry id and the Web App's identity). There is no cycle.

## 11. Initialize, validate and plan

From the repository root:

```powershell
terraform -chdir=terraform init
terraform -chdir=terraform validate
terraform -chdir=terraform plan `
  -var-file=dev.tfvars `
  -var="container_image_tag=latest"
```

`init` connects to the Azure backend and downloads the provider and modules. Read the plan carefully before applying. On a clean environment it should only show resources to **add**, none to change or destroy.

> If `init` fails with a 403 or authorization error against the storage account, you are probably missing the `Storage Blob Data Contributor` role from step 6 (or it has not propagated yet). You can also force Entra ID authentication for the backend with `$env:ARM_USE_AZUREAD = "true"`.

## 12. Create the application infrastructure

```powershell
terraform -chdir=terraform apply `
  -var-file=dev.tfvars `
  -var="container_image_tag=latest"
```

Terraform creates the whole environment. The Application Gateway is the slowest resource and can take several minutes.

At this point the Web App exists but has **no image to pull yet**: the registry is empty. That is expected; the pipeline pushes the first image in Part D.

When it finishes, print the outputs:

```powershell
terraform -chdir=terraform output
```

## 13. Verify the Azure infrastructure

```powershell
az group show --name rg-azuredevopsbootcamp --output table
az resource list --resource-group rg-azuredevopsbootcamp --output table
az acr show --name acrazuredevopsbootcamp --output table
az webapp show `
  --name linux-web-app-azuredevopsbootcamp `
  --resource-group rg-azuredevopsbootcamp `
  --output table
```

Confirm the security-relevant settings:

```powershell
# ACR admin user must be disabled -> false
az acr show --name acrazuredevopsbootcamp --query adminUserEnabled -o tsv

# Web App must have public access disabled -> Disabled
az webapp show `
  --name linux-web-app-azuredevopsbootcamp `
  --resource-group rg-azuredevopsbootcamp `
  --query publicNetworkAccess -o tsv

# The Web App's managed identity should hold AcrPull on the registry
$PRINCIPAL_ID = az webapp identity show `
  --name linux-web-app-azuredevopsbootcamp `
  --resource-group rg-azuredevopsbootcamp `
  --query principalId -o tsv
az role assignment list --assignee $PRINCIPAL_ID --all --output table
```

---

# Part D: GitHub Actions pipeline

## 14. Configure GitHub-to-Azure OIDC

The pipeline authenticates with **OpenID Connect**: GitHub issues a short-lived token and Microsoft Entra ID trusts it. No client secret is stored anywhere.

```text
GitHub Actions -> OIDC token -> Microsoft Entra ID -> Azure service principal -> Azure resources
```

Create the app registration and service principal:

```powershell
$APP_ID = az ad app create `
  --display-name "github-actions-azuredevopsbootcamp" `
  --query appId -o tsv

az ad sp create --id $APP_ID
```

Create a **federated credential** that trusts pushes to the `dev` branch of your repository. Save the credential as a JSON file:

```powershell
@"
{
  "name": "github-dev-branch",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<GITHUB_OWNER>/<REPOSITORY_NAME>:ref:refs/heads/dev",
  "audiences": ["api://AzureADTokenExchange"]
}
"@ | Set-Content -Path credential.json

az ad app federated-credential create --id $APP_ID --parameters credential.json
Remove-Item credential.json
```

The `subject` must match your repository and branch **exactly** (it is case-sensitive). If the pipeline later fails to log in, this is the first thing to check.

## 15. Grant the required Azure permissions

The GitHub Actions identity needs permission to do everything the pipeline does:

| Role | Scope | Why it is needed |
| ---- | ----- | ---------------- |
| `Contributor` | Subscription | Terraform creates the resource group and all resources inside it |
| `User Access Administrator` | Subscription | Terraform creates the `AcrPull` role assignment, and creating role assignments is not covered by Contributor |
| `Storage Blob Data Contributor` | State storage account | Read and write the Terraform state blob |
| `AcrPush` | The container registry | Push the Docker image to ACR (see note below) |

```powershell
$SUB_ID = az account show --query id -o tsv
$SP_OBJECT_ID = az ad sp show --id $APP_ID --query id -o tsv
$STATE_SA_ID = az storage account show `
  --name stterraformstatebootcamp `
  --resource-group rg-terraform-state `
  --query id -o tsv
$ACR_ID = az acr show --name acrazuredevopsbootcamp --query id -o tsv

az role assignment create --assignee-object-id $SP_OBJECT_ID --assignee-principal-type ServicePrincipal `
  --role "Contributor" --scope "/subscriptions/$SUB_ID"

az role assignment create --assignee-object-id $SP_OBJECT_ID --assignee-principal-type ServicePrincipal `
  --role "User Access Administrator" --scope "/subscriptions/$SUB_ID"

az role assignment create --assignee-object-id $SP_OBJECT_ID --assignee-principal-type ServicePrincipal `
  --role "Storage Blob Data Contributor" --scope $STATE_SA_ID

az role assignment create --assignee-object-id $SP_OBJECT_ID --assignee-principal-type ServicePrincipal `
  --role "AcrPush" --scope $ACR_ID
```

Notes:

* The subscription-level roles are broad because this Terraform creates the resource group itself. For anything beyond a learning project, narrow the scope.
* The registry exists already because you ran `terraform apply` in step 12. If you destroy and recreate the registry later, **re-create the `AcrPush` assignment**, because it is tied to the registry's resource ID.
* If the pipeline's ACR login or push step fails with an authorization error, check this `AcrPush` assignment first.
* Role assignments can take a few minutes to propagate.
* Avoid storage account keys. Use Azure RBAC for state access.

## 16. Add the GitHub repository secrets

The workflow reads three values from repository secrets. They are identifiers, not passwords, but keep them out of the workflow file anyway.

| Secret | Value |
| ------ | ----- |
| `AZURE_CLIENT_ID` | the `$APP_ID` from step 14 |
| `AZURE_TENANT_ID` | `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | `az account show --query id -o tsv` |

Add them under **Settings -> Secrets and variables -> Actions**, or with the GitHub CLI:

```powershell
gh secret set AZURE_CLIENT_ID       --body $APP_ID
gh secret set AZURE_TENANT_ID       --body (az account show --query tenantId -o tsv)
gh secret set AZURE_SUBSCRIPTION_ID --body $SUB_ID
```

## 17. Create the GitHub Actions workflow

Create `.github/workflows/Deploy-to-Azure.yml`. It triggers on pushes to `dev` and runs these stages:

```text
Checkout -> Azure OIDC login -> Show account -> Setup Terraform -> Init -> Validate -> Plan -> Apply
         -> Refresh Azure login -> ACR login -> Docker build -> Docker push -> Verify image in ACR
         -> Restart Web App
```

A starting point (keep your repository's actual workflow file as the source of truth):

```yaml
name: Deploy to Azure

on:
  push:
    branches: [dev]

permissions:
  id-token: write      # lets the job request an OIDC token
  contents: read

env:
  AZURE_ENVIRONMENT: dev
  ACR_NAME: acrazuredevopsbootcamp
  ACR_REPOSITORY: azuredevopsbootcampapp
  TFVARS_FILE: dev.tfvars
  IMAGE_TAG: ${{ github.sha }}          # every deployment gets a unique image tag
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  ARM_USE_OIDC: "true"                  # Terraform authenticates with OIDC too
  ARM_USE_AZUREAD: "true"               # backend uses Entra ID, not storage keys

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Azure login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Show Azure account
        run: az account show

      - uses: hashicorp/setup-terraform@v3

      - name: Terraform init
        run: terraform -chdir=terraform init
      - name: Terraform validate
        run: terraform -chdir=terraform validate
      - name: Terraform plan
        run: >
          terraform -chdir=terraform plan -input=false
          -var-file=${{ env.TFVARS_FILE }}
          -var="container_image_tag=${{ env.IMAGE_TAG }}"
      - name: Terraform apply
        run: >
          terraform -chdir=terraform apply -auto-approve -input=false
          -var-file=${{ env.TFVARS_FILE }}
          -var="container_image_tag=${{ env.IMAGE_TAG }}"

      - name: Refresh Azure login
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Login to ACR
        run: az acr login --name ${{ env.ACR_NAME }}

      - name: Build Docker image
        run: >
          docker build
          -t ${{ env.ACR_NAME }}.azurecr.io/${{ env.ACR_REPOSITORY }}:${{ env.IMAGE_TAG }}
          ./application

      - name: Push Docker image
        run: docker push ${{ env.ACR_NAME }}.azurecr.io/${{ env.ACR_REPOSITORY }}:${{ env.IMAGE_TAG }}

      - name: Verify image in ACR
        run: >
          az acr repository show-tags --name ${{ env.ACR_NAME }}
          --repository ${{ env.ACR_REPOSITORY }} --output table

      - name: Restart Web App
        run: >
          az webapp restart --name linux-web-app-azuredevopsbootcamp
          --resource-group rg-azuredevopsbootcamp
```

Why the order looks the way it does:

* **Terraform runs before the image is pushed.** Apply points the Web App at `azuredevopsbootcampapp:<sha>`. The image is then built and pushed, and the final **restart** makes the Web App pull it.
* **The Azure login is refreshed before the ACR login.** A long Terraform stage can leave the earlier token stale; refreshing it avoids a confusing ACR authentication failure.
* **The tag is the commit SHA**, so every running image can be traced to the exact commit that produced it, and rollback is a matter of redeploying an earlier SHA.

## 18. Commit and push to `dev`

```powershell
git add .
git commit -m "Initial Azure DevOps project"
git push origin dev
```

The push triggers GitHub Actions automatically.

---

# Part E: Verify everything

## 19. Monitor the pipeline

Open the repository's **Actions** tab and confirm each stage passes:

```text
[x] Checkout Repository
[x] Azure Login
[x] Show Azure Account
[x] Setup Terraform
[x] Terraform Init
[x] Terraform Validate
[x] Terraform Plan
[x] Terraform Apply
[x] Refresh Azure Login
[x] Login to Azure Container Registry
[x] Build Docker Image
[x] Push Docker Image
[x] Verify Docker Image in ACR
[x] Restart Azure Web App
```

If a step fails, troubleshoot **that layer** before changing anything else (see [Part F](#part-f--troubleshooting)).

## 20. Verify the Docker image

```powershell
az acr repository show-tags `
  --name acrazuredevopsbootcamp `
  --repository azuredevopsbootcampapp `
  --output table
```

You should see the commit SHA used by the deployment. Compare it with `git rev-parse HEAD`.

## 21. Verify the Web App and the traffic path

The expected path is:

```text
Internet -> Public IP -> Application Gateway -> Private Endpoint -> Web App -> Portfolio container
```

Check the Private Endpoint and the gateway's view of its backend:

```powershell
az network private-endpoint list `
  --resource-group rg-azuredevopsbootcamp `
  --output table

az network application-gateway show-backend-health `
  --name agw-azuredevopsbootcamp `
  --resource-group rg-azuredevopsbootcamp
```

The backend should report **Healthy**. Then open the URL printed by Terraform:

```powershell
terraform -chdir=terraform output az_public_ip_show
```

Browse to it. You should see the portfolio, served through the Application Gateway.

To prove the Web App itself is **not** publicly reachable, request its default hostname directly:

```powershell
az webapp show `
  --name linux-web-app-azuredevopsbootcamp `
  --resource-group rg-azuredevopsbootcamp `
  --query defaultHostName -o tsv
```

Browsing to `https://<that hostname>` from the internet should be **refused** (public network access is disabled). Only the Application Gateway path works.

## 22. Verify Terraform remote state

```powershell
az storage blob list `
  --account-name stterraformstatebootcamp `
  --container-name tfstate `
  --auth-mode login `
  --output table
```

You should see `azuredevopsbootcamp.tfstate`. You can also list what Terraform manages:

```powershell
terraform -chdir=terraform state list
```

## 23. Test the complete CI/CD loop

Make a small visible change to the portfolio (HTML, CSS or JavaScript), then:

```powershell
git add .
git commit -m "Update portfolio"
git push origin dev
```

GitHub Actions should detect the commit, run Terraform, build a new image, tag it with the **new** SHA, push it to ACR and restart the Web App:

```text
New commit -> Terraform -> New Docker image (new SHA tag) -> Push to ACR -> Restart Web App
```

Refresh the site and confirm your change is live. Run `az acr repository show-tags` again: you should now see **two** tags. That proves the whole path works.

---

# Part F: Troubleshooting

Always find which **layer** failed first (application, Docker, Terraform, authentication, networking) and fix that layer before touching the others.

## Terraform says the resource group already exists

```text
A resource with the ID ... already exists
```

An Azure resource existing does **not** mean Terraform manages it. Check both sides:

```powershell
az group show --name rg-azuredevopsbootcamp
terraform -chdir=terraform state list
```

If Azure has it but the state does not, either import it into the state or delete it and let Terraform recreate it. In a learning environment, recreating is usually simpler.

## Terraform backend authentication fails (403 / not authorized)

Check, in order: the storage account name, the `tfstate` container, the RBAC role, and the GitHub OIDC login. The identity running Terraform needs **`Storage Blob Data Contributor`** on `stterraformstatebootcamp`. Role changes can take a few minutes to apply. For Entra ID authentication on the backend, set `ARM_USE_AZUREAD=true`.

## "Error acquiring the state lock"

A previous run was interrupted and left a lock. First make sure no other `terraform` run is in progress, then release it with the lock ID from the error message:

```powershell
terraform -chdir=terraform force-unlock <LOCK_ID>
```

## GitHub Actions: Azure login fails

Check that the federated credential's `subject` matches your repository and branch exactly (`repo:<owner>/<repo>:ref:refs/heads/dev`), that the three secrets exist and hold the right values, and that the workflow has `permissions: id-token: write`.

## ACR login or push fails

Check Azure authentication first:

```powershell
az account show
az acr show --name acrazuredevopsbootcamp
```

Do **not** turn on the ACR admin account as a workaround. Instead:

* Make sure the Azure login step was **refreshed** right before the ACR login (a stale token is a common cause).
* Confirm the pipeline identity has **`AcrPush`** on the registry.

## Web App cannot pull the image

Check each link in the chain:

```text
ACR exists -> repository exists -> image/tag exists -> Web App has a managed identity -> identity has AcrPull
```

```powershell
az acr repository show-tags --name acrazuredevopsbootcamp --repository azuredevopsbootcampapp --output table
az webapp config container show --name linux-web-app-azuredevopsbootcamp --resource-group rg-azuredevopsbootcamp
az webapp log tail --name linux-web-app-azuredevopsbootcamp --resource-group rg-azuredevopsbootcamp
```

Then confirm the Web App is configured for the tag you expect, and restart it so it pulls again.

## Application Gateway backend shows "Unhealthy" or the site returns 502

Work through the private path:

* Is the Web App running? (`az webapp show ... --query state`)
* Does the Private DNS zone `privatelink.azurewebsites.net` exist and is it **linked to the VNet**?
* Is the backend pool using the Private Endpoint's **private IP**, and does the HTTP setting send the Web App's **hostname**?
* Does the NSG on the private subnets allow inbound port 80 from the public subnet?
* Does the health probe path (`/`) actually return a successful response from the container?

## Errors about unregistered resource providers or quota

`MissingSubscriptionRegistration` means a provider is not registered. Register it (see step 1) and retry. A quota error on the App Service Plan means the chosen SKU is not available to your subscription in that region; pick another region or SKU.

---

# Part G: Cleanup

## 24. Destroy the application environment

When you no longer need the project, remove the application resources to stop Azure charges.

The cleanest way is through Terraform, so the state stays accurate:

```powershell
terraform -chdir=terraform destroy `
  -var-file=dev.tfvars `
  -var="container_image_tag=<CURRENT_IMAGE_TAG>"
```

Alternatively, for this learning project you can delete the application resource group directly:

```powershell
az group delete --name rg-azuredevopsbootcamp --yes
```

> If you delete the resource group with the CLI, the Terraform state still lists resources that no longer exist. That is fine if you are finished with the project and will delete the state next; it is **not** fine if you plan to reuse the same state later.

Verify:

```powershell
az group list --output table
```

## 25. Destroy the Terraform state infrastructure

Only do this when the project is **completely finished** and you no longer need the state:

```text
rg-terraform-state -> stterraformstatebootcamp -> tfstate
```

```powershell
az group delete --name rg-terraform-state --yes
```

Once it is deleted, the remote Terraform state is gone for good. To rebuild later, recreate the backend first (Part B).

## 26. Final Azure cleanup check

```powershell
az group list --output table
```

Review every remaining resource group. Do not delete one just because it looks unfamiliar: some are created by Azure itself (for example `NetworkWatcherRG`) or may belong to another project. **Check what a resource group contains before deleting it.**

Also remove the leftovers outside Azure if you want a full clean-up: the Entra app registration (`github-actions-azuredevopsbootcamp`), its role assignments, and the repository secrets.

---

# Appendix A: Resource name reference

All names derive from `project_name = "azuredevopsbootcamp"`.

| Resource | Name |
| -------- | ---- |
| Resource group | `rg-azuredevopsbootcamp` |
| Virtual network | `vnet-azuredevopsbootcamp` |
| Public subnets | `pub-sub-azuredevopsbootcamp-1`, `pub-sub-azuredevopsbootcamp-2` |
| Private subnets | `priv-sub-azuredevopsbootcamp-1` (VNet Integration), `priv-sub-azuredevopsbootcamp-2` (Private Endpoint) |
| NSGs | `nsg-agw-azuredevopsbootcamp`, `nsg-app-azuredevopsbootcamp` |
| Route tables | `rt-pub-sub-azuredevopsbootcamp`, `rt-priv-sub-azuredevopsbootcamp` |
| Public IP | `pub-ip-azuredevopsbootcamp` |
| Container registry | `acrazuredevopsbootcamp` |
| Image repository | `azuredevopsbootcampapp` |
| App Service Plan | `asp-azuredevopsbootcamp` |
| Web App | `linux-web-app-azuredevopsbootcamp` |
| Private Endpoint | `web-app-priv-ep-azuredevopsbootcamp` |
| Private DNS zone | `privatelink.azurewebsites.net` |
| Private DNS VNet link | `pri-dns-zone-vnet-link-azuredevopsbootcamp` |
| Application Gateway | `agw-azuredevopsbootcamp` |
| State resource group | `rg-terraform-state` |
| State storage account | `stterraformstatebootcamp` |
| State container / blob | `tfstate` / `azuredevopsbootcamp.tfstate` |

# Appendix B: Recommended build order (summary)

```text
 1. Install tools, sign in to Azure, register resource providers
 2. Create the GitHub repository and folder structure
 3. Add the portfolio application
 4. Create the Dockerfile and test it locally
 5. Create the state resource group
 6. Create the state storage account and the tfstate container (and your own blob role)
 7. Configure provider.tf and the backend
 8. Write variables.tf and dev.tfvars
 9. Write the five modules
10. Wire the modules in main.tf
11. terraform init, validate, plan
12. terraform apply
13. Verify the infrastructure
14. Configure GitHub OIDC (app registration + federated credential)
15. Assign Azure roles
16. Add the GitHub secrets
17. Create the GitHub Actions workflow
18. Push to dev
19. Watch the pipeline, then verify image, Web App, traffic and state
20. Push a second commit to prove CI/CD end to end
21. Destroy the application resources
22. Destroy the Terraform state when completely finished
```

# Appendix C: Cost warning

Azure resources can cost money even when idle. Pay particular attention to:

* Application Gateway (billed while it exists)
* App Service Plan
* Public IP addresses
* Container Registry
* Storage accounts
* Anything else that runs continuously

For a learning project, create resources only when needed and destroy them afterwards. Before deleting anything, confirm it does not belong to another project or workload.

# Appendix D: Rebuild philosophy

The goal is not just to reproduce the same Azure resources. It is to understand two chains.

**The dependency chain** (what depends on what):

```text
Application -> Docker -> Container Registry -> Web App -> Private Networking -> Application Gateway -> End User
```

**The delivery chain** (how a change reaches users):

```text
Git -> GitHub -> GitHub Actions -> OIDC -> Terraform -> Azure -> Docker image -> Web App
```

Once both chains are clear, the project is much easier to troubleshoot and extend, for example into separate development, test and production environments.
