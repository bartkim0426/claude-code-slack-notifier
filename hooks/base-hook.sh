#!/bin/bash

# Claude Slack Notifier - 통합 Hook 스크립트 템플릿
# 설정 파일 기반으로 작동

# 설정 로드
CONFIG_FILE="$HOME/.claude-slack-notifier/config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Webhook URL 확인
if [ -z "$SLACK_WEBHOOK_URL" ]; then
    exit 0
fi

# 로그 함수
log_debug() {
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$HOME/.claude-slack-notifier/logs/debug.log"
    fi
}

# Slack 전송 함수
send_to_slack() {
    local json_payload="$1"
    curl -s -X POST -H 'Content-type: application/json' \
        --data "$json_payload" \
        "$SLACK_WEBHOOK_URL" >/dev/null 2>&1
}

# 프로젝트별 Webhook URL 가져오기
get_webhook_url() {
    local project_name="$1"
    local channel_map="$HOME/.claude-slack-notifier/channel-map.json"
    
    if [ -f "$channel_map" ] && command -v jq &> /dev/null; then
        # 프로젝트별 매칭 시도
        local custom_url=$(jq -r --arg proj "$project_name" '
            to_entries | 
            map(select(.key | test($proj))) | 
            first.value // .default // empty
        ' "$channel_map" 2>/dev/null)
        
        if [ -n "$custom_url" ]; then
            echo "$custom_url"
            return
        fi
    fi
    
    echo "$SLACK_WEBHOOK_URL"
}

# 기본 정보
PROJECT_NAME=$(basename "$PWD")
WEBHOOK_URL=$(get_webhook_url "$PROJECT_NAME")

# Hook 타입별 처리는 각 Hook 스크립트에서 구현