#!/bin/bash

# Claude Code Slack Notification Script
# 사용법: Stop hook에서 이 스크립트를 호출

WEBHOOK_URL="https://hooks.slack.com/services/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"

# 입력 JSON을 임시 파일에 저장
TEMP_FILE=$(mktemp)
cat > "$TEMP_FILE"

# 프로젝트 정보
PROJECT_NAME=$(basename "$PWD")
PROJECT_PATH="$PWD"
CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")

# JSON에서 정보 추출
ELAPSED_TIME=$(jq -r '.elapsed_time // "알 수 없음"' < "$TEMP_FILE")

# 최근 작업 내용 추출 (여러 방법 시도)
LAST_MESSAGE=""

# 방법 1: transcript의 마지막 assistant 메시지들
if [ -z "$LAST_MESSAGE" ]; then
    LAST_MESSAGE=$(jq -r '.transcript[-5:] | map(select(.type == "text" and .sender == "assistant") | .text) | join("\n")