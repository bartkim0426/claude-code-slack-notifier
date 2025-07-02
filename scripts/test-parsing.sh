#!/bin/bash

# 실제 JSONL 파일로 Stop Hook 테스트

# 최근 JSONL 파일 찾기
PROJECT_DIR="$HOME/.claude/projects/*vibe-web-transformer*"
JSONL_FILE=$(ls -t $PROJECT_DIR/*.jsonl 2>/dev/null | head -1)

if [ ! -f "$JSONL_FILE" ]; then
    echo "JSONL 파일을 찾을 수 없습니다."
    exit 1
fi

echo "테스트 대상 파일: $JSONL_FILE"
echo ""

echo "=== Assistant 메시지 추출 테스트 ==="
tail -50 "$JSONL_FILE" | \
    jq -r '
        select(.type == "assistant" and .message.content != null) | 
        .message.content[] | 
        select(.type == "text") | 
        .text
    ' | tail -3
echo ""

echo "=== Bash 명령어 추출 테스트 ==="
tail -100 "$JSONL_FILE" | \
    jq -r '
        select(.type == "assistant" and .message.content != null) |
        .message.content[] |
        select(.type == "tool_use" and .name == "bash") |
        .input.command // empty
    ' | tail -5
echo ""

echo "=== 파일 작업 추출 테스트 ==="
tail -100 "$JSONL_FILE" | \
    jq -r '
        select(.type == "assistant" and .message.content != null) |
        .message.content[] |
        select(.type == "tool_use" and (.name == "edit" or .name == "write" or .name == "str_replace")) |
        "\(.name): \(.input.path // .input.file // "unknown")"
    ' | tail -5
echo ""

echo "=== Summary 추출 테스트 ==="
jq -r 'select(.type == "summary") | .summary' "$JSONL_FILE" | tail -3
