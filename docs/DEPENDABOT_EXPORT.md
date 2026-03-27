# Dependabot Alerts CSV Exporter

This script allows you to export Dependabot security alerts from the GitHub repository to a CSV file.

## Prerequisites

- Ruby (version 3.0 or higher)
- GitHub Personal Access Token with appropriate permissions

## Setup

### 1. Generate a GitHub Personal Access Token

To use this script, you need a GitHub Personal Access Token with the following scopes:

1. Go to [GitHub Settings > Personal Access Tokens](https://github.com/settings/tokens)
2. Click "Generate new token" (classic)
3. Give your token a descriptive name (e.g., "Dependabot Alerts Exporter")
4. Select the following scopes:
   - `repo` (Full control of private repositories)
   - `security_events` (Read and write security events)
5. Click "Generate token"
6. **Important:** Copy the token immediately (you won't be able to see it again)

## Usage

### Basic Usage

Run the script with your GitHub token:

```bash
ruby script/export_dependabot_alerts.rb --token YOUR_GITHUB_TOKEN
```

Or set the token as an environment variable:

```bash
export GITHUB_TOKEN=your_github_token_here
ruby script/export_dependabot_alerts.rb
```

This will create a file named `dependabot_alerts.csv` in the current directory.

### Advanced Options

```bash
ruby script/export_dependabot_alerts.rb [options]

Options:
  -o, --owner OWNER      GitHub repository owner (default: health-connector)
  -r, --repo REPO        GitHub repository name (default: enroll)
  -t, --token TOKEN      GitHub personal access token (required)
  -f, --file FILE        Output CSV file (default: dependabot_alerts.csv)
  -h, --help            Show help message
```

### Examples

Export alerts to a custom file:
```bash
ruby script/export_dependabot_alerts.rb -t YOUR_TOKEN -f my_alerts.csv
```

Export alerts from a different repository:
```bash
ruby script/export_dependabot_alerts.rb -t YOUR_TOKEN -o different-owner -r different-repo
```

## Output Format

The CSV file includes the following columns:

- **Number**: Alert number
- **State**: Current state (open, dismissed, fixed)
- **Severity**: Severity level (critical, high, medium, low)
- **Package**: Name of the vulnerable package
- **Ecosystem**: Package ecosystem (npm, pip, rubygems, etc.)
- **Vulnerable Version Range**: Range of affected versions
- **Fixed Version**: First version that fixes the vulnerability
- **CVE ID**: Common Vulnerabilities and Exposures identifier
- **GHSA ID**: GitHub Security Advisory identifier
- **Summary**: Brief description of the vulnerability
- **Description**: Detailed description
- **Created At**: When the alert was created
- **Updated At**: When the alert was last updated
- **Dismissed At**: When the alert was dismissed (if applicable)
- **Dismissed Reason**: Reason for dismissal (if applicable)
- **Dismissed Comment**: Comment on dismissal (if applicable)
- **URL**: Link to the alert on GitHub

## Filtering

By default, the script filters for:
- **State**: Open alerts only
- **Severity**: High and critical alerts only

To modify these filters, you can edit the `fetch_dependabot_alerts` method in the script and change the `params` hash.

## Troubleshooting

### Authentication Failed
- Verify your token is correct and hasn't expired
- Regenerate a new token if needed

### Access Forbidden (403)
- Ensure your token has the `security_events` scope
- Verify you have access to the repository

### Repository Not Found (404)
- Check that Dependabot alerts are enabled for the repository
- Verify the owner and repo names are correct
- Ensure you have the necessary permissions to view the repository

## Security Notes

- **Never commit your GitHub token to the repository**
- Store tokens securely (e.g., in environment variables or a password manager)
- Rotate tokens regularly
- Use tokens with the minimum required permissions

## Additional Resources

- [GitHub Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [GitHub REST API - Dependabot Alerts](https://docs.github.com/en/rest/dependabot/alerts)
- [Creating a Personal Access Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
