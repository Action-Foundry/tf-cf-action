# Example: Worker Deployment
# This example demonstrates Cloudflare Workers configuration
#
# Usage:
# 1. Copy this file to your terraform directory
# 2. Replace YOUR_ZONE_ID with actual zone ID
# 3. Customize worker scripts for your use case
# 4. Run: terraform plan -var-file=workers.tfvars
#
# SECURITY NOTE:
# Do NOT use secret_text_bindings for production secrets!
# Secrets stored in Terraform state are NOT encrypted.
# Use Wrangler CLI or Cloudflare Dashboard to set secrets securely.

# Workers
workers = {
  "redirect-worker" = {
    name    = "redirect-worker"
    content = <<-EOT
      addEventListener('fetch', event => {
        event.respondWith(handleRequest(event.request))
      })

      async function handleRequest(request) {
        const url = new URL(request.url)
        
        // Example: Redirect old paths to new paths
        const redirects = {
          '/old-page': '/new-page',
          '/blog': '/articles'
        }
        
        if (redirects[url.pathname]) {
          return Response.redirect(url.origin + redirects[url.pathname], 301)
        }
        
        return fetch(request)
      }
    EOT
    routes = [
      {
        zone_id = "YOUR_ZONE_ID"
        pattern = "example.com/old-*"
      }
    ]
    plain_text_bindings = []
    kv_namespaces       = []
    secret_text_bindings = []
  }

  "api-worker" = {
    name    = "api-gateway-worker"
    content = <<-EOT
      addEventListener('fetch', event => {
        event.respondWith(handleRequest(event.request))
      })

      async function handleRequest(request) {
        const url = new URL(request.url)
        
        // Add CORS headers
        const corsHeaders = {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization'
        }
        
        // Handle preflight
        if (request.method === 'OPTIONS') {
          return new Response(null, { headers: corsHeaders })
        }
        
        // Forward to origin with modifications
        const response = await fetch(request)
        const newResponse = new Response(response.body, response)
        
        Object.entries(corsHeaders).forEach(([key, value]) => {
          newResponse.headers.set(key, value)
        })
        
        return newResponse
      }
    EOT
    routes = [
      {
        zone_id = "YOUR_ZONE_ID"
        pattern = "api.example.com/*"
      }
    ]
    plain_text_bindings = [
      {
        name = "API_VERSION"
        text = "v1"
      }
    ]
    kv_namespaces       = []
    secret_text_bindings = []
  }
}
