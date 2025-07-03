#!/bin/bash

# PreToolUse Hook - 위험한 작업 전 알림
# 특정 도구 사용 전에 Slack 알림 전송

WEBHOOK_URL="https://hooks.slack.com/services/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"

# 입력 받기
INPUT=$(cat)

# 도구 이름과 입력 추출
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')

# 프로젝트 정보
PROJECT_NAME=$(basename "$PWD")
CURRENT_TIME=$(date "+%H:%M:%S")

# 알림을 보낼지 결정
should_notify=false
message=""

case "$TOOL_NAME" in
    "Bash")
        # Bash 명령어 추출
        COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // ""')
        
        # 위험한 명령어 체크
        if echo "$COMMAND" | grep -qiE "(sudo|rm -rf|chmod 777|:>/|dd if=|mkfs|format)"; then
            should_notify=true
            message="⚠️ 위험한 명령어 실행 예정: $COMMAND"
        elif echo "$COMMAND" | grep -qiE "(npm install|pip install|apt-get|brew install)"; then
            should_notify=true
            message="📦 패키지 설치 예정: $COMMAND"
        fi
        ;;
    
    "Write"|"Edit")
        # 파일 경로 추출
        FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.path // .file // ""')
        
        # 중요 파일 체크
        if echo "$FILE_PATH" | grep -qiE "(\.env|config|secret|credential|production)"; then
            should_notify=true
            message="🔐 중요 파일 수정 예정: $FILE_PATH"
        fi
        ;;
esac

# Slack 알림 전송
if [ "$should_notify" = "true" ]; then
    SLACK_JSON=$(cat <<EOF
{
    "text": "🔔 Claude Code 작업 알림",
    "blocks": [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "$message"
            }
        },
        {
            "type": "context",
            "elements": [
                {
                    "type": "mrkdwn",
                    "text": "프로젝트: $PROJECT_NAME | $CURRENT_TIME | 도구: $TOOL_NAME"
                }
            ]
        }
    ]
}
EOF
)
    
    echo "$SLACK_JSON" | curl -s -X POST -H 'Content-type: application/json' --data @- "$WEBHOOK_URL" >/dev/null 2>&1
fi

# 항상 성공 반환 (작업은 계속 진행)
exit 0
