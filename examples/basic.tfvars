# Example: Basic Zone and DNS Record Configuration
# This example demonstrates how to set up a simple zone with DNS records

# Zone Configuration
zones = {
  "example-com" = {
    zone_name  = "example.com"
    plan       = "free"
    paused     = false
    jump_start = true
  }
}

# DNS Records
dns_records = {
  "root-a" = {
    zone_id = "YOUR_ZONE_ID"  # Replace after zone creation
    name    = "@"
    type    = "A"
    content = "192.0.2.1"
    proxied = true
    ttl     = 1  # Auto TTL when proxied
  }
  "www-cname" = {
    zone_id = "YOUR_ZONE_ID"
    name    = "www"
    type    = "CNAME"
    content = "example.com"
    proxied = true
    ttl     = 1
  }
  "mail-mx" = {
    zone_id  = "YOUR_ZONE_ID"
    name     = "@"
    type     = "MX"
    content  = "mail.example.com"
    priority = 10
    proxied  = false
    ttl      = 3600
  }
  "spf-txt" = {
    zone_id = "YOUR_ZONE_ID"
    name    = "@"
    type    = "TXT"
    content = "v=spf1 include:_spf.example.com ~all"
    proxied = false
    ttl     = 3600
  }
}
