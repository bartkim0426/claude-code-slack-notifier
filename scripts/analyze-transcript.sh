#!/bin/bash

# JSONL 파일 구조 확인 스크립트

TRANSCRIPT_PATH="$1"

if [ -z "$TRANSCRIPT_PATH" ]; then
    echo "Usage: $0 <transcript-path>"
    exit 1
fi

echo "=== JSONL 파일 구조 분석 ==="
echo "파일: $TRANSCRIPT_PATH"
echo ""

echo "첫 5줄 구조:"
head -5 "$TRANSCRIPT_PATH" | jq -c 'keys' | sort -u
echo ""

echo "Assistant 메시지 예시:"
grep '"sender":"assistant"' "$TRANSCRIPT_PATH" | tail -1 | jq '.'
echo ""

echo "Bash 도구 사용 예시:"
grep '"tool_name":"Bash"' "$TRANSCRIPT_PATH" | tail -1 | jq '.'
echo ""

echo "파일 수정 도구 사용 예시:"
grep -E '"tool_name":"(Edit|Write)"' "$TRANSCRIPT_PATH" | tail -1 | jq '.'
