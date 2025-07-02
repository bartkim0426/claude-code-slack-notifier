#!/bin/bash

# JSONL 파일의 실제 구조를 자세히 분석

JSONL_FILE="$1"

if [ -z "$JSONL_FILE" ]; then
    # 가장 최근 파일 자동 찾기
    PROJECT_DIR="$HOME/.claude/projects/*vibe-web-transformer*"
    JSONL_FILE=$(ls -t $PROJECT_DIR/*.jsonl 2>/dev/null | head -1)
fi

if [ ! -f "$JSONL_FILE" ]; then
    echo "JSONL 파일을 찾을 수 없습니다."
    exit 1
fi

echo "분석 대상 파일: $JSONL_FILE"
echo ""

echo "=== 각 type별 샘플 데이터 ==="
echo ""

echo "1. type=user 샘플:"
grep '"type":"user"' "$JSONL_FILE" | tail -1 | jq '.'
echo ""

echo "2. type=assistant 샘플:"
grep '"type":"assistant"' "$JSONL_FILE" | tail -1 | jq '.'
echo ""

echo "3. type=summary 샘플:"
grep '"type":"summary"' "$JSONL_FILE" | head -1 | jq '.'
echo ""

echo "4. type=system 샘플:"
grep '"type":"system"' "$JSONL_FILE" | head -1 | jq '.'
echo ""

echo "=== 특정 패턴 검색 ==="
echo ""

echo "5. 'text' 필드가 있는 라인 확인:"
jq 'select(.text != null) | {type, text: (.text | .[0:100])}' "$JSONL_FILE" | tail -5
echo ""

echo "6. 'content' 필드가 있는 라인 확인:"
jq 'select(.content != null) | {type, content: (.content | .[0:100])}' "$JSONL_FILE" | tail -5
echo ""

echo "7. 'tool' 관련 필드 검색:"
jq '. | select(. | to_entries | map(.key) | any(contains("tool")))' "$JSONL_FILE" | tail -5
echo ""

echo "8. 모든 키 조합 확인:"
jq -s 'map(keys) | add | unique | sort' "$JSONL_FILE"
echo ""

echo "9. leafUuid와 summary가 있는 첫 번째 항목 상세:"
jq 'select(.leafUuid != null)' "$JSONL_FILE" | head -1 | jq '.'
