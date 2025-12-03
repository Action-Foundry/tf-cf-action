# Security Policy

## Reporting Security Vulnerabilities

We take security seriously. If you discover a security vulnerability, please follow these steps:

1. **Do NOT** create a public GitHub issue
2. Email the maintainers privately with details
3. Include steps to reproduce the vulnerability
4. Allow time for the issue to be addressed before public disclosure

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| < 1.0   | :x:                |

## Security Best Practices

### When Using This Action

1. **Secrets Management**
   - Always use GitHub Secrets for API tokens and account IDs
   - Never commit credentials to version control
   - Rotate API tokens regularly
   - Use tokens with minimal required permissions

2. **API Token Permissions**
   Create Cloudflare API tokens with only the permissions you need:
   - Zone:Read, Zone:Edit (for zone management)
   - DNS:Read, DNS:Edit (for DNS records)
   - Page Rules:Edit (for page rules)
   - Firewall Services:Edit (for firewall rules)
   - Workers Scripts:Edit (for Workers deployment)

3. **State File Security**
   - Use remote state backends with encryption
   - Enable state file versioning
   - Restrict access to state files
   - Never commit state files to version control

4. **Workflow Security**
   - Use GitHub Environments with required reviewers for production
   - Enable destroy_protection for production environments
   - Review all changes before applying
   - Use branch protection rules

5. **Worker Secrets**
   - **NEVER** use `secret_text_bindings` in production
   - Secrets in Terraform state are stored in plain text
   - Use Wrangler CLI or Cloudflare Dashboard for secrets:
     ```bash
     wrangler secret put SECRET_NAME
     ```

### Infrastructure Security

1. **SSL/TLS Configuration**
   - Use "strict" or "full (strict)" SSL mode
   - Set minimum TLS version to 1.2 or higher
   - Enable automatic HTTPS rewrites

2. **Firewall Rules**
   - Implement rate limiting
   - Block known bad bots
   - Use challenge for suspicious requests
   - Allow known good IPs explicitly

3. **DNS Security**
   - Enable DNSSEC where possible
   - Use CAA records to control certificate issuance
   - Implement SPF, DKIM, and DMARC for email security

## Known Security Considerations

### Terraform State

Terraform state files contain:
- All resource configurations
- Sensitive data from outputs
- Secret values if stored in state

**Mitigation:**
- Use encrypted remote backends (S3 with encryption, Terraform Cloud)
- Limit access to state files
- Audit state file access regularly

### GitHub Actions Logs

Workflow logs may contain:
- Plan outputs showing resource changes
- Error messages with configuration details

**Mitigation:**
- Avoid logging sensitive values
- The action masks sensitive inputs automatically
- Review logs before making them public

## Compliance

This action follows these security standards:

- **Principle of Least Privilege**: Request only necessary permissions
- **Defense in Depth**: Multiple layers of protection (destroy protection, drift detection, validation)
- **Fail Secure**: Errors prevent destructive actions from proceeding
- **Audit Trail**: All actions are logged in GitHub Actions

## Updates and Patches

- Security patches are released as soon as possible
- Subscribe to repository releases for notifications
- Review changelog for security-related updates
- Test updates in non-production environments first

## Resources

- [Cloudflare API Token Best Practices](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)
- [GitHub Actions Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [Terraform Security Best Practices](https://developer.hashicorp.com/terraform/tutorials/configuration-language/sensitive-variables)
