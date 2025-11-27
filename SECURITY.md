# Security Policy

## Supported Versions

We release patches for security vulnerabilities. Which versions are eligible for receiving such patches depends on the CVSS v3.0 Rating:

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |
| < Latest| :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability, please **do not** open a public issue. Instead, please report it privately.

### How to Report

Please email security concerns to: [Your Email Address]

Include the following information:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### What to Expect

- We will acknowledge receipt of your report within 48 hours
- We will provide a detailed response within 7 days
- We will keep you informed of the progress toward fixing the vulnerability
- We will notify you when the vulnerability has been fixed

### Security Best Practices

When using this script:

1. **Always review changes**: Use `--dry-run` before removing firewall rules
2. **Keep backups**: The script creates backups automatically, but keep additional backups
3. **Test in safe environment**: Test changes in a non-production environment first
4. **Review firewall rules**: Understand what rules will be removed before confirming
5. **Use root carefully**: Only run with sudo/root when necessary

### Known Security Considerations

- This script requires root privileges to modify firewall rules
- Always review what will be removed before confirming
- Backup files contain sensitive firewall configuration information
- The script does not validate firewall rule syntax beyond basic checks

## Security Updates

Security updates will be released as patches to the latest version. Please keep your copy of the script up to date.
