# Contributing to Claude Code Slack Notifier

First off, thank you for considering contributing to Claude Code Slack Notifier! 🎉

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues as you might find out that you don't need to create one.

**How to Submit A Good Bug Report:**

* Use a clear and descriptive title
* Describe the exact steps to reproduce the problem
* Provide specific examples to demonstrate the steps
* Describe the behavior you observed and what behavior you expected
* Include logs from `~/.claude-slack-notifier/logs/`

### Suggesting Enhancements

* Use a clear and descriptive title
* Provide a step-by-step description of the suggested enhancement
* Provide specific examples to demonstrate the steps
* Explain why this enhancement would be useful

### Pull Requests

1. Fork the repo and create your branch from `main`
2. If you've added code that should be tested, add tests
3. Ensure the test suite passes
4. Make sure your code follows the existing style
5. Issue that pull request!

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/claude-code-slack-notifier.git
cd claude-code-slack-notifier

# Add upstream remote
git remote add upstream https://github.com/[original-username]/claude-code-slack-notifier.git

# Install development dependencies
./scripts/setup-dev.sh
```

## Style Guide

### Shell Script Style

* Use `#!/bin/bash` shebang
* Set `set -e` for error handling
* Use meaningful variable names in UPPER_CASE
* Add comments for complex logic
* Use functions for repeated code

### Commit Messages

* Use the present tense ("Add feature" not "Added feature")
* Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
* Limit the first line to 72 characters or less
* Reference issues and pull requests liberally after the first line

### Documentation

* Use Markdown for all documentation
* Include code examples where relevant
* Keep language clear and concise
* Update README.md if needed

## Testing

Run the test suite:

```bash
./test.sh
```

Add new tests for any new functionality:

```bash
# tests/test_new_feature.sh
#!/bin/bash
source ./tests/test_helper.sh

test_my_new_feature() {
    # Your test here
    assert_equals "expected" "actual"
}

run_test test_my_new_feature
```

## Release Process

1. Update version in relevant files
2. Update CHANGELOG.md
3. Create a pull request
4. After merge, tag the release
5. GitHub Actions will handle the rest

Thank you! 🙏