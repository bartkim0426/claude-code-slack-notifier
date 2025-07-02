#!/bin/bash

# Claude Code Slack Notifier - 디버그 설치 스크립트

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 Claude Code Slack Notifier 설치를 시작합니다 (디버그 모드)...${NC}"
echo ""

# 1. 설치 디렉토리 생성
INSTALL_DIR="$HOME/.claude-slack-notifier"
mkdir -p "$INSTALL_DIR"/{hooks,logs}

# 2. 설정 파일 생성
if [ ! -f "$INSTALL_DIR/config" ]; then
    cat > "$INSTALL_DIR/config" << 'EOF'
# Claude Slack Notifier 설정
SLACK_WEBHOOK_URL=""

# 알림 옵션
NOTIFY_PERMISSIONS=true
NOTIFY_COMPLETION=true
NOTIFY_ERRORS=false

# 디버그 모드
DEBUG_MODE=false
EOF
    echo -e "${YELLOW}📝 설정 파일이 생성되었습니다: $INSTALL_DIR/config${NC}"
fi

# 3. Hook 스크립트 다운로드 (디버그 모드)
echo "📥 Hook 스크립트를 다운로드합니다..."

# GitHub API로 파일 존재 여부 확인
echo "GitHub API로 파일 확인 중..."
NOTIFICATION_URL="https://api.github.com/repos/bartkim0426/claude-code-slack-notifier/contents/hooks/notification-hook.sh"
STOP_URL="https://api.github.com/repos/bartkim0426/claude-code-slack-notifier/contents/hooks/stop-hook.sh"

echo "Checking: $NOTIFICATION_URL"
curl -s "$NOTIFICATION_URL" | jq -r '.download_url // "NOT FOUND"'

echo "Checking: $STOP_URL"
curl -s "$STOP_URL" | jq -r '.download_url // "NOT FOUND"'

# Raw URL로 직접 다운로드 시도
NOTIFICATION_RAW="https://raw.githubusercontent.com/bartkim0426/claude-code-slack-notifier/main/hooks/notification-hook.sh"
STOP_RAW="https://raw.githubusercontent.com/bartkim0426/claude-code-slack-notifier/main/hooks/stop-hook.sh"

echo ""
echo "다운로드 시도 중..."
echo "URL: $NOTIFICATION_RAW"

# curl의 전체 응답 확인
curl -L -v "$NOTIFICATION_RAW" -o "$INSTALL_DIR/hooks/notification-hook.sh" 2>&1 | grep -E "HTTP|Location|404"

echo ""
echo "URL: $STOP_RAW"
curl -L -v "$STOP_RAW" -o "$INSTALL_DIR/hooks/stop-hook.sh" 2>&1 | grep -E "HTTP|Location|404"

# 파일 확인
echo ""
echo "다운로드된 파일 확인:"
ls -la "$INSTALL_DIR/hooks/"

# 실행 권한 부여
chmod +x "$INSTALL_DIR/hooks/"*.sh 2>/dev/null || true

echo ""
echo -e "${GREEN}✅ 디버그 완료${NC}"