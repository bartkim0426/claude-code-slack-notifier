#!/bin/bash

# PostToolUse Hook - 작업 내용을 로컬 파일에 기록
# 이 데이터를 Stop Hook에서 읽어서 사용

WORK_LOG="$HOME/.claude-current-work.log"
TEMP_LOG="$HOME/.claude-current-work.tmp"

# 입력 받기
INPUT=$(cat)

# 도구 정보 추출
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
TIMESTAMP=$(date "+%H:%M:%S")

# 도구별로 작업 내용 기록
case "$TOOL_NAME" in
    "Bash")
        COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
        echo "[$TIMESTAMP] CMD: $COMMAND" >> "$WORK_LOG"
        ;;
    
    "Write"|"Edit"|"MultiEdit")
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // .tool_input.file // ""' 2>/dev/null)
        echo "[$TIMESTAMP] EDIT: $FILE_PATH" >> "$WORK_LOG"
        ;;
    
    "Read")
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // ""' 2>/dev/null)
        echo "[$TIMESTAMP] READ: $FILE_PATH" >> "$WORK_LOG"
        ;;
esac

# 로그 파일 크기 제한 (최근 100줄만 유지)
if [ -f "$WORK_LOG" ]; then
    tail -100 "$WORK_LOG" > "$TEMP_LOG" && mv "$TEMP_LOG" "$WORK_LOG"
fi

exit 0
