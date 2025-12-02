# Terraform Outputs for Cloudflare Resources
# Provides useful information after resource creation

#==============================================================================
# ZONE OUTPUTS
#==============================================================================

output "zone_ids" {
  description = "Map of zone names to their IDs"
  value = {
    for k, zone in cloudflare_zone.zones : k => zone.id
  }
}

output "zone_name_servers" {
  description = "Map of zone names to their assigned name servers"
  value = {
    for k, zone in cloudflare_zone.zones : k => zone.name_servers
  }
}

#==============================================================================
# DNS RECORD OUTPUTS
#==============================================================================

output "dns_record_ids" {
  description = "Map of DNS record names to their IDs"
  value = {
    for k, record in cloudflare_record.dns_records : k => record.id
  }
}

output "dns_record_hostnames" {
  description = "Map of DNS record names to their fully qualified hostnames"
  value = {
    for k, record in cloudflare_record.dns_records : k => record.hostname
  }
}

#==============================================================================
# WORKER OUTPUTS
#==============================================================================

output "worker_script_names" {
  description = "Map of worker keys to their script names"
  value = {
    for k, worker in cloudflare_workers_script.workers : k => worker.name
  }
}

#==============================================================================
# ACCESS APPLICATION OUTPUTS
#==============================================================================

output "access_application_ids" {
  description = "Map of access application names to their IDs"
  value = {
    for k, app in cloudflare_zero_trust_access_application.access_apps : k => app.id
  }
}

#==============================================================================
# SUMMARY OUTPUT
#==============================================================================

output "resource_summary" {
  description = "Summary of all managed resources"
  value = {
    zones_count             = length(cloudflare_zone.zones)
    dns_records_count       = length(cloudflare_record.dns_records)
    workers_count           = length(cloudflare_workers_script.workers)
    access_apps_count       = length(cloudflare_zero_trust_access_application.access_apps)
    page_rules_count        = length(cloudflare_page_rule.page_rules)
    firewall_rulesets_count = length(cloudflare_ruleset.custom_firewall)
  }
}
