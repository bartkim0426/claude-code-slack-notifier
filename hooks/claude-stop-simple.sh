#!/bin/bash

# Claude Code Stop Hook - 심플 버전
# 기본 정보만 포함하되 안정적으로 작동

WEBHOOK_URL="https://hooks.slack.com/services/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"

# 입력 JSON을 변수에 저장
INPUT=$(cat)

# 기본 정보
PROJECT_NAME=$(basename "$PWD")
CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")
SHORT_TIME=$(date "+%H:%M")

# 간단한 작업 요약 추출 시도
SUMMARY="작업이 완료되었습니다."

# stop_hook_active 체크 (무한 루프 방지)
IS_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$IS_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

# 가능한 경우 마지막 메시지 추출
if echo "$INPUT" | jq -e '.transcript' >/dev/null 2>&1; then
    LAST_MSG=$(echo "$INPUT" | jq -r '
        .transcript 
        | map(select(.type == "text" and .sender == "assistant")) 
        | last.text // empty
    ' 2>/dev/null | head -c 500)
    
    if [ -n "$LAST_MSG" ] && [ "$LAST_MSG" != "null" ]; then
        SUMMARY="$LAST_MSG"
    fi
fi

# 실행 시간 추출
ELAPSED=$(echo "$INPUT" | jq -r '.elapsed_time // ""' 2>/dev/null)
if [ -n "$ELAPSED" ] && [ "$ELAPSED" != "null" ]; then
    ELAPSED_TEXT="작업 시간: $ELAPSED"
else
    ELAPSED_TEXT="작업 완료"
fi

# Slack 메시지 전송
cat <<EOF | curl -s -X POST -H 'Content-type: application/json' --data @- "$WEBHOOK_URL"
{
    "blocks": [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": "✅ Claude Code 작업 완료",
                "emoji": true
            }
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*$PROJECT_NAME* 프로젝트에서 작업이 완료되었습니다."
            }
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "> $SUMMARY"
            }
        },
        {
            "type": "context",
            "elements": [
                {
                    "type": "mrkdwn",
                    "text": "🕐 $SHORT_TIME | 📁 $(pwd | sed "s|$HOME|~|") | ⏱️ $ELAPSED_TEXT"
                }
            ]
        }
    ]
}
EOF

exit 0
