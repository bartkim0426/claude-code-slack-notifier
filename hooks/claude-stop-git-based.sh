#!/bin/bash

# Claude Code Stop Hook - 로컬 작업 추적 버전
# transcript 대신 로컬에서 작업 내용을 추적

WEBHOOK_URL="https://hooks.slack.com/services/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"
WORK_LOG="$HOME/.claude-work-history.log"

# 입력 받기 (사용하지 않더라도 받아야 함)
INPUT=$(cat)

# 기본 정보
PROJECT_NAME=$(basename "$PWD")
PROJECT_PATH="$PWD"
CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")
SHORT_TIME=$(date "+%H:%M")

# Stop hook 입력에서 가능한 정보 추출
ELAPSED_TIME=$(echo "$INPUT" | jq -r '.elapsed_time // "알 수 없음"' 2>/dev/null || echo "알 수 없음")
IS_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")

# 무한 루프 방지
if [ "$IS_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

# 최근 git 커밋 확인 (있다면)
RECENT_COMMITS=""
if [ -d ".git" ]; then
    RECENT_COMMITS=$(git log --oneline -3 2>/dev/null | sed 's/^/• /' || echo "")
fi

# 최근 수정된 파일들 (git status)
MODIFIED_FILES=""
if [ -d ".git" ]; then
    MODIFIED_FILES=$(git status --porcelain 2>/dev/null | head -10 | sed 's/^/• /' || echo "")
fi

# 프로젝트별 작업 요약 (간단한 추정)
WORK_SUMMARY="Claude Code 작업이 완료되었습니다."

# 파일 변경 통계
if [ -n "$MODIFIED_FILES" ]; then
    FILE_COUNT=$(echo "$MODIFIED_FILES" | wc -l | tr -d ' ')
else
    FILE_COUNT="0"
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
                            "text": "*작업 시간:*\n$ELAPSED_TIME"
                        },
                        {
                            "type": "mrkdwn",
                            "text": "*변경 파일:*\n$FILE_COUNT개"
                        }
                    ]
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*📁 작업 디렉토리:*\n\`$PROJECT_PATH\`"
                    }
                }
EOF
)

# 수정된 파일이 있으면 추가
if [ -n "$MODIFIED_FILES" ] && [ "$FILE_COUNT" != "0" ]; then
    SLACK_JSON="${SLACK_JSON},
                {
                    \"type\": \"section\",
                    \"text\": {
                        \"type\": \"mrkdwn\",
                        \"text\": \"*📝 변경된 파일:*\n\`\`\`${MODIFIED_FILES}\`\`\`\"
                    }
                }"
fi

# 최근 커밋이 있으면 추가
if [ -n "$RECENT_COMMITS" ]; then
    SLACK_JSON="${SLACK_JSON},
                {
                    \"type\": \"section\",
                    \"text\": {
                        \"type\": \"mrkdwn\",
                        \"text\": \"*🔄 최근 커밋:*\n${RECENT_COMMITS}\"
                    }
                }"
fi

# 마무리
SLACK_JSON="${SLACK_JSON},
                {
                    \"type\": \"context\",
                    \"elements\": [
                        {
                            \"type\": \"mrkdwn\",
                            \"text\": \"💡 작업 내용은 터미널에서 확인하세요\"
                        }
                    ]
                }
            ]
        }
    ]
}"

# Slack 전송
echo "$SLACK_JSON" | curl -s -X POST -H 'Content-type: application/json' --data @- "$WEBHOOK_URL"

# 작업 이력 로컬 저장
echo "[$CURRENT_TIME] $PROJECT_NAME - 작업 완료 (시간: $ELAPSED_TIME)" >> "$WORK_LOG"

exit 0
