# Cloudflare Resource Definitions
# Following DRY principles with dynamic resource creation

#==============================================================================
# ZONE RESOURCES
#==============================================================================

resource "cloudflare_zone" "zones" {
  for_each = var.zones

  account_id = var.cloudflare_account_id
  zone       = each.value.zone_name
  plan       = each.value.plan
  paused     = each.value.paused
  jump_start = each.value.jump_start
  type       = each.value.type
  
  # Lifecycle to prevent accidental deletion of zones
  lifecycle {
    prevent_destroy = false  # Set to true in production to prevent accidental zone deletion
  }
}

#==============================================================================
# DNS RECORDS
#==============================================================================

resource "cloudflare_record" "dns_records" {
  for_each = var.dns_records

  zone_id  = each.value.zone_id
  name     = each.value.name
  type     = each.value.type
  content  = each.value.content
  priority = each.value.priority
  proxied  = each.value.proxied
  ttl      = each.value.proxied ? 1 : each.value.ttl  # Auto TTL when proxied
  comment  = each.value.comment
  tags     = each.value.tags

  # Dynamic block for SRV, CAA, and other records requiring structured data
  dynamic "data" {
    for_each = each.value.data != null ? [each.value.data] : []
    content {
      # SRV record data
      service = lookup(data.value, "service", null)
      proto   = lookup(data.value, "proto", null)
      name    = lookup(data.value, "name", null)
      weight  = lookup(data.value, "weight", null)
      port    = lookup(data.value, "port", null)
      target  = lookup(data.value, "target", null)
    }
  }
}

#==============================================================================
# PAGE RULES
#==============================================================================

resource "cloudflare_page_rule" "page_rules" {
  for_each = var.page_rules

  zone_id  = each.value.zone_id
  target   = each.value.target
  priority = each.value.priority
  status   = each.value.status

  actions {
    # Forwarding URL action (conditional)
    # Used for redirects (301/302)
    dynamic "forwarding_url" {
      for_each = lookup(each.value.actions, "forwarding_url", null) != null ? [1] : []
      content {
        url         = lookup(each.value.actions, "forwarding_url", null)
        status_code = lookup(each.value.actions, "forwarding_status_code", 301)
      }
    }

    # Cache and performance settings
    cache_level              = lookup(each.value.actions, "cache_level", null)
    browser_cache_ttl        = lookup(each.value.actions, "browser_cache_ttl", null)
    edge_cache_ttl           = lookup(each.value.actions, "edge_cache_ttl", null)
    always_use_https         = lookup(each.value.actions, "always_use_https", null)
    automatic_https_rewrites = lookup(each.value.actions, "automatic_https_rewrites", null)
    ssl                      = lookup(each.value.actions, "ssl", null)
    security_level           = lookup(each.value.actions, "security_level", null)
    rocket_loader            = lookup(each.value.actions, "rocket_loader", null)

    # Minify action (conditional)
    # Reduces file sizes for HTML, CSS, and JavaScript
    dynamic "minify" {
      for_each = (
        lookup(each.value.actions, "minify_html", null) != null ||
        lookup(each.value.actions, "minify_css", null) != null ||
        lookup(each.value.actions, "minify_js", null) != null
      ) ? [1] : []
      content {
        html = lookup(each.value.actions, "minify_html", "off")
        css  = lookup(each.value.actions, "minify_css", "off")
        js   = lookup(each.value.actions, "minify_js", "off")
      }
    }
  }
}

#==============================================================================
# CUSTOM FIREWALL RULES (Using modern Rulesets API)
#==============================================================================

resource "cloudflare_ruleset" "custom_firewall" {
  for_each = {
    for zone_id in distinct([for k, v in var.firewall_rules : v.zone_id]) : zone_id => {
      zone_id = zone_id
      rules = [
        for k, v in var.firewall_rules : {
          key               = k
          description       = v.description
          filter_expression = v.filter_expression
          action            = v.action
          enabled           = !v.paused
        } if v.zone_id == zone_id
      ]
    }
  }

  zone_id     = each.value.zone_id
  name        = "Custom Firewall Rules"
  description = "Managed by Terraform Cloudflare Action"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  dynamic "rules" {
    for_each = each.value.rules
    content {
      action      = rules.value.action
      expression  = rules.value.filter_expression
      description = rules.value.description
      enabled     = rules.value.enabled
    }
  }
}

#==============================================================================
# ACCESS APPLICATIONS (Zero Trust)
#==============================================================================

resource "cloudflare_zero_trust_access_application" "access_apps" {
  for_each = var.access_applications

  zone_id                   = each.value.zone_id
  account_id                = each.value.account_id != null ? each.value.account_id : var.cloudflare_account_id
  name                      = each.value.name
  domain                    = each.value.domain
  type                      = each.value.type
  session_duration          = each.value.session_duration
  auto_redirect_to_identity = each.value.auto_redirect_to_identity
  allowed_idps              = each.value.allowed_idps
}

#==============================================================================
# WORKERS
#==============================================================================

resource "cloudflare_workers_script" "workers" {
  for_each = var.workers

  account_id = var.cloudflare_account_id
  name       = each.value.name
  content    = each.value.content

  dynamic "kv_namespace_binding" {
    for_each = each.value.kv_namespaces
    content {
      name         = kv_namespace_binding.value.binding
      namespace_id = kv_namespace_binding.value.id
    }
  }

  dynamic "plain_text_binding" {
    for_each = each.value.plain_text_bindings
    content {
      name = plain_text_binding.value.name
      text = plain_text_binding.value.text
    }
  }

  # SECURITY WARNING: secret_text_binding stores secrets in Terraform state in plain text!
  # This is NOT recommended for production use.
  # Instead, use one of these secure alternatives:
  # 1. Wrangler CLI: `wrangler secret put SECRET_NAME`
  # 2. Cloudflare Dashboard: Workers & Pages > Your Worker > Settings > Variables
  # 3. Cloudflare API: https://developers.cloudflare.com/workers/configuration/secrets/
  # Only use this for development/testing with non-sensitive dummy values.
  dynamic "secret_text_binding" {
    for_each = each.value.secret_text_bindings
    content {
      name = secret_text_binding.value.name
      text = secret_text_binding.value.text
    }
  }
}

resource "cloudflare_workers_route" "worker_routes" {
  for_each = {
    for item in flatten([
      for worker_key, worker in var.workers : [
        for route_idx, route in worker.routes : {
          key         = "${worker_key}-${route_idx}"
          zone_id     = route.zone_id
          pattern     = route.pattern
          script_name = worker.name
        }
      ]
    ]) : item.key => item
  }

  zone_id     = each.value.zone_id
  pattern     = each.value.pattern
  script_name = each.value.script_name
}

#==============================================================================
# SSL/TLS SETTINGS
#==============================================================================

resource "cloudflare_zone_settings_override" "ssl_settings" {
  for_each = var.ssl_settings

  zone_id = each.value.zone_id

  settings {
    ssl                      = each.value.ssl_mode
    min_tls_version          = each.value.min_tls_version
    always_use_https         = each.value.always_use_https ? "on" : "off"
    automatic_https_rewrites = each.value.automatic_https_rewrites ? "on" : "off"
  }
}

#==============================================================================
# CACHE SETTINGS
#==============================================================================

resource "cloudflare_zone_settings_override" "cache_settings" {
  for_each = var.cache_settings

  zone_id = each.value.zone_id

  settings {
    cache_level       = each.value.cache_level
    browser_cache_ttl = each.value.browser_ttl
    development_mode  = each.value.development_mode ? "on" : "off"
  }
}
