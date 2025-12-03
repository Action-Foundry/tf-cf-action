# Example: Advanced Configuration with Page Rules and Firewall
# This example shows security-focused configuration
#
# Usage:
# 1. Copy this file to your terraform directory
# 2. Replace YOUR_ZONE_ID with actual zone ID
# 3. Customize security rules based on your requirements
# 4. Run: terraform plan -var-file=advanced.tfvars
#
# Security Best Practices:
# - Always use SSL/TLS strict mode or higher
# - Enable automatic HTTPS rewrites
# - Implement rate limiting and bot protection
# - Use firewall rules to block malicious traffic

# SSL/TLS Settings
ssl_settings = {
  "main-zone" = {
    zone_id           = "YOUR_ZONE_ID"
    ssl_mode          = "strict"
    min_tls_version   = "1.2"
    always_use_https  = true
    automatic_https_rewrites = true
  }
}

# Page Rules
page_rules = {
  "force-https" = {
    zone_id  = "YOUR_ZONE_ID"
    target   = "http://*.example.com/*"
    priority = 1
    status   = "active"
    actions = {
      always_use_https = true
    }
  }
  "cache-static" = {
    zone_id  = "YOUR_ZONE_ID"
    target   = "*.example.com/static/*"
    priority = 2
    status   = "active"
    actions = {
      cache_level       = "cache_everything"
      edge_cache_ttl    = 86400
      browser_cache_ttl = 14400
    }
  }
  "bypass-admin" = {
    zone_id  = "YOUR_ZONE_ID"
    target   = "*.example.com/admin/*"
    priority = 3
    status   = "active"
    actions = {
      cache_level    = "bypass"
      security_level = "high"
    }
  }
}

# Firewall Rules
firewall_rules = {
  "block-bad-bots" = {
    zone_id           = "YOUR_ZONE_ID"
    description       = "Block known bad bots"
    filter_expression = "(cf.client.bot) or (http.user_agent contains \"BadBot\")"
    action            = "block"
    priority          = 1
    paused            = false
  }
  "challenge-suspicious" = {
    zone_id           = "YOUR_ZONE_ID"
    description       = "Challenge suspicious requests"
    filter_expression = "(cf.threat_score gt 14)"
    action            = "challenge"
    priority          = 2
    paused            = false
  }
  "allow-known-ips" = {
    zone_id           = "YOUR_ZONE_ID"
    description       = "Allow known good IP ranges"
    filter_expression = "(ip.src in {192.0.2.0/24 198.51.100.0/24})"
    action            = "allow"
    priority          = 0
    paused            = false
  }
}

# Cache Settings
cache_settings = {
  "main-zone" = {
    zone_id        = "YOUR_ZONE_ID"
    cache_level    = "aggressive"
    browser_ttl    = 14400
    development_mode = false
  }
}
