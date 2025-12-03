# Terraform Cloudflare Action

[![GitHub Marketplace](https://img.shields.io/badge/Marketplace-Terraform%20Cloudflare%20Action-blue?logo=github)](https://github.com/marketplace/actions/terraform-cloudflare-action)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A GitHub Action for Cloudflare CI/CD with Terraform, featuring **SMART** (Specific, Measurable, Achievable, Relevant, Time-bound) and **DRY** (Don't Repeat Yourself) best practices. This action provides a secure, maintainable, and industry-standard approach to managing Cloudflare infrastructure as code.

## 🌟 Features

- **Terraform-Based Management**: Full lifecycle management of Cloudflare resources
- **Safety First**: Built-in safety mechanisms with plan preview before apply
- **Import Support**: Easily onboard existing Cloudflare domains to Terraform state
- **Flexible Configuration**: Support for tfvars files and inline variables
- **CI/CD Ready**: Designed for seamless GitHub Actions integration
- **DRY Architecture**: Modular, reusable configuration patterns

## 📋 Table of Contents

- [Quick Start](#-quick-start)
- [Inputs](#-inputs)
- [Outputs](#-outputs)
- [Usage Examples](#-usage-examples)
- [Safety Mechanisms](#-safety-mechanisms)
- [Importing Existing Resources](#-importing-existing-resources)
- [Terraform Configuration](#-terraform-configuration)
- [Best Practices](#-best-practices)
- [Contributing](#-contributing)

## 🚀 Quick Start

### Prerequisites

1. **Cloudflare API Token**: Create a token with appropriate permissions
2. **GitHub Secrets**: Store your credentials securely
   - `CLOUDFLARE_API_TOKEN`
   - `CLOUDFLARE_ACCOUNT_ID`

### Basic Usage

```yaml
name: Cloudflare Infrastructure
on:
  push:
    branches: [main]
  pull_request:

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Terraform Plan
        uses: Action-Foundry/tf-cf-action@main
        with:
          cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          terraform_action: plan
          working_directory: ./terraform
```

## 📥 Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `cloudflare_api_token` | Cloudflare API token | ✅ Yes | - |
| `cloudflare_account_id` | Cloudflare Account ID | ✅ Yes | - |
| `terraform_version` | Terraform version to use | No | `1.6.0` |
| `working_directory` | Directory containing Terraform config | No | `.` |
| `terraform_action` | Action to perform: `plan`, `apply`, `destroy`, `import`, `validate` | No | `plan` |
| `auto_approve` | Skip approval for apply/destroy | No | `false` |
| `tfvars_file` | Path to terraform.tfvars file | No | - |
| `tfvars` | Inline Terraform variables (HCL format) | No | - |
| `backend_config` | Backend configuration (key=value pairs) | No | - |
| `import_resources` | Resources to import (format: `resource.name=id`) | No | - |
| `plan_output_file` | Path for plan output file | No | `tfplan` |
| `enable_drift_detection` | Enable drift detection before apply | No | `true` |
| `destroy_protection` | Require explicit confirmation for destroy | No | `true` |
| `max_parallelism` | Maximum concurrent operations | No | `10` |

## 📤 Outputs

| Output | Description |
|--------|-------------|
| `plan_output` | Terraform plan output |
| `plan_has_changes` | Whether the plan has changes (`true`/`false`) |
| `plan_summary` | Summary of planned changes |
| `apply_output` | Terraform apply output |
| `state_outputs` | Terraform state outputs as JSON |
| `imported_resources` | List of successfully imported resources |

## 💡 Usage Examples

### Plan on Pull Request

```yaml
name: Terraform Plan
on:
  pull_request:
    paths:
      - 'terraform/**'

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Terraform Plan
        id: plan
        uses: Action-Foundry/tf-cf-action@main
        with:
          cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          terraform_action: plan
          working_directory: ./terraform
          tfvars_file: production.tfvars
```

### Apply on Merge to Main

```yaml
name: Terraform Apply
on:
  push:
    branches: [main]

jobs:
  apply:
    runs-on: ubuntu-latest
    environment: production  # Requires approval
    steps:
      - uses: actions/checkout@v4
      
      - name: Terraform Apply
        uses: Action-Foundry/tf-cf-action@main
        with:
          cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          terraform_action: apply
          auto_approve: true
          working_directory: ./terraform
          tfvars_file: production.tfvars
```

### Using Inline Variables

```yaml
- name: Terraform with Inline Variables
  uses: Action-Foundry/tf-cf-action@main
  with:
    cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    terraform_action: plan
    tfvars: |
      zones = {
        "my-domain" = {
          zone_name = "example.com"
          plan      = "free"
        }
      }
```

### Remote State Backend

```yaml
- name: Terraform with Remote State
  uses: Action-Foundry/tf-cf-action@main
  with:
    cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    terraform_action: plan
    backend_config: |
      bucket=my-terraform-state
      key=cloudflare/terraform.tfstate
      region=us-east-1
```

## 🛡️ Safety Mechanisms

This action includes multiple safety features to prevent accidental changes:

### 1. Plan Before Apply
All `apply` operations automatically run a plan first, ensuring you see what will change.

### 2. Approval Required
By default, `auto_approve` is `false`, requiring explicit confirmation before changes.

### 3. Destroy Protection
The `destroy_protection` input (default: `true`) prevents accidental destruction of resources.

```yaml
# Destroy requires BOTH flags
- uses: Action-Foundry/tf-cf-action@main
  with:
    terraform_action: destroy
    auto_approve: true           # Must be true
    destroy_protection: false    # Must be false
```

### 4. Drift Detection
Enable `enable_drift_detection` to detect and report any configuration drift before applying changes.

### 5. Environment Protection
Use GitHub Environments with required reviewers for production deployments:

```yaml
jobs:
  deploy:
    environment: production  # Configure required reviewers in GitHub
```

## 📦 Importing Existing Resources

Onboard existing Cloudflare resources into Terraform management:

```yaml
- name: Import Existing Zone
  uses: Action-Foundry/tf-cf-action@main
  with:
    cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    terraform_action: import
    import_resources: |
      cloudflare_zone.main=zone_id_here
      cloudflare_record.www=zone_id/record_id
```

### Import Format

Resources should be specified as:
```
resource_type.resource_name=cloudflare_identifier
```

Examples:
- Zone: `cloudflare_zone.example=abc123`
- DNS Record: `cloudflare_record.www=abc123/def456`
- Worker: `cloudflare_worker_script.api=account_id/script_name`

## 🔧 Terraform Configuration

### Directory Structure

```
terraform/
├── provider.tf      # Provider configuration
├── main.tf          # Resource definitions
├── variables.tf     # Variable definitions
├── outputs.tf       # Output definitions
├── terraform.tfvars # Variable values
└── backend.tf       # State backend (optional)
```

### Example terraform.tfvars

```hcl
# Zone Configuration
zones = {
  "main" = {
    zone_name = "example.com"
    plan      = "free"
  }
}

# DNS Records
dns_records = {
  "www" = {
    zone_id = "your-zone-id"
    name    = "www"
    type    = "CNAME"
    content = "example.com"
    proxied = true
  }
}
```

## 📚 Best Practices

### 1. SMART Principles

- **Specific**: Define exact resources with clear naming conventions
- **Measurable**: Track changes through plan summaries and outputs
- **Achievable**: Start with simple configurations, expand gradually
- **Relevant**: Only manage resources that need automation
- **Time-bound**: Use CI/CD for consistent, timely deployments

### 2. DRY Principles

- Use variables for repeated values
- Leverage Terraform modules for reusable patterns
- Define default tags in variables
- Use `for_each` for similar resources

### 3. Security

- Never commit API tokens or secrets
- Use GitHub Secrets for sensitive values
- Enable destroy protection in production
- Use environment protection rules

### 4. CI/CD Workflow

```
Pull Request → Plan → Review → Merge → Apply
```

1. **Pull Request**: Triggers automatic plan
2. **Plan**: Shows proposed changes in PR comments
3. **Review**: Team reviews changes
4. **Merge**: Triggers apply to production
5. **Apply**: Changes are applied with approval

## 📁 Example Workflows

Pre-built workflow templates are available in the [`.github/workflows`](.github/workflows) directory:

- **cloudflare-plan.yml**: Plan on pull requests
- **cloudflare-apply.yml**: Apply on merge to main
- **cloudflare-import.yml**: Import existing resources

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Cloudflare Terraform Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest)
- [HashiCorp Terraform](https://www.terraform.io/)
- The DevOps community for best practices and patterns
