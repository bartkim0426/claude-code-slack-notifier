#!/bin/bash

# Claude Code Stop Hook - 작업 완료 시 상세 Slack 알림
# 작업 내용, 실행한 명령어, 수정한 파일 등을 포함한 종합 리포트

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

# 색상 정의
COLOR_SUCCESS="#36a64f"
COLOR_WARNING="#ff9900"
COLOR_INFO="#3AA3E3"

# 임시 파일로 입력 저장
TEMP_FILE=$(mktemp)
cat > "$TEMP_FILE"

# 기본 정보 추출
PROJECT_NAME=$(basename "$PWD")
PROJECT_PATH="$PWD"
CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")
ELAPSED_TIME=$(jq -r '.elapsed_time // "알 수 없음"' < "$TEMP_FILE")

# Stop hook 입력 분석
echo "=== Stop Hook Debug at $CURRENT_TIME ===" >> ~/claude-stop-debug.log
jq '.' < "$TEMP_FILE" >> ~/claude-stop-debug.log

# 마지막 assistant 메시지들 추출 (최대 5개)
LAST_MESSAGES=$(jq -r '
    .transcript[-10:] 
    | map(select(.type == "text" and .sender == "assistant")) 
    | .[-3:] 
    | map(.text) 
    | join("\n\n")
' < "$TEMP_FILE" 2>/dev/null || echo "")

# 메시지가 비어있으면 다른 방법 시도
if [ -z "$LAST_MESSAGES" ] || [ "$LAST_MESSAGES" = "null" ]; then
    LAST_MESSAGES=$(jq -r '
        if .transcript then
            .transcript 
            | map(select(.sender == "assistant" and .text)) 
            | last.text // "작업 내용을 가져올 수 없습니다"
        else
            "트랜스크립트 정보가 없습니다"
        end
    ' < "$TEMP_FILE" 2>/dev/null || echo "작업 내용 파싱 실패")
fi

# 실행된 명령어들 추출
EXECUTED_COMMANDS=$(jq -r '
    .transcript[]? 
    | select(.tool_name == "Bash") 
    | .tool_input.command // empty
' < "$TEMP_FILE" 2>/dev/null | tail -5 | sed 's/^/• /' || echo "")

# 수정된 파일들 추출
MODIFIED_FILES=$(jq -r '
    .transcript[]? 
    | select(.tool_name == "Edit" or .tool_name == "Write" or .tool_name == "MultiEdit") 
    | .tool_input.path // .tool_input.file // empty
' < "$TEMP_FILE" 2>/dev/null | sort -u | tail -10 | sed 's/^/• /' || echo "")

# 읽은 파일들 추출
READ_FILES=$(jq -r '
    .transcript[]? 
    | select(.tool_name == "Read") 
    | .tool_input.path // empty
' < "$TEMP_FILE" 2>/dev/null | sort -u | tail -5 | sed 's/^/• /' || echo "")

# 작업 요약 만들기
if [ -n "$LAST_MESSAGES" ] && [ "$LAST_MESSAGES" != "null" ]; then
    # 메시지 길이 제한 (Slack 제한 고려)
    SUMMARY=$(echo "$LAST_MESSAGES" | head -c 1000)
    if [ ${#LAST_MESSAGES} -gt 1000 ]; then
        SUMMARY="${SUMMARY}..."
    fi
else
    SUMMARY="작업 내용을 요약할 수 없습니다."
fi

# 통계 정보
COMMAND_COUNT=$(echo "$EXECUTED_COMMANDS" | grep -c '^•' || echo "0")
FILE_MODIFIED_COUNT=$(echo "$MODIFIED_FILES" | grep -c '^•' || echo "0")
FILE_READ_COUNT=$(echo "$READ_FILES" | grep -c '^•' || echo "0")

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
                            "text": "*완료 시간:*\n$CURRENT_TIME"
                        },
                        {
                            "type": "mrkdwn",
                            "text": "*작업 시간:*\n$ELAPSED_TIME"
                        },
                        {
                            "type": "mrkdwn",
                            "text": "*작업 위치:*\n\`$PROJECT_PATH\`"
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
if [ -n "$EXECUTED_COMMANDS" ]; then
    SLACK_JSON="${SLACK_JSON},
                {
                    \"type\": \"section\",
                    \"text\": {
                        \"type\": \"mrkdwn\",
                        \"text\": \"*🔧 실행한 명령어 (${COMMAND_COUNT}개):*\n\`\`\`${EXECUTED_COMMANDS}\`\`\`\"
                    }
                }"
fi

# 수정한 파일이 있으면 추가
if [ -n "$MODIFIED_FILES" ]; then
    SLACK_JSON="${SLACK_JSON},
                {
                    \"type\": \"section\",
                    \"text\": {
                        \"type\": \"mrkdwn\",
                        \"text\": \"*📄 수정한 파일 (${FILE_MODIFIED_COUNT}개):*\n${MODIFIED_FILES}\"
                    }
                }"
fi

# 통계 정보 추가
SLACK_JSON="${SLACK_JSON},
                {
                    \"type\": \"context\",
                    \"elements\": [
                        {
                            \"type\": \"mrkdwn\",
                            \"text\": \"📊 *통계:* 명령어 ${COMMAND_COUNT}개 실행 | 파일 ${FILE_MODIFIED_COUNT}개 수정 | 파일 ${FILE_READ_COUNT}개 읽음\"
                        }
                    ]
                }
            ]
        }
    ]
}"

# Slack으로 전송
echo "$SLACK_JSON" | curl -s -X POST -H 'Content-type: application/json' --data @- "$WEBHOOK_URL"

# 임시 파일 삭제
rm -f "$TEMP_FILE"

# 디버그 로그에 전송 내용 기록
echo "Sent to Slack at $CURRENT_TIME" >> ~/claude-stop-debug.log
echo "---" >> ~/claude-stop-debug.log

exit 0
