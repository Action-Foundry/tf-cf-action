# Terraform Cloudflare Provider Configuration
# This file provides the base configuration for Cloudflare resources

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Configure the Cloudflare provider
# API token is automatically sourced from CLOUDFLARE_API_TOKEN environment variable
provider "cloudflare" {
  # API token with appropriate permissions
  # Recommended permissions:
  # - Zone:Read, Zone:Edit (for zone management)
  # - DNS:Read, DNS:Edit (for DNS records)
  # - Cache Purge (for cache management)
  # - Page Rules:Edit (for page rules)
  # - Firewall:Edit (for WAF/Firewall rules)
}

# Data source to validate API token
data "cloudflare_api_token_permission_groups" "all" {}
