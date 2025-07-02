# 🔔 Claude Code Slack Notifier

<p align="center">
  <img src="https://img.shields.io/badge/Claude_Code-Compatible-blue?style=for-the-badge" alt="Claude Code Compatible">
  <img src="https://img.shields.io/badge/Slack-Integration-4A154B?style=for-the-badge&logo=slack" alt="Slack Integration">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="MIT License">
</p>

<p align="center">
  <b>Get real-time Slack notifications from Claude Code - Never miss a permission request again!</b>
</p>

<p align="center">
  <img src="docs/demo.gif" alt="Demo" width="600">
</p>

## 🌟 Features

- 🔔 **Real-time Permission Notifications** - Get notified when Claude needs your approval
- ✅ **Work Completion Summaries** - Detailed reports of what Claude accomplished
- 🚨 **Dangerous Command Alerts** - Special warnings for risky operations
- 📊 **Work Statistics** - Track commands executed, files modified, and more
- 🎨 **Rich Slack Messages** - Beautiful, informative notifications with context
- 🔧 **Highly Customizable** - Filter notifications, set up multiple channels, and more
- 🌍 **Multi-language Support** - Works with any language (Korean examples included!)

## 📸 Screenshots

<table>
  <tr>
    <td><img src="docs/permission-request.png" alt="Permission Request" width="400"></td>
    <td><img src="docs/work-complete.png" alt="Work Complete" width="400"></td>
  </tr>
  <tr>
    <td align="center"><b>Permission Request</b></td>
    <td align="center"><b>Work Completion</b></td>
  </tr>
</table>

## 🚀 Quick Start

### Prerequisites

- Claude Code installed and authenticated
- A Slack workspace with webhook permissions
- macOS, Linux, or Windows (via WSL)

### 1. One-Line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/bartkim0426/claude-code-slack-notifier/main/install.sh | bash
```

### 2. Configure Slack Webhook

```bash
# Open configuration
claude-slack-config

# Add your webhook URL:
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

### 3. Done! 🎉

Claude Code will now send notifications to your Slack channel.

## 📖 Detailed Setup Guide

### Getting a Slack Webhook URL

1. Go to [Slack App Directory](https://api.slack.com/apps)
2. Click "Create New App" → "From scratch"
3. Name your app (e.g., "Claude Notifier") and select workspace
4. Go to "Incoming Webhooks" → Enable → "Add New Webhook"
5. Select a channel and copy the webhook URL

### Manual Installation

If you prefer to install manually:

```bash
# Clone the repository
git clone https://github.com/bartkim0426/claude-code-slack-notifier.git
cd claude-code-slack-notifier

# Run setup
./setup.sh

# Configure
vim ~/.claude-slack-notifier/config
```

### Verifying Installation

```bash
# Check installation status
claude-slack-doctor

# Output:
# ✓ Installation directory exists
# ✓ Configuration file found
# ✓ Slack webhook configured
# ✓ Hooks registered in Claude Code
```

## ⚙️ Configuration

### Basic Configuration

Edit `~/.claude-slack-notifier/config`:

```bash
# Slack webhook URL (required)
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Notification toggles
NOTIFY_PERMISSIONS=true    # Permission request notifications
NOTIFY_COMPLETION=true     # Work completion notifications
NOTIFY_ERRORS=true         # Error notifications
NOTIFY_IDLE=false         # Idle status notifications

# Advanced options
DEBUG_MODE=false          # Enable debug logging
NOTIFICATION_LANG=en      # Language (en, ko, ja, etc.)
```

### Project-Specific Channels

Route notifications to different channels based on project:

```json
// ~/.claude-slack-notifier/channel-map.json
{
  "frontend-*": "https://hooks.slack.com/services/FRONTEND/WEBHOOK",
  "backend-*": "https://hooks.slack.com/services/BACKEND/WEBHOOK",
  "ml-*": "https://hooks.slack.com/services/ML_TEAM/WEBHOOK",
  "default": "https://hooks.slack.com/services/GENERAL/WEBHOOK"
}
```

### Notification Filters

Control which actions trigger notifications:

```json
// ~/.claude-slack-notifier/filters.json
{
  "ignore_commands": [
    "ls", "pwd", "echo", "cat"
  ],
  "alert_commands": [
    "rm -rf", "sudo", "chmod 777", "curl", "wget"
  ],
  "ignore_paths": [
    "node_modules/*",
    "*.log",
    ".git/*"
  ],
  "alert_paths": [
    ".env*",
    "config/*",
    "secrets/*"
  ]
}
```

## 🎨 Customization

### Custom Notification Templates

Create custom message templates:

```bash
# ~/.claude-slack-notifier/templates/custom-permission.json
{
  "text": "🤖 Claude needs your attention!",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Project:* {{project}}\n*Action:* {{action}}\n*Details:* {{details}}"
      }
    }
  ]
}
```

### Adding New Hook Types

1. Create a new hook script:
```bash
# ~/.claude-slack-notifier/hooks/custom-hook.sh
#!/bin/bash
source "$HOME/.claude-slack-notifier/hooks/base-hook.sh"

# Your custom logic here
```

2. Register in Claude Code:
```bash
/hooks
# Select hook type
# Add: ~/.claude-slack-notifier/hooks/custom-hook.sh
```

## 📚 Advanced Usage

### Team Deployment

Deploy to your entire team:

```bash
# Export team configuration
claude-slack-export > team-config.json

# Team members import
claude-slack-import team-config.json
```

### CI/CD Integration

Add to your CI pipeline:

```yaml
# .github/workflows/notify.yml
- name: Notify Claude Code Status
  run: |
    echo '{"text":"Deployment started by Claude Code"}' | \
    curl -X POST -H 'Content-type: application/json' \
    --data @- ${{ secrets.SLACK_WEBHOOK }}
```

### Webhook Proxy

For enhanced security, use a webhook proxy:

```bash
# ~/.claude-slack-notifier/config
WEBHOOK_PROXY="https://your-proxy.com/slack"
WEBHOOK_TOKEN="your-secret-token"
```

## 🛠️ Troubleshooting

### Common Issues

<details>
<summary><b>Notifications not working</b></summary>

1. Check webhook URL:
   ```bash
   claude-slack-test
   ```

2. Verify hooks are registered:
   ```bash
   cat ~/.claude/settings.json | jq '.hooks'
   ```

3. Check logs:
   ```bash
   tail -f ~/.claude-slack-notifier/logs/debug.log
   ```
</details>

<details>
<summary><b>Duplicate notifications</b></summary>

1. Check for multiple hook registrations:
   ```bash
   /hooks
   ```

2. Clean and reinstall:
   ```bash
   claude-slack-clean
   claude-slack-reinstall
   ```
</details>

<details>
<summary><b>Permission denied errors</b></summary>

```bash
# Fix permissions
chmod +x ~/.claude-slack-notifier/hooks/*.sh
```
</details>

### Debug Mode

Enable detailed logging:

```bash
# In config file
DEBUG_MODE=true

# View logs
tail -f ~/.claude-slack-notifier/logs/debug.log
```

## 🔧 Utilities

### Available Commands

- `claude-slack-config` - Edit configuration
- `claude-slack-doctor` - Check installation health
- `claude-slack-test` - Send test notification
- `claude-slack-update` - Update to latest version
- `claude-slack-uninstall` - Remove completely
- `claude-slack-export` - Export configuration
- `claude-slack-import` - Import configuration

### API

Use the notifier programmatically:

```bash
# Send custom notification
claude-slack-send "Custom message" "info"

# With JSON payload
echo '{"text":"Hello from script!"}' | claude-slack-send --json
```

## 🌐 Internationalization

Supports multiple languages out of the box:

```bash
# ~/.claude-slack-notifier/config
NOTIFICATION_LANG=ko  # Korean
NOTIFICATION_LANG=ja  # Japanese
NOTIFICATION_LANG=zh  # Chinese
```

## 🤝 Contributing

We love contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup

```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/claude-code-slack-notifier.git
cd claude-code-slack-notifier

# Create feature branch
git checkout -b feature/amazing-feature

# Make changes and test
./test.sh

# Commit and push
git commit -m "Add amazing feature"
git push origin feature/amazing-feature
```

## 📊 Performance

- **Lightweight**: < 100KB total size
- **Fast**: < 50ms notification latency
- **Efficient**: Minimal CPU/memory usage
- **Reliable**: Automatic retry with exponential backoff

## 🔒 Security

- Webhook URLs stored locally only
- No external dependencies (except `curl` and `jq`)
- No telemetry or data collection
- Optional webhook proxy support
- Supports secret rotation

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with ❤️ for the Claude Code community
- Inspired by developers who love automation
- Special thanks to all contributors

## 🔗 Links

- [Report Issues](https://github.com/bartkim0426/claude-code-slack-notifier/issues)
- [Request Features](https://github.com/bartkim0426/claude-code-slack-notifier/issues/new?labels=enhancement)
- [Discussions](https://github.com/bartkim0426/claude-code-slack-notifier/discussions)
- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)

---

<p align="center">
  Made with ☕ and 🎵 by developers, for developers
</p>

<p align="center">
  <a href="https://github.com/bartkim0426/claude-code-slack-notifier/stargazers">⭐ Star us on GitHub!</a>
</p>