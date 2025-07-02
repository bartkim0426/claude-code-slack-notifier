# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Code Slack Notifier is a bash-based integration tool that sends Slack notifications when Claude Code requests permissions or completes work. It consists of hook scripts that integrate with Claude Code's hook system to monitor and notify about Claude's activities.

## Architecture

The project is organized around:
- **Hook Scripts** (`/hooks/`): Core notification handlers that Claude Code calls
- **Installation Scripts** (`install.sh`): Automated setup that configures hooks in Claude Code settings
- **Utility Scripts** (`/scripts/`): Various helper scripts for debugging and analysis
- **Configuration** (`~/.claude-slack-notifier/config`): User-specific settings including Slack webhook URL

### Key Components

1. **notification-hook.sh**: Handles permission request notifications when Claude needs approval
2. **stop-hook.sh**: Sends work completion summaries when Claude finishes tasks
3. **base-hook.sh**: Shared utilities for Slack communication and configuration loading

## Development Commands

Since this is a bash script project without package.json, the main development tasks are:

```bash
# Run the installation script
./install.sh

# Test individual hooks manually
./hooks/notification-hook.sh < test-input.json
./hooks/stop-hook.sh < test-input.json

# Check script syntax
bash -n hooks/*.sh

# Make scripts executable
chmod +x hooks/*.sh scripts/*.sh
```

## Working with Hook Scripts

When modifying hook scripts:
1. The scripts expect JSON input via stdin from Claude Code
2. They parse the JSON using `jq` to extract notification data
3. Debug logs are written to `$HOME/claude-*.log` files
4. Slack messages use webhook URLs stored in config files

## Important Notes

- The webhook URL in the hooks is hardcoded and needs to be replaced with user configuration
- Scripts rely on `jq` for JSON parsing and `curl` for Slack API calls
- The project supports multi-language notifications (Korean examples included)
- Hook registration happens automatically via `install.sh` by modifying `~/.claude/settings.json`

## Testing Modifications

When testing changes:
1. Use the debug logs to verify input/output
2. Test with actual Claude Code sessions to ensure hook integration works
3. Verify Slack message formatting using the Slack API tester
4. Check that hooks don't create infinite loops (stop hook has protection)

## Configuration Structure

User configuration is stored in `~/.claude-slack-notifier/config`:
- `SLACK_WEBHOOK_URL`: The Slack incoming webhook URL
- `NOTIFY_PERMISSIONS`: Enable/disable permission notifications
- `NOTIFY_COMPLETION`: Enable/disable completion notifications
- `DEBUG_MODE`: Enable verbose logging