#!/bin/bash

# Claude Code Notification Hook - 요청 내용 상세 표시 버전
# Claude가 무엇을 하려는지 구체적으로 보여줌

WEBHOOK_URL="https://hooks.slack.com/services/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"
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

# notification_type에 따른 처리
case "$NOTIFICATION_TYPE" in
    "permission_request")
        # 메시지에서 중요 정보 추출
        ACTION=""
        DETAILS=""
        EMOJI="🔔"
        COLOR="#ff9900"
        
        # 메시지 내용 분석
        if echo "$MESSAGE" | grep -qi "bash"; then
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
            
        elif echo "$MESSAGE" | grep -qiE "(write|create|edit|modify)"; then
            # 파일 작업 요청
            FILE=$(echo "$MESSAGE" | grep -oE '`[^`]+`' | head -1 | tr -d '`')
            ACTION="파일 작업"
            DETAILS="대상: \`${FILE}\`"
            
        elif echo "$MESSAGE" | grep -qiE "(delete|remove)"; then
            # 삭제 작업
            TARGET=$(echo "$MESSAGE" | grep -oE '`[^`]+`' | head -1 | tr -d '`')
            ACTION="⚠️ 삭제 작업"
            DETAILS="대상: \`${TARGET}\`"
            EMOJI="⚠️"
            COLOR="#ff6600"
            
        elif echo "$MESSAGE" | grep -qiE "(read|view|open)"; then
            # 읽기 작업
            FILE=$(echo "$MESSAGE" | grep -oE '`[^`]+`' | head -1 | tr -d '`')
            ACTION="파일 읽기"
            DETAILS="대상: \`${FILE}\`"
            
        else
            # 기타 작업
            ACTION="권한 요청"
            DETAILS="${MESSAGE:0:200}"
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
        ;;
    
    "idle")
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
        ;;
    
    *)
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
        ;;
esac

# Slack 전송
if [ -n "$SLACK_JSON" ]; then
    echo "$SLACK_JSON" | curl -s -X POST -H 'Content-type: application/json' --data @- "$WEBHOOK_URL" >/dev/null 2>&1
fi

echo "---" >> "$DEBUG_LOG"

exit 0
