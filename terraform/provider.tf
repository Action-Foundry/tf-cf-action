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
  
  # Best practice: Add backend configuration in a separate backend.tf file
  # or provide it via backend-config flags during initialization
}

# Configure the Cloudflare provider
# API token is automatically sourced from CLOUDFLARE_API_TOKEN environment variable
# Account ID is sourced from CLOUDFLARE_ACCOUNT_ID environment variable
provider "cloudflare" {
  # API token with appropriate permissions
  # Recommended permissions:
  # - Zone:Read, Zone:Edit (for zone management)
  # - DNS:Read, DNS:Edit (for DNS records)
  # - Cache Purge (for cache management)
  # - Page Rules:Edit (for page rules)
  # - Firewall Services:Edit (for WAF/Firewall rules)
  # - Workers Scripts:Edit (for Workers deployment)
  # - Access:Edit (for Zero Trust applications)
  
  # Note: Never hardcode credentials in this file
  # Always use environment variables or secure secret management
}
