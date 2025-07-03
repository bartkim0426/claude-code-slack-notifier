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

# 마지막 assistant 메시지들 추출
LAST_MESSAGES=$(tail -200 "$TRANSCRIPT_PATH" | \
    jq -r '
        select(.type == "assistant" and .message.content != null) | 
        .message.content[] | 
        select(.type == "text") | 
        .text
    ' 2>/dev/null | \
    tail -5 | \
    awk 'NR>1{print "\n"} {print}' | \
    head -c 3000)

echo "Messages found: ${#LAST_MESSAGES} chars" >> "$DEBUG_LOG"

# Tool 사용 추출은 제거 (명령어와 파일 섹션 제거 요청에 따라)

# Tool 결과에서 에러 확인
ERRORS=$(tail -100 "$TRANSCRIPT_PATH" | \
    jq -r '
        select(.type == "user" and .toolUseResult != null and (.toolUseResult | contains("Error"))) |
        .toolUseResult
    ' 2>/dev/null | \
    tail -3 | \
    sed 's/^/⚠️ /')

# 요약 정보 추출 (있다면)
SUMMARY_INFO=$(jq -r 'select(.type == "summary") | .summary' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1)

# 통계 (에러만 유지)
ERROR_COUNT=$(echo "$ERRORS" | grep -c '^⚠️' 2>/dev/null || echo "0")

# 작업 요약 생성
if [ -n "$SUMMARY_INFO" ] && [ "$SUMMARY_INFO" != "null" ]; then
    WORK_SUMMARY="📋 $SUMMARY_INFO"
elif [ -n "$LAST_MESSAGES" ]; then
    WORK_SUMMARY="$LAST_MESSAGES"
else
    WORK_SUMMARY="작업이 완료되었습니다."
fi

# Slack 메시지 구성
SLACK_JSON=$(cat <<EOF
{
    "text": "✅ Claude Code 작업 완료 - $PROJECT_NAME",
    "attachments": [
        {
            "color": "#36a64f",
            "blocks": [
                {
                    "type": "section",
                    "fields": [
                        {
                            "type": "mrkdwn",
                            "text": "*프로젝트:*\n$PROJECT_NAME"
                        },
                        {
                            "type": "mrkdwn",
                            "text": "*시간:*\n${START_TIME_FORMATTED:-$SHORT_TIME}${END_TIME_FORMATTED:+ → $END_TIME_FORMATTED}"
                        }${TOTAL_TOKENS:+,
                        {
                            "type": "mrkdwn",
                            "text": "*토큰:*\n${TOTAL_TOKENS}개"
                        }}${ELAPSED_TIME:+,
                        {
                            "type": "mrkdwn",
                            "text": "*소요시간:*\n${ELAPSED_TIME}"
                        }}
                    ]
                },
                {
                    "type": "divider"
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*📝 작업 내용:*\n\`\`\`${WORK_SUMMARY}\`\`\`"
                    }
                }
EOF
)

# 에러가 있으면 추가
if [ "$ERROR_COUNT" -gt 0 ] && [ -n "$ERRORS" ]; then
    SLACK_JSON="${SLACK_JSON},
                {
                    \"type\": \"section\",
                    \"text\": {
                        \"type\": \"mrkdwn\",
                        \"text\": \"*⚠️ 발생한 에러:*\n\`\`\`${ERRORS}\`\`\`\"
                    }
                }"
fi

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

# Slack 전송
echo "$SLACK_JSON" | curl -s -X POST -H 'Content-type: application/json' --data @- "$SLACK_WEBHOOK_URL"

echo "Notification sent successfully" >> "$DEBUG_LOG"
echo "---" >> "$DEBUG_LOG"

exit 0
