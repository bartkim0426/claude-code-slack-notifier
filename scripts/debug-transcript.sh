#!/bin/bash

# 가장 최근 transcript 파일 찾기 및 분석

CLAUDE_DIR="$HOME/.claude/projects"
PROJECT_DIR=$(find "$CLAUDE_DIR" -name "*vibe-web-transformer*" -type d | head -1)

if [ -z "$PROJECT_DIR" ]; then
    echo "프로젝트 디렉토리를 찾을 수 없습니다."
    exit 1
fi

echo "프로젝트 디렉토리: $PROJECT_DIR"
echo ""

# 최근 JSONL 파일 찾기
LATEST_JSONL=$(ls -t "$PROJECT_DIR"/*.jsonl 2>/dev/null | head -1)

if [ -z "$LATEST_JSONL" ]; then
    echo "JSONL 파일을 찾을 수 없습니다."
    exit 1
fi

echo "최근 transcript 파일: $LATEST_JSONL"
echo "파일 크기: $(ls -lh "$LATEST_JSONL" | awk '{print $5}')"
echo "라인 수: $(wc -l < "$LATEST_JSONL")"
echo ""

echo "=== 파일 구조 분석 ==="
echo ""

echo "1. 첫 번째 라인의 키들:"
head -1 "$LATEST_JSONL" | jq -r 'keys | .[]' | sort -u
echo ""

echo "2. type 값들의 종류:"
jq -r '.type // empty' "$LATEST_JSONL" | sort -u | head -20
echo ""

echo "3. tool_name 값들의 종류:"
jq -r '.tool_name // empty' "$LATEST_JSONL" | sort -u | grep -v '^$'
echo ""

echo "4. 마지막 5개 라인 미리보기:"
tail -5 "$LATEST_JSONL" | jq -c '{type, tool_name, sender, text: (.text // null | if . then (.[0:50] + "...") else null end)}'
echo ""

echo "5. Assistant 메시지 개수:"
grep -c '"sender":"assistant"' "$LATEST_JSONL" || echo "0"
echo ""

echo "6. Bash 명령어 실행 개수:"
grep -c '"tool_name":"Bash"' "$LATEST_JSONL" || echo "0"
echo ""

echo "7. 파일 수정 개수:"
grep -cE '"tool_name":"(Edit|Write|MultiEdit)"' "$LATEST_JSONL" || echo "0"
