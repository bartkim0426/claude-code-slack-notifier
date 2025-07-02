#!/bin/bash

# Claude Code Notification Handler
# Notification Hook에서 호출하는 스크립트

WEBHOOK_URL="https://hooks.slack.com/services/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"

# 입력 JSON 읽기
INPUT=$(cat)

# 프로젝트 정보
PROJECT_NAME=$(basename "$PWD")
CURRENT_TIME=$(date "+%H:%M:%S")
FULL_TIME=$(date "+%Y-%m-%d %H:%M:%S")

# notification_type 추출
NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
MESSAGE=$(echo "$INPUT" | jq -r '.message // "No message"')

# notification_type에 따라 다른 처리
case "$NOTIFICATION_TYPE" in
    "permission_request")
        # 권한 요청 - 가장 중요한 알림
        SLACK_JSON=$(cat <<EOF
{
    "text": "⏸️ Claude Code가 승인을 기다리고 있습니다!",
    "blocks": [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": "🔔 승인 요청",
                "emoji": true
            }
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*요청 내용:*\n${MESSAGE}"
            }
        },
        {
            "type": "section",
            "fields": [
                {
                    "type": "mrkdwn",
                    "text": "*프로젝트:*\n${PROJECT_NAME}"
                },
                {
                    "type": "mrkdwn",
                    "text": "*시간:*\n${CURRENT_TIME}"
                }
            ]
        },
        {
            "type": "divider"
        },
        {
            "type": "context",
            "elements": [
                {
                    "type": "mrkdwn",
                    "text": "💡 터미널로 돌아가서 응답해주세요"
                }
            ]
        }
    ]
}
EOF
)
        ;;
    
    "idle")
        # 대기 중 알림 (선택적 - 너무 자주 올 수 있음)
        # 원하지 않으면 이 케이스를 주석처리
        SLACK_JSON=$(cat <<EOF
{
    "text": "💤 Claude Code가 대기 중입니다",
    "blocks": [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*Claude Code가 입력을 기다리고 있습니다*"
            }
        },
        {
            "type": "context",
            "elements": [
                {
                    "type": "mrkdwn",
                    "text": "프로젝트: ${PROJECT_NAME} | ${CURRENT_TIME}"
                }
            ]
        }
    ]
}
EOF
)
        ;;
    
    *)
        # 기타 알림 타입
        SLACK_JSON=$(cat <<EOF
{
    "text": "📢 Claude Code 알림",
    "blocks": [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*알림 타입:* ${NOTIFICATION_TYPE}\n*메시지:* ${MESSAGE}"
            }
        },
        {
            "type": "context",
            "elements": [
                {
                    "type": "mrkdwn",
                    "text": "${PROJECT_NAME} | ${FULL_TIME}"
                }
            ]
        }
    ]
}
EOF
)
        ;;
esac

# Slack으로 전송
if [ -n "$SLACK_JSON" ]; then
    echo "$SLACK_JSON" | curl -X POST -H 'Content-type: application/json' --data @- "$WEBHOOK_URL" >/dev/null 2>&1
fi

# 성공 종료
exit 0
