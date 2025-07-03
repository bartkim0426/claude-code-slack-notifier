#!/bin/bash

# Stop Hook 데이터 구조 분석 스크립트
# 실제로 어떤 데이터가 들어오는지 확인

LOG_FILE="$HOME/claude-stop-structure.json"
DEBUG_LOG="$HOME/claude-stop-debug-detailed.log"

echo "=== Stop Hook Called at $(date) ===" >> "$DEBUG_LOG"

# 입력 데이터를 파일로 저장
cat > "$LOG_FILE"

# 데이터 구조 분석
echo "데이터 구조 분석:" >> "$DEBUG_LOG"
jq 'keys' < "$LOG_FILE" >> "$DEBUG_LOG" 2>&1

# 각 키의 타입 확인
echo -e "\n키 타입 확인:" >> "$DEBUG_LOG"
jq 'to_entries | map({key: .key, type: (.value | type)})' < "$LOG_FILE" >> "$DEBUG_LOG" 2>&1

# transcript가 있는지 확인
echo -e "\nTranscript 존재 여부:" >> "$DEBUG_LOG"
jq 'has("transcript")' < "$LOG_FILE" >> "$DEBUG_LOG" 2>&1

# 전체 데이터를 보기 좋게 저장
echo -e "\n전체 데이터 (pretty print):" >> "$DEBUG_LOG"
jq '.' < "$LOG_FILE" >> "$DEBUG_LOG" 2>&1

echo "---" >> "$DEBUG_LOG"

# Slack에도 간단한 알림
KEYS=$(jq -r 'keys | join(", ")' < "$LOG_FILE" 2>/dev/null || echo "parse error")

cat <<EOF | curl -s -X POST -H 'Content-type: application/json' --data @- https://hooks.slack.com/services/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
{
    "text": "🔍 Stop Hook 데이터 구조 분석 완료",
    "blocks": [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*Stop Hook 데이터 키:*\n\`$KEYS\`\n\n*로그 확인:*\n\`cat ~/claude-stop-structure.json\`\n\`cat ~/claude-stop-debug-detailed.log\`"
            }
        }
    ]
}
EOF

exit 0
