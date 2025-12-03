# Contributing to Terraform Cloudflare Action

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## Development Setup

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/your-username/tf-cf-action.git
   cd tf-cf-action
   ```

2. **Ensure you have the required tools**
   - Bash 4.0 or higher
   - ShellCheck for linting bash scripts
   - Terraform 1.0 or higher (for testing)

## Code Standards

### Bash Scripts

- Follow the existing code style
- Use `set -euo pipefail` at the start of scripts
- Run ShellCheck before committing:
  ```bash
  shellcheck scripts/entrypoint.sh
  ```
- Add comments for complex logic
- Use meaningful variable names
- Keep functions focused and single-purpose

### Terraform Configuration

- Use 2-space indentation
- Add comments explaining resource purposes
- Include validation blocks for variables where appropriate
- Follow HashiCorp's Terraform style guide
- Format code with `terraform fmt`:
  ```bash
  terraform fmt -recursive terraform/
  ```

### Documentation

- Keep README.md up to date with new features
- Add inline comments for complex logic
- Update examples when changing behavior
- Document breaking changes clearly

## Pull Request Process

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Write clear, focused commits
   - Follow the existing code style
   - Add tests if applicable

3. **Verify your changes**
   ```bash
   # Lint bash scripts
   shellcheck scripts/entrypoint.sh
   
   # Format Terraform files
   terraform fmt -recursive terraform/
   
   # Validate Terraform configuration
   cd terraform && terraform validate
   ```

4. **Submit a pull request**
   - Provide a clear description of changes
   - Reference any related issues
   - Ensure all checks pass

## Commit Message Guidelines

- Use clear, descriptive commit messages
- Start with a verb in present tense (e.g., "Add", "Fix", "Update")
- Keep the first line under 72 characters
- Add details in the commit body if needed

Examples:
```
Add support for worker KV namespaces

- Add kv_namespace_binding support to worker resources
- Update documentation with KV namespace examples
- Add validation for namespace IDs
```

## Reporting Issues

When reporting issues, please include:

- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, Terraform version, etc.)
- Relevant logs or error messages

## Security Issues

For security vulnerabilities, please email the maintainers directly instead of creating a public issue.

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on what's best for the project
- Be patient with new contributors

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
