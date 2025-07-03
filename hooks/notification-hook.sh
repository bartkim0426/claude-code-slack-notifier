#!/bin/bash

# Claude Code Notification Hook - 요청 내용 상세 표시 버전
# Claude가 무엇을 하려는지 구체적으로 보여줌

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

DEBUG_LOG="$HOME/claude-notification-detail.log"

# 입력 JSON 읽기
INPUT=$(cat)

# 디버깅용 로그
echo "=== Notification at $(date) ===" >> "$DEBUG_LOG"
echo "$INPUT" | jq '.' >> "$DEBUG_LOG" 2>&1

# 기본 정보
PROJECT_NAME=$(basename "$PWD")
CURRENT_TIME=$(date "+%H:%M:%S")
FULL_TIME=$(date "+%Y-%m-%d %H:%M:%S")

# JSON 파싱
NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
MESSAGE=$(echo "$INPUT" | jq -r '.message // ""')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')

# transcript에서 마지막 사용자 프롬프트 추출
USER_PROMPT=""
if [ -f "$TRANSCRIPT_PATH" ]; then
    # 마지막 사용자 메시지 찾기 - Claude Code의 실제 구조에 맞춤
    USER_PROMPT=$(jq -r 'select(.message.role == "user" and .message.content[0].type == "text") | .message.content[0].text' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1)
    echo "User prompt: $USER_PROMPT" >> "$DEBUG_LOG"
fi

# 메시지 내용으로 직접 판단
if echo "$MESSAGE" | grep -qi "permission"; then
    # 권한 요청 메시지
        # 메시지에서 중요 정보 추출
        ACTION=""
        DETAILS=""
        EMOJI="🔔"
        COLOR="#ff9900"
        
        # 메시지 내용 분석
        if echo "$MESSAGE" | grep -qiE "(Bash|bash command)"; then
            # Bash 명령어 실행 요청
            COMMAND=$(echo "$MESSAGE" | grep -oE '`[^`]+`' | head -1 | tr -d '`')
            if [ -z "$COMMAND" ]; then
                COMMAND=$(echo "$MESSAGE" | grep -oE '"[^"]+"' | head -1 | tr -d '"')
            fi
            ACTION="명령어 실행"
            DETAILS="명령어: \`${COMMAND}\`"
            
            # 위험한 명령어 체크
            if echo "$COMMAND" | grep -qiE "(rm -rf|sudo|chmod 777|dd if=|mkfs)"; then
                EMOJI="🚨"
                COLOR="#ff0000"
                ACTION="⚠️ 위험한 명령어"
            fi
            
        elif echo "$MESSAGE" | grep -qiE "(Write|Edit|MultiEdit|write|create|edit|modify)"; then
            # 파일 작업 요청
            TOOL_NAME=$(echo "$MESSAGE" | grep -oE '(Write|Edit|MultiEdit)' | head -1)
            ACTION="${TOOL_NAME:-파일} 사용 요청"
            DETAILS="도구: ${TOOL_NAME:-파일 작업}"
            
        elif echo "$MESSAGE" | grep -qiE "(delete|remove)"; then
            # 삭제 작업
            TARGET=$(echo "$MESSAGE" | grep -oE '`[^`]+`' | head -1 | tr -d '`')
            ACTION="⚠️ 삭제 작업"
            DETAILS="대상: \`${TARGET}\`"
            EMOJI="⚠️"
            COLOR="#ff6600"
            
        elif echo "$MESSAGE" | grep -qiE "(read|view|open)"; then
            # 읽기 작업
            # 메시지에서 tool 이름 추출 (Read, Write, Edit 등)
            TOOL_NAME=$(echo "$MESSAGE" | grep -oE '(Read|Write|Edit|Bash|Grep|Glob|LS)' | head -1)
            ACTION="${TOOL_NAME:-파일} 사용 요청"
            DETAILS="도구: ${TOOL_NAME:-알 수 없음}"
            
        else
            # 기타 작업 - tool 이름 찾기 시도
            TOOL_NAME=$(echo "$MESSAGE" | grep -oE '(Task|TodoWrite|TodoRead|WebFetch|WebSearch|NotebookRead|NotebookEdit)' | head -1)
            if [ -n "$TOOL_NAME" ]; then
                ACTION="${TOOL_NAME} 사용 요청"
                DETAILS="도구: ${TOOL_NAME}"
            else
                ACTION="권한 요청"
                DETAILS="${MESSAGE:0:200}"
            fi
        fi
        
        # Slack 메시지 구성
        SLACK_JSON=$(cat <<EOF
{
    "text": "${EMOJI} Claude Code 승인 요청",
    "attachments": [
        {
            "color": "${COLOR}",
            "blocks": [
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": "${EMOJI} ${ACTION}",
                        "emoji": true
                    }
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*요청 내용:*\n${DETAILS}"
                    }
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*사용자 프롬프트:*\n> ${USER_PROMPT:-'프롬프트를 찾을 수 없습니다'}"
                    }
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*전체 메시지:*\n> ${MESSAGE}"
                    }
                },
                {
                    "type": "section",
                    "fields": [
                        {
                            "type": "mrkdwn",
                            "text": "*프로젝트:*\n${PROJECT_NAME}"
                        },
                        {
                            "type": "mrkdwn",
                            "text": "*시간:*\n${CURRENT_TIME}"
                        },
                        {
                            "type": "mrkdwn",
                            "text": "*디렉토리:*\n\`${PWD}\`"
                        },
                        {
                            "type": "mrkdwn",
                            "text": "*타입:*\n${NOTIFICATION_TYPE}"
                        }
                    ]
                },
                {
                    "type": "divider"
                },
                {
                    "type": "context",
                    "elements": [
                        {
                            "type": "mrkdwn",
                            "text": "💡 터미널에서 Y/N으로 응답하세요"
                        }
                    ]
                }
            ]
        }
    ]
}
EOF
)

elif echo "$MESSAGE" | grep -qi "waiting for your input"; then
    # 대기 중 알림 - 너무 자주 오면 주석 처리
        SLACK_JSON=$(cat <<EOF
{
    "text": "💤 Claude Code 대기 중",
    "blocks": [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*Claude Code가 입력을 기다리고 있습니다*\n프로젝트: ${PROJECT_NAME}"
            }
        },
        {
            "type": "context",
            "elements": [
                {
                    "type": "mrkdwn",
                    "text": "${CURRENT_TIME} | ${PWD}"
                }
            ]
        }
    ]
}
EOF
)

else
    # 기타 알림
        SLACK_JSON=$(cat <<EOF
{
    "text": "📢 Claude Code 알림",
    "blocks": [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*알림 타입:* ${NOTIFICATION_TYPE}\n*메시지:* ${MESSAGE}"
            }
        },
        {
            "type": "context",
            "elements": [
                {
                    "type": "mrkdwn",
                    "text": "${PROJECT_NAME} | ${FULL_TIME}"
                }
            ]
        }
    ]
}
EOF
)
fi

# Slack 전송
if [ -n "$SLACK_JSON" ]; then
    RESPONSE=$(echo "$SLACK_JSON" | curl -s -X POST -H 'Content-type: application/json' --data @- "$WEBHOOK_URL" 2>&1)
    echo "Slack response: $RESPONSE" >> "$DEBUG_LOG"
fi

echo "---" >> "$DEBUG_LOG"

exit 0
