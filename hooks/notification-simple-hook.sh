#!/bin/bash

# Claude Code Notification Hook - 심플 버전
# 요청 내용을 간결하게 표시

WEBHOOK_URL="https://hooks.slack.com/services/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"

# 입력 받기
INPUT=$(cat)

# 기본 정보
PROJECT=$(basename "$PWD")
TIME=$(date "+%H:%M")

# 파싱
TYPE=$(echo "$INPUT" | jq -r '.notification_type // ""')
MSG=$(echo "$INPUT" | jq -r '.message // ""')

# permission_request만 처리 (idle은 무시)
if [ "$TYPE" != "permission_request" ]; then
    exit 0
fi

# 메시지에서 핵심 정보 추출
if echo "$MSG" | grep -q '`'; then
    # 백틱으로 감싼 내용 추출
    TARGET=$(echo "$MSG" | grep -oE '`[^`]+`' | head -1)
else
    # 없으면 메시지 일부
    TARGET="${MSG:0:100}..."
fi

# 작업 유형 판단
if echo "$MSG" | grep -qi "bash.*command"; then
    ICON="🔧"
    ACTION="명령어 실행"
elif echo "$MSG" | grep -qiE "(write|create|edit)"; then
    ICON="📝"
    ACTION="파일 수정"
elif echo "$MSG" | grep -qiE "(delete|remove)"; then
    ICON="🗑️"
    ACTION="삭제 작업"
elif echo "$MSG" | grep -qi "read"; then
    ICON="👁️"
    ACTION="파일 읽기"
else
    ICON="🔔"
    ACTION="권한 요청"
fi

# Slack 메시지
cat <<EOF | curl -s -X POST -H 'Content-type: application/json' --data @- "$WEBHOOK_URL"
{
    "blocks": [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*${ICON} Claude Code - ${ACTION}*\n${TARGET}"
            }
        },
        {
            "type": "context",
            "elements": [
                {
                    "type": "mrkdwn",
                    "text": "🕐 ${TIME} | 📁 ${PROJECT} | ⏸️ 터미널에서 응답 대기 중"
                }
            ]
        }
    ]
}
EOF

exit 0
