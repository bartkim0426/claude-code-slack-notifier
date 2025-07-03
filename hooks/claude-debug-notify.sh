#!/bin/bash

# Claude Notification Debug Script
# 이 스크립트로 어떤 데이터가 오는지 확인

LOG_FILE="$HOME/claude-notification-debug.log"

echo "=== Notification Hook Triggered at $(date) ===" >> "$LOG_FILE"
echo "PWD: $PWD" >> "$LOG_FILE"
echo "Input JSON:" >> "$LOG_FILE"

# 입력 JSON을 로그에 저장
INPUT=$(cat)
echo "$INPUT" | jq '.' >> "$LOG_FILE" 2>&1

# notification_type 확인
NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
echo "Notification Type: $NOTIFICATION_TYPE" >> "$LOG_FILE"

# 구분선
echo "---" >> "$LOG_FILE"

# 원래 Slack 알림도 시도 (테스트용 간단 버전)
if [ "$NOTIFICATION_TYPE" = "permission_request" ]; then
    echo "Permission request detected, sending Slack..." >> "$LOG_FILE"
    echo '{"text":"🔔 Notification Hook Test - Permission Request"}' | \
    curl -X POST -H 'Content-type: application/json' \
    --data @- https://hooks.slack.com/services/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 \
    >> "$LOG_FILE" 2>&1
fi

exit 0
