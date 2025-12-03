# Variable Definitions for Terraform Cloudflare Action
# These variables enable flexible configuration of Cloudflare resources

#==============================================================================
# AUTHENTICATION VARIABLES
#==============================================================================

variable "cloudflare_api_token" {
  description = "Cloudflare API Token with appropriate permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
  sensitive   = true
}

#==============================================================================
# ZONE CONFIGURATION
#==============================================================================

variable "zones" {
  description = "Map of zones to manage"
  type = map(object({
    zone_name  = string
    plan       = optional(string, "free")
    paused     = optional(bool, false)
    jump_start = optional(bool, false)
    type       = optional(string, "full")
  }))
  default = {}
}

#==============================================================================
# DNS RECORDS
#==============================================================================

variable "dns_records" {
  description = "Map of DNS records to create"
  type = map(object({
    zone_id  = string
    name     = string
    type     = string
    content  = optional(string, null)
    data     = optional(map(string), null)
    priority = optional(number, null)
    proxied  = optional(bool, false)
    ttl      = optional(number, 1)
    comment  = optional(string, null)
    tags     = optional(list(string), [])
  }))
  default = {}
}

#==============================================================================
# PAGE RULES
#==============================================================================

variable "page_rules" {
  description = "Map of page rules to create"
  type = map(object({
    zone_id  = string
    target   = string
    priority = optional(number, 1)
    status   = optional(string, "active")
    actions  = map(any)
  }))
  default = {}
}

#==============================================================================
# FIREWALL RULES
#==============================================================================

variable "firewall_rules" {
  description = "Map of firewall rules to create"
  type = map(object({
    zone_id           = string
    description       = string
    filter_expression = string
    action            = string
    priority          = optional(number, null)
    paused            = optional(bool, false)
  }))
  default = {}
}

#==============================================================================
# ACCESS CONFIGURATION
#==============================================================================

variable "access_applications" {
  description = "Map of Cloudflare Access applications"
  type = map(object({
    zone_id                   = optional(string, null)
    account_id                = optional(string, null)
    name                      = string
    domain                    = string
    type                      = optional(string, "self_hosted")
    session_duration          = optional(string, "24h")
    auto_redirect_to_identity = optional(bool, false)
    allowed_idps              = optional(list(string), [])
  }))
  default = {}
}

#==============================================================================
# WORKERS
#==============================================================================

variable "workers" {
  description = "Map of Cloudflare Workers to deploy. WARNING: secret_text_bindings will store secrets in Terraform state. Consider using wrangler secret put instead."
  type = map(object({
    name    = string
    content = string
    routes = optional(list(object({
      zone_id = string
      pattern = string
    })), [])
    kv_namespaces = optional(list(object({
      binding = string
      id      = string
    })), [])
    plain_text_bindings = optional(list(object({
      name = string
      text = string
    })), [])
    secret_text_bindings = optional(list(object({
      name = string
      text = string
    })), [])
  }))
  default = {}
}

#==============================================================================
# SSL/TLS CONFIGURATION
#==============================================================================

variable "ssl_settings" {
  description = "SSL/TLS settings per zone"
  type = map(object({
    zone_id                  = string
    ssl_mode                 = optional(string, "full")
    min_tls_version          = optional(string, "1.2")
    always_use_https         = optional(bool, true)
    automatic_https_rewrites = optional(bool, true)
  }))
  default = {}
}

#==============================================================================
# CACHE CONFIGURATION
#==============================================================================

variable "cache_settings" {
  description = "Cache settings per zone"
  type = map(object({
    zone_id          = string
    cache_level      = optional(string, "aggressive")
    browser_ttl      = optional(number, 14400)
    development_mode = optional(bool, false)
  }))
  default = {}
}

#==============================================================================
# CUSTOM TAGS
#==============================================================================

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    managed_by = "terraform"
    action     = "tf-cf-action"
  }
}
