#!/bin/bash

# Claude Code Stop Hook - 개선된 버전
# 다양한 JSONL 구조에 대응

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
DEBUG_LOG="$HOME/claude-stop-parsing.log"

# 입력 받기
INPUT=$(cat)

# 기본 정보
PROJECT_NAME=$(basename "$PWD")
SHORT_TIME=$(date "+%H:%M")

# Stop hook 데이터에서 정보 추출
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')
IS_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

# 디버깅 정보 기록
echo "=== Stop Hook Debug $(date) ===" >> "$DEBUG_LOG"
echo "Transcript path: $TRANSCRIPT_PATH" >> "$DEBUG_LOG"
echo "Session ID: $SESSION_ID" >> "$DEBUG_LOG"

# 무한 루프 방지
if [ "$IS_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

# transcript 파일 존재 확인
if [ ! -f "$TRANSCRIPT_PATH" ]; then
    echo "Transcript file not found: $TRANSCRIPT_PATH" >> "$DEBUG_LOG"
    
    # 파일이 없어도 기본 알림은 전송
    cat <<EOF | curl -s -X POST -H 'Content-type: application/json' --data @- "$WEBHOOK_URL"
{
    "text": "✅ Claude Code 작업 완료",
    "blocks": [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*$PROJECT_NAME* 프로젝트에서 작업이 완료되었습니다.\n_세부 정보를 가져올 수 없습니다._"
            }
        },
        {
            "type": "context",
            "elements": [
                {
                    "type": "mrkdwn",
                    "text": "🕐 $SHORT_TIME | 📁 $PWD"
                }
            ]
        }
    ]
}
EOF
    exit 0
fi

# 파일 정보 로깅
echo "File exists. Size: $(ls -lh "$TRANSCRIPT_PATH" | awk '{print $5}')" >> "$DEBUG_LOG"
echo "Line count: $(wc -l < "$TRANSCRIPT_PATH")" >> "$DEBUG_LOG"

# 마지막 assistant 메시지 추출 (여러 방법 시도)
LAST_MESSAGES=""

# 방법 1: text 필드와 sender 필드가 있는 경우
if [ -z "$LAST_MESSAGES" ]; then
    LAST_MESSAGES=$(tail -100 "$TRANSCRIPT_PATH" | \
        jq -r 'select(.sender == "assistant" and .text != null) | .text' 2>/dev/null | \
        tail -3 | \
        awk 'NR>1{print "\n"} {print}' | \
        head -c 800)
    echo "방법 1 결과: ${#LAST_MESSAGES} chars" >> "$DEBUG_LOG"
fi

# 방법 2: content 필드가 있는 경우
if [ -z "$LAST_MESSAGES" ]; then
    LAST_MESSAGES=$(tail -100 "$TRANSCRIPT_PATH" | \
        jq -r 'select(.role == "assistant" and .content != null) | .content' 2>/dev/null | \
        tail -3 | \
        awk 'NR>1{print "\n"} {print}' | \
        head -c 800)
    echo "방법 2 결과: ${#LAST_MESSAGES} chars" >> "$DEBUG_LOG"
fi

# 방법 3: type이 message인 경우
if [ -z "$LAST_MESSAGES" ]; then
    LAST_MESSAGES=$(tail -100 "$TRANSCRIPT_PATH" | \
        jq -r 'select(.type == "message" and .role == "assistant") | .content // .text // empty' 2>/dev/null | \
        tail -3 | \
        awk 'NR>1{print "\n"} {print}' | \
        head -c 800)
    echo "방법 3 결과: ${#LAST_MESSAGES} chars" >> "$DEBUG_LOG"
fi

# 실행한 명령어 추출 (여러 형식 대응)
EXECUTED_COMMANDS=$(tail -200 "$TRANSCRIPT_PATH" | \
    jq -r '
        select(.tool_name == "Bash" or .tool == "bash" or .name == "bash") | 
        (.tool_input.command // .parameters.command // .arguments.command // .input.command // empty)
    ' 2>/dev/null | \
    grep -v '^$' | \
    tail -5 | \
    sed 's/^/• /')

# 수정한 파일 추출
MODIFIED_FILES=$(tail -200 "$TRANSCRIPT_PATH" | \
    jq -r '
        select(.tool_name | test("Edit|Write|MultiEdit") // false) |
        (.tool_input.path // .tool_input.file // .parameters.path // .parameters.file // empty)
    ' 2>/dev/null | \
    grep -v '^$' | \
    sort -u | \
    tail -10 | \
    sed 's/^/• /')

# 통계
COMMAND_COUNT=$(echo "$EXECUTED_COMMANDS" | grep -c '^•' || echo "0")
FILE_COUNT=$(echo "$MODIFIED_FILES" | grep -c '^•' || echo "0")

# 작업 요약 생성
if [ -n "$LAST_MESSAGES" ]; then
    SUMMARY="$LAST_MESSAGES"
else
    SUMMARY="이번 세션의 작업 내용입니다."
fi

echo "Summary length: ${#SUMMARY}" >> "$DEBUG_LOG"
echo "Commands found: $COMMAND_COUNT" >> "$DEBUG_LOG"
echo "Files modified: $FILE_COUNT" >> "$DEBUG_LOG"

# Slack 메시지 전송
cat <<EOF | curl -s -X POST -H 'Content-type: application/json' --data @- "$WEBHOOK_URL"
{
    "text": "✅ Claude Code 작업 완료 - $PROJECT_NAME",
    "blocks": [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": "✅ 작업 완료",
                "emoji": true
            }
        },
        {
            "type": "section",
            "fields": [
                {
                    "type": "mrkdwn",
                    "text": "*프로젝트:*\n$PROJECT_NAME"
                },
                {
                    "type": "mrkdwn",
                    "text": "*시간:*\n$SHORT_TIME"
                },
                {
                    "type": "mrkdwn",
                    "text": "*명령어:*\n${COMMAND_COUNT}개"
                },
                {
                    "type": "mrkdwn",
                    "text": "*파일 수정:*\n${FILE_COUNT}개"
                }
            ]
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*📝 작업 내용:*\n> ${SUMMARY}"
            }
        },
        {
            "type": "context",
            "elements": [
                {
                    "type": "mrkdwn",
                    "text": "💾 세션: \`${SESSION_ID:0:8}...\` | 📁 $PWD"
                }
            ]
        }
    ]
}
EOF

echo "Slack notification sent" >> "$DEBUG_LOG"
echo "---" >> "$DEBUG_LOG"

exit 0
