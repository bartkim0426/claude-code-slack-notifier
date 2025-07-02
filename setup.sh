#!/bin/bash

# Claude Code Slack Notifier - 로컬 설치 스크립트
# GitHub 없이 로컬 파일로 설치

set -e

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 Claude Code Slack Notifier 로컬 설치를 시작합니다...${NC}"
echo ""

# 현재 디렉토리 확인
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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

# 3. Hook 스크립트 복사
echo "📥 Hook 스크립트를 설치합니다..."

# 필요한 hook 파일들 복사
cp "$SCRIPT_DIR/hooks/notification-hook.sh" "$INSTALL_DIR/hooks/"
cp "$SCRIPT_DIR/hooks/stop-hook.sh" "$INSTALL_DIR/hooks/"
cp "$SCRIPT_DIR/hooks/base-hook.sh" "$INSTALL_DIR/hooks/"

# 실행 권한 부여
chmod +x "$INSTALL_DIR/hooks/"*.sh

echo -e "${GREEN}✓ Hook 스크립트가 설치되었습니다${NC}"

# 4. 유틸리티 스크립트 설치
echo "🔧 유틸리티 스크립트를 설치합니다..."

mkdir -p "$HOME/.local/bin"

# claude-slack-config 명령어
cat > "$HOME/.local/bin/claude-slack-config" << 'EOF'
#!/bin/bash
${EDITOR:-nano} "$HOME/.claude-slack-notifier/config"
EOF

# claude-slack-doctor 명령어
cat > "$HOME/.local/bin/claude-slack-doctor" << 'EOF'
#!/bin/bash

CONFIG_FILE="$HOME/.claude-slack-notifier/config"
source "$CONFIG_FILE" 2>/dev/null

echo "🔍 Claude Slack Notifier 진단"
echo "=============================="
echo ""

# 설치 확인
echo "✓ 설치 디렉토리: $HOME/.claude-slack-notifier"
echo "✓ 설정 파일: $([ -f "$CONFIG_FILE" ] && echo "존재" || echo "없음")"
echo ""

# Webhook 설정 확인
if [ -z "$SLACK_WEBHOOK_URL" ]; then
    echo "❌ Slack Webhook URL이 설정되지 않았습니다!"
    echo "   실행: claude-slack-config"
else
    echo "✓ Slack Webhook URL 설정됨"
fi
echo ""

# Claude 설정 확인
echo "Claude Code Hook 설정:"
if [ -f "$HOME/.claude/settings.json" ]; then
    echo "✓ Claude 설정 파일 존재"
    # Hook 설정 확인
    if grep -q "notification-hook.sh" "$HOME/.claude/settings.json" 2>/dev/null; then
        echo "✓ Notification Hook 설정됨"
    else
        echo "⚠️  Notification Hook 미설정"
    fi
    if grep -q "stop-hook.sh" "$HOME/.claude/settings.json" 2>/dev/null; then
        echo "✓ Stop Hook 설정됨"
    else
        echo "⚠️  Stop Hook 미설정"
    fi
else
    echo "❌ Claude 설정 파일 없음"
fi
EOF

chmod +x "$HOME/.local/bin/claude-slack-config"
chmod +x "$HOME/.local/bin/claude-slack-doctor"

# PATH에 추가 안내
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo -e "${YELLOW}ℹ️  PATH에 ~/.local/bin을 추가하세요:${NC}"
    echo "   echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
    echo "   source ~/.bashrc"
fi

# 5. Claude Code에 Hook 자동 등록 (settings.json 수정)
echo "⚙️  Claude Code에 Hook을 등록합니다..."

CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [ ! -f "$CLAUDE_SETTINGS" ]; then
    mkdir -p "$HOME/.claude"
    echo '{}' > "$CLAUDE_SETTINGS"
fi

# jq를 사용하여 안전하게 Hook 추가
if command -v jq &> /dev/null; then
    # Backup 생성
    cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.backup"
    
    # Hook 추가
    jq '.hooks.Notification = {
        "": {
            "hooks": [{
                "type": "command",
                "command": "'"$INSTALL_DIR/hooks/notification-hook.sh"'"
            }]
        }
    } | .hooks.Stop = {
        "": {
            "hooks": [{
                "type": "command",
                "command": "'"$INSTALL_DIR/hooks/stop-hook.sh"'"
            }]
        }
    }' "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp" && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
    
    echo -e "${GREEN}✓ Hook이 자동으로 등록되었습니다!${NC}"
else
    echo -e "${YELLOW}⚠️  jq가 설치되어 있지 않아 수동으로 Hook을 등록해야 합니다.${NC}"
    echo "   Claude Code에서 /hooks 명령어를 실행하여 다음을 추가하세요:"
    echo "   - Notification: $INSTALL_DIR/hooks/notification-hook.sh"
    echo "   - Stop: $INSTALL_DIR/hooks/stop-hook.sh"
fi

# 6. 완료 메시지
echo ""
echo -e "${GREEN}✅ 설치가 완료되었습니다!${NC}"
echo ""
echo "다음 단계:"
echo "1. Slack Webhook URL 설정:"
echo "   $ claude-slack-config"
echo "   SLACK_WEBHOOK_URL에 Webhook URL을 입력하세요"
echo ""
echo "2. 설치 확인:"
echo "   $ claude-slack-doctor"
echo ""
echo "3. Claude Code를 재시작하면 알림이 작동합니다!"
echo ""