#!/bin/bash

# Claude Code Stop Hook - 실제 transcript 파일을 읽어서 작업 내용 분석
# transcript_path에서 JSONL 파일을 읽어 작업 내용을 추출

WEBHOOK_URL="https://hooks.slack.com/services/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"

# 색상 정의
COLOR_SUCCESS="#36a64f"
COLOR_WARNING="#ff9900"
COLOR_INFO="#3AA3E3"

# 입력 받기
INPUT=$(cat)

# 기본 정보
PROJECT_NAME=$(basename "$PWD")
PROJECT_PATH="$PWD"
CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")
SHORT_TIME=$(date "+%H:%M")

# Stop hook 데이터에서 정보 추출
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')
IS_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

# 무한 루프 방지
if [ "$IS_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

# transcript 파일 존재 확인
if [ ! -f "$TRANSCRIPT_PATH" ]; then
    echo "Transcript file not found: $TRANSCRIPT_PATH" >&2
    exit 0
fi

# JSONL 파일에서 마지막 assistant 메시지들 추출 (최대 3개)
LAST_MESSAGES=$(tail -50 "$TRANSCRIPT_PATH" | \
    jq -r 'select(.type == "text" and .sender == "assistant") | .text' | \
    tail -3 | \
    awk 'NR>1{print ""} {print}' | \
    head -c 1000)

# 실행한 명령어들 추출
EXECUTED_COMMANDS=$(tail -100 "$TRANSCRIPT_PATH" | \
    jq -r 'select(.tool_name == "Bash") | .tool_input.command // empty' | \
    tail -5 | \
    sed 's/^/• /')

# 수정한 파일들 추출
MODIFIED_FILES=$(tail -100 "$TRANSCRIPT_PATH" | \
    jq -r 'select(.tool_name == "Edit" or .tool_name == "Write" or .tool_name == "MultiEdit") | .tool_input.path // .tool_input.file // empty' | \
    sort -u | \
    tail -10 | \
    sed 's/^/• /')

# 읽은 파일들 추출
READ_FILES=$(tail -100 "$TRANSCRIPT_PATH" | \
    jq -r 'select(.tool_name == "Read") | .tool_input.path // empty' | \
    sort -u | \
    tail -5 | \
    sed 's/^/• /')

# 작업 시간 계산 (첫 줄과 마지막 줄의 타임스탬프 차이)
START_TIME=$(head -1 "$TRANSCRIPT_PATH" | jq -r '.timestamp // empty' 2>/dev/null)
END_TIME=$(tail -1 "$TRANSCRIPT_PATH" | jq -r '.timestamp // empty' 2>/dev/null)

# 통계 정보
COMMAND_COUNT=$(echo "$EXECUTED_COMMANDS" | grep -c '^•' || echo "0")
FILE_MODIFIED_COUNT=$(echo "$MODIFIED_FILES" | grep -c '^•' || echo "0")
FILE_READ_COUNT=$(echo "$READ_FILES" | grep -c '^•' || echo "0")

# 작업 요약 생성
if [ -n "$LAST_MESSAGES" ]; then
    SUMMARY="$LAST_MESSAGES"
else
    SUMMARY="작업 내용을 요약할 수 없습니다."
fi

# Slack 메시지 구성
SLACK_JSON=$(cat <<EOF
{
    "text": "✅ Claude Code 작업 완료 - $PROJECT_NAME",
    "attachments": [
        {
            "color": "$COLOR_SUCCESS",
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
                            "text": "*완료 시간:*\n$SHORT_TIME"
                        },
                        {
                            "type": "mrkdwn",
                            "text": "*세션 ID:*\n\`${SESSION_ID:0:8}...\`"
                        },
                        {
                            "type": "mrkdwn",
                            "text": "*작업 통계:*\n명령어 ${COMMAND_COUNT}개, 파일 ${FILE_MODIFIED_COUNT}개 수정"
                        }
                    ]
                },
                {
                    "type": "divider"
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*📝 작업 요약:*\n\`\`\`$SUMMARY\`\`\`"
                    }
                }
EOF
)

# 실행한 명령어가 있으면 추가
if [ -n "$EXECUTED_COMMANDS" ] && [ "$COMMAND_COUNT" -gt 0 ]; then
    SLACK_JSON="${SLACK_JSON},
                {
                    \"type\": \"section\",
                    \"text\": {
                        \"type\": \"mrkdwn\",
                        \"text\": \"*🔧 실행한 명령어:*\n\`\`\`${EXECUTED_COMMANDS}\`\`\`\"
                    }
                }"
fi

# 수정한 파일이 있으면 추가
if [ -n "$MODIFIED_FILES" ] && [ "$FILE_MODIFIED_COUNT" -gt 0 ]; then
    SLACK_JSON="${SLACK_JSON},
                {
                    \"type\": \"section\",
                    \"text\": {
                        \"type\": \"mrkdwn\",
                        \"text\": \"*📄 수정한 파일:*\n${MODIFIED_FILES}\"
                    }
                }"
fi

# Footer 추가
SLACK_JSON="${SLACK_JSON},
                {
                    \"type\": \"context\",
                    \"elements\": [
                        {
                            \"type\": \"mrkdwn\",
                            \"text\": \"📊 총 ${COMMAND_COUNT}개 명령어 실행 | ${FILE_MODIFIED_COUNT}개 파일 수정 | ${FILE_READ_COUNT}개 파일 읽음\"
                        }
                    ]
                }
            ]
        }
    ]
}"

# Slack으로 전송
echo "$SLACK_JSON" | curl -s -X POST -H 'Content-type: application/json' --data @- "$WEBHOOK_URL"

# 디버그 로그
echo "Stop hook completed at $CURRENT_TIME for session $SESSION_ID" >> ~/claude-stop-debug.log

exit 0
