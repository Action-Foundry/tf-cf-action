# Example: Basic Zone and DNS Record Configuration
# This example demonstrates how to set up a simple zone with DNS records
#
# Usage:
# 1. Copy this file to your terraform directory
# 2. Replace YOUR_ZONE_ID with actual zone ID after zone creation
# 3. Update IP addresses and domain names to match your infrastructure
# 4. Run: terraform plan -var-file=basic.tfvars

# Zone Configuration
zones = {
  "example-com" = {
    zone_name  = "example.com"
    plan       = "free"        # Options: free, pro, business, enterprise
    paused     = false         # Set to true to temporarily pause the zone
    jump_start = true          # Automatically scan for DNS records
  }
}

# DNS Records
dns_records = {
  # Root A record - Points domain to IP address
  "root-a" = {
    zone_id = "YOUR_ZONE_ID"  # Replace after zone creation
    name    = "@"              # @ represents root domain
    type    = "A"
    content = "192.0.2.1"      # Replace with your server IP
    proxied = true             # Enable Cloudflare proxy (orange cloud)
    ttl     = 1                # Auto TTL when proxied
  }
  
  # WWW subdomain - CNAME to root
  "www-cname" = {
    zone_id = "YOUR_ZONE_ID"
    name    = "www"
    type    = "CNAME"
    content = "example.com"
    proxied = true
    ttl     = 1
  }
  
  # Mail server - MX record (must not be proxied)
  "mail-mx" = {
    zone_id  = "YOUR_ZONE_ID"
    name     = "@"
    type     = "MX"
    content  = "mail.example.com"
    priority = 10              # Lower number = higher priority
    proxied  = false           # MX records cannot be proxied
    ttl      = 3600            # 1 hour
  }
  
  # SPF record - Email sender verification
  "spf-txt" = {
    zone_id = "YOUR_ZONE_ID"
    name    = "@"
    type    = "TXT"
    content = "v=spf1 include:_spf.example.com ~all"
    proxied = false            # TXT records cannot be proxied
    ttl     = 3600
  }
}
