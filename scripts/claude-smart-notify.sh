#!/bin/bash

# Smart Claude Code Notification Handler
# 중요한 알림만 필터링해서 전송

WEBHOOK_URL="https://hooks.slack.com/services/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"

# 입력 JSON 읽기
INPUT=$(cat)

# 기본 정보
PROJECT_NAME=$(basename "$PWD")
CURRENT_TIME=$(date "+%H:%M:%S")

# JSON 파싱
NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
MESSAGE=$(echo "$INPUT" | jq -r '.message // ""')

# 중요한 권한 요청만 필터링
should_notify=false
priority="normal"

# permission_request 타입 체크
if [ "$NOTIFICATION_TYPE" = "permission_request" ]; then
    # 메시지에 특정 키워드가 있는지 확인
    if echo "$MESSAGE" | grep -qiE "(delete|remove|rm |sudo|production|deploy|database|credential|secret|env)"; then
        priority="high"
        should_notify=true
    elif echo "$MESSAGE" | grep -qiE "(write|edit|modify|create|install|npm|yarn|git)"; then
        priority="medium"
        should_notify=true
    else
        priority="low"
        should_notify=true  # 모든 권한 요청은 기본적으로 알림
    fi
fi

# 알림 전송 여부 결정
if [ "$should_notify" = "true" ]; then
    # Priority에 따른 이모지
    case "$priority" in
        "high")
            EMOJI="🚨"
            COLOR="#ff0000"
            ;;
        "medium")
            EMOJI="⚠️"
            COLOR="#ff9900"
            ;;
        *)
            EMOJI="🔔"
            COLOR="#36a64f"
            ;;
    esac
    
    # Slack 메시지 생성
    SLACK_JSON=$(cat <<EOF
{
    "text": "${EMOJI} Claude Code 승인 요청 (${priority} 우선순위)",
    "attachments": [
        {
            "color": "${COLOR}",
            "blocks": [
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": "${EMOJI} 승인 필요",
                        "emoji": true
                    }
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*요청 내용:*\n\`\`\`${MESSAGE}\`\`\`"
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
                        },
                        {
                            "type": "mrkdwn",
                            "text": "*우선순위:*\n${priority}"
                        },
                        {
                            "type": "mrkdwn",
                            "text": "*디렉토리:*\n\`${PWD}\`"
                        }
                    ]
                }
            ]
        }
    ]
}
EOF
)
    
    # Slack 전송
    echo "$SLACK_JSON" | curl -s -X POST -H 'Content-type: application/json' --data @- "$WEBHOOK_URL" >/dev/null 2>&1
fi

exit 0
