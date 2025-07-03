#!/bin/bash

# Load base hook functions
source ./hooks/base-hook.sh

# Create test message
test_message='{
    "text": "🧪 Claude Slack Notifier 테스트",
    "blocks": [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*테스트 알림*\n이 메시지가 보이면 Slack 연동이 정상적으로 작동하고 있습니다! ✅"
            }
        },
        {
            "type": "context",
            "elements": [
                {
                    "type": "mrkdwn",
                    "text": "테스트 시간: '"$(date '+%Y-%m-%d %H:%M:%S')"'"
                }
            ]
        }
    ]
}'

# Send test notification
echo "Sending test notification to Slack..."
send_to_slack "$test_message"

if [ $? -eq 0 ]; then
    echo "✅ Test notification sent successfully!"
else
    echo "❌ Failed to send test notification"
fi