#!/bin/bash

# 설정 파일 로드
CONFIG_FILE="$HOME/.claude-slack-notifier/config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Webhook URL 확인
if [ -z "$SLACK_WEBHOOK_URL" ]; then
    echo "Error: SLACK_WEBHOOK_URL not configured"
    exit 1
fi

# 테스트 메시지 전송
JSON_PAYLOAD=$(cat <<EOF
{
    "text": "🧪 Claude Slack Notifier 테스트 메시지",
    "blocks": [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "✅ *테스트 성공!*\n\nClaude Slack Notifier가 정상적으로 작동하고 있습니다."
            }
        },
        {
            "type": "context",
            "elements": [
                {
                    "type": "mrkdwn",
                    "text": "📍 프로젝트: \`claude-slack-notifier\`"
                },
                {
                    "type": "mrkdwn",
                    "text": "🕐 시간: $(date '+%Y-%m-%d %H:%M:%S')"
                }
            ]
        }
    ]
}
EOF
)

# Slack으로 전송
echo "Sending test message to Slack..."
curl -s -X POST -H 'Content-type: application/json' \
    --data "$JSON_PAYLOAD" \
    "$SLACK_WEBHOOK_URL"

if [ $? -eq 0 ]; then
    echo -e "\n✅ Test message sent successfully!"
else
    echo -e "\n❌ Failed to send test message"
fi