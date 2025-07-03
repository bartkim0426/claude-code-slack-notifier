#!/bin/bash

# Claude Code Stop Hook - 실제 JSONL 구조에 맞춘 버전
# Claude Code의 실제 transcript 형식을 정확히 파싱

# 설정 파일 로드
CONFIG_FILE="$HOME/.claude-slack-notifier/config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Error: Config file not found at $CONFIG_FILE" >&2
    exit 1
fi

# 설정 확인
if [ -z "$SLACK_WEBHOOK_URL" ]; then
    echo "Error: SLACK_WEBHOOK_URL not set in config" >&2
    exit 1
fi

DEBUG_LOG="$HOME/claude-stop-final.log"

# 입력 받기
INPUT=$(cat)

# 기본 정보
PROJECT_NAME=$(basename "$PWD")
PROJECT_PATH="$PWD"
SHORT_TIME=$(date "+%H:%M")
FULL_TIME=$(date "+%Y-%m-%d %H:%M:%S")

# Stop hook 데이터에서 정보 추출
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')
IS_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

# 메타데이터에서 토큰 사용량과 시작 시간 추출
METADATA_USAGE=$(echo "$INPUT" | jq -r '.metadata.usage // null')
START_TIME_FROM_META=$(echo "$INPUT" | jq -r '.start_time // null')

# 디버깅
echo "=== Stop Hook at $FULL_TIME ===" >> "$DEBUG_LOG"
echo "Session: $SESSION_ID" >> "$DEBUG_LOG"
echo "Transcript: $TRANSCRIPT_PATH" >> "$DEBUG_LOG"

# 무한 루프 방지
if [ "$IS_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

# transcript 파일 확인
if [ ! -f "$TRANSCRIPT_PATH" ]; then
    echo "Transcript not found" >> "$DEBUG_LOG"
    exit 0
fi

# 시작 시간과 종료 시간 추출
# 메타데이터의 start_time 우선 사용
if [ "$START_TIME_FROM_META" != "null" ] && [ -n "$START_TIME_FROM_META" ]; then
    START_TIME="$START_TIME_FROM_META"
else
    START_TIME=$(head -5 "$TRANSCRIPT_PATH" | jq -r 'select(.timestamp != null) | .timestamp' 2>/dev/null | head -1)
fi
END_TIME=$(tail -5 "$TRANSCRIPT_PATH" | jq -r 'select(.timestamp != null) | .timestamp' 2>/dev/null | tail -1)

# 시간 포맷팅
if [ -n "$START_TIME" ] && [ "$START_TIME" != "null" ]; then
    START_TIME_FORMATTED=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${START_TIME%%.*}" "+%H:%M" 2>/dev/null || echo "")
    START_TIME_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${START_TIME%%.*}" "+%s" 2>/dev/null || echo "")
else
    START_TIME_FORMATTED=""
    START_TIME_EPOCH=""
fi

if [ -n "$END_TIME" ] && [ "$END_TIME" != "null" ]; then
    END_TIME_FORMATTED=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${END_TIME%%.*}" "+%H:%M" 2>/dev/null || echo "")
    END_TIME_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${END_TIME%%.*}" "+%s" 2>/dev/null || echo "")
else
    END_TIME_FORMATTED=""
    END_TIME_EPOCH=""
fi

# 소요 시간 계산
ELAPSED_TIME=""
if [ -n "$START_TIME_EPOCH" ] && [ -n "$END_TIME_EPOCH" ]; then
    ELAPSED_SECONDS=$((END_TIME_EPOCH - START_TIME_EPOCH))
    if [ $ELAPSED_SECONDS -ge 0 ]; then
        HOURS=$((ELAPSED_SECONDS / 3600))
        MINUTES=$(((ELAPSED_SECONDS % 3600) / 60))
        SECONDS=$((ELAPSED_SECONDS % 60))
        
        if [ $HOURS -gt 0 ]; then
            ELAPSED_TIME="${HOURS}시간 ${MINUTES}분"
        elif [ $MINUTES -gt 0 ]; then
            ELAPSED_TIME="${MINUTES}분 ${SECONDS}초"
        else
            ELAPSED_TIME="${SECONDS}초"
        fi
    fi
fi

# 토큰 사용량 추출 - 메타데이터 우선, 없으면 transcript에서 추출
if [ "$METADATA_USAGE" != "null" ] && [ -n "$METADATA_USAGE" ]; then
    # 메타데이터에서 토큰 정보 추출
    TOTAL_TOKENS=$(echo "$METADATA_USAGE" | jq -r '(.input_tokens // 0) + (.output_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)')
else
    # transcript에서 토큰 정보 추출
    TOTAL_TOKENS=$(tail -200 "$TRANSCRIPT_PATH" | \
        jq -r 'select(.message.usage != null) | .message.usage | (.input_tokens // 0) + (.output_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)' 2>/dev/null | \
        awk '{sum+=$1} END {print sum}')
fi

echo "Total tokens calculated: $TOTAL_TOKENS" >> "$DEBUG_LOG"

# 사용자 프롬프트 추출 (Agent 프롬프트 제외)
USER_PROMPT=$(tail -500 "$TRANSCRIPT_PATH" | \
    jq -r '
        select(.type == "user" and .message.content != null) | 
        if (.message.content | type) == "string" then 
            .message.content 
        else 
            empty 
        end
    ' 2>/dev/null | \
    grep -v "^Read the last" | \
    grep -v "^Find all Claude" | \
    grep -v "^Analyze" | \
    tail -1 | \
    head -c 1000)

# Claude 응답 추출
CLAUDE_RESPONSE=$(tail -200 "$TRANSCRIPT_PATH" | \
    jq -r '
        select(.type == "assistant" and .message.content != null) | 
        .message.content[] | 
        select(.type == "text") | 
        .text
    ' 2>/dev/null | \
    tail -1 | \
    head -c 2000)

echo "User prompt: ${#USER_PROMPT} chars" >> "$DEBUG_LOG"
echo "Claude response: ${#CLAUDE_RESPONSE} chars" >> "$DEBUG_LOG"

# 작업 내용 구성
if [ -n "$USER_PROMPT" ]; then
    PROMPT_TEXT="💬 사용자 요청:\n$USER_PROMPT"
else
    PROMPT_TEXT="💬 사용자 요청:\n(요청 내용 없음)"
fi

if [ -n "$CLAUDE_RESPONSE" ]; then
    RESPONSE_TEXT="🤖 Claude 응답:\n$CLAUDE_RESPONSE"
else
    RESPONSE_TEXT="🤖 Claude 응답:\n(응답 내용 없음)"
fi

# Slack 메시지 구성
FIELDS_JSON='[
    {
        "type": "mrkdwn",
        "text": "*프로젝트:*\n'"$PROJECT_NAME"'"
    },
    {
        "type": "mrkdwn",
        "text": "*시간:*\n'"${START_TIME_FORMATTED:-$SHORT_TIME}${END_TIME_FORMATTED:+ → $END_TIME_FORMATTED}"'"
    }'

# 토큰 정보 추가
if [ -n "$TOTAL_TOKENS" ] && [ "$TOTAL_TOKENS" != "0" ]; then
    FIELDS_JSON="${FIELDS_JSON},
    {
        \"type\": \"mrkdwn\",
        \"text\": \"*토큰:*\\n${TOTAL_TOKENS}개\"
    }"
fi

# 소요시간 정보 추가
if [ -n "$ELAPSED_TIME" ]; then
    FIELDS_JSON="${FIELDS_JSON},
    {
        \"type\": \"mrkdwn\",
        \"text\": \"*소요시간:*\\n${ELAPSED_TIME}\"
    }"
fi

FIELDS_JSON="${FIELDS_JSON}]"

SLACK_JSON=$(cat <<EOF
{
    "text": "✅ Claude Code 작업 완료 - $PROJECT_NAME",
    "attachments": [
        {
            "color": "#36a64f",
            "blocks": [
                {
                    "type": "section",
                    "fields": $FIELDS_JSON
                },
                {
                    "type": "divider"
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*$PROMPT_TEXT*"
                    }
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*$RESPONSE_TEXT*"
                    }
                }
EOF
)

# Footer
SLACK_JSON="${SLACK_JSON},
                {
                    \"type\": \"context\",
                    \"elements\": [
                        {
                            \"type\": \"mrkdwn\",
                            \"text\": \"💾 세션: \`${SESSION_ID:0:8}...\` | 📁 $PROJECT_PATH\"
                        }
                    ]
                }
            ]
        }
    ]
}"

# JSON 디버깅용 저장
echo "$SLACK_JSON" > "$HOME/claude-stop-debug-json.log"

# Slack 전송
CURL_RESPONSE=$(echo "$SLACK_JSON" | curl -s -X POST -H 'Content-type: application/json' --data @- "$SLACK_WEBHOOK_URL" -w "\n%{http_code}")
HTTP_CODE=$(echo "$CURL_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$CURL_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "200" ]; then
    echo "Notification sent successfully (HTTP $HTTP_CODE)" >> "$DEBUG_LOG"
else
    echo "Notification failed! HTTP code: $HTTP_CODE" >> "$DEBUG_LOG"
    echo "Response: $RESPONSE_BODY" >> "$DEBUG_LOG"
fi
echo "---" >> "$DEBUG_LOG"

exit 0
