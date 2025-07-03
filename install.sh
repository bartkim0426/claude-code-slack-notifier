#!/bin/bash

# Claude Code Slack Notifier - 설치 스크립트
# 한 번의 명령으로 모든 것을 설정

set -e

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 Claude Code Slack Notifier 설치를 시작합니다...${NC}"
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

# 3. Hook 스크립트 다운로드
echo "📥 Hook 스크립트를 다운로드합니다..."

# Notification Hook
curl -fsSL "https://raw.githubusercontent.com/bartkim0426/claude-code-slack-notifier/main/hooks/notification-hook.sh" \
    -o "$INSTALL_DIR/hooks/notification-hook.sh"

# Stop Hook
curl -fsSL "https://raw.githubusercontent.com/bartkim0426/claude-code-slack-notifier/main/hooks/stop-hook.sh" \
    -o "$INSTALL_DIR/hooks/stop-hook.sh"

# 실행 권한 부여
chmod +x "$INSTALL_DIR/hooks/"*.sh

# 4. 유틸리티 스크립트 설치
echo "🔧 유틸리티 스크립트를 설치합니다..."

# claude-slack-config 명령어
cat > "$HOME/.local/bin/claude-slack-config" << 'EOF'
#!/bin/bash

CONFIG_FILE="$HOME/.claude-slack-notifier/config"

show_help() {
    echo "Claude Slack Notifier 설정 도구"
    echo ""
    echo "사용법:"
    echo "  claude-slack-config                  인터렉티브 모드 (기본)"
    echo "  claude-slack-config -i, --interactive  인터렉티브 모드"
    echo "  claude-slack-config -e, --edit        편집기 모드"
    echo "  claude-slack-config -h, --help        도움말"
}

interactive_mode() {
    echo "🔧 Claude Slack Notifier 설정"
    echo "=============================="
    echo ""
    
    # 현재 설정 표시
    if [ -f "$CONFIG_FILE" ]; then
        current_url=$(grep "SLACK_WEBHOOK_URL=" "$CONFIG_FILE" | cut -d'"' -f2)
        if [ -n "$current_url" ] && [ "$current_url" != "" ]; then
            echo "현재 Webhook URL: ${current_url:0:50}..."
        else
            echo "현재 Webhook URL: 설정되지 않음"
        fi
        echo ""
    fi
    
    echo "새 Slack Webhook URL을 입력하세요:"
    echo "(예: https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX)"
    echo ""
    read -p "Webhook URL: " webhook_url
    
    if [ -z "$webhook_url" ]; then
        echo "❌ URL이 입력되지 않았습니다."
        exit 1
    fi
    
    # URL 검증
    if [[ ! "$webhook_url" =~ ^https://hooks\.slack\.com/services/ ]]; then
        echo "⚠️  경고: Slack Webhook URL 형식이 아닌 것 같습니다."
        read -p "계속하시겠습니까? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "설정이 취소되었습니다."
            exit 1
        fi
    fi
    
    # 설정 파일 업데이트
    sed -i.bak "s|SLACK_WEBHOOK_URL=\".*\"|SLACK_WEBHOOK_URL=\"$webhook_url\"|" "$CONFIG_FILE"
    
    echo ""
    echo "✅ Slack Webhook URL이 설정되었습니다!"
    echo ""
    echo "설정을 확인하려면: claude-slack-doctor"
}

editor_mode() {
    ${EDITOR:-vim} "$CONFIG_FILE"
}

# 메인 로직
case "$1" in
    -h|--help)
        show_help
        ;;
    -e|--edit)
        editor_mode
        ;;
    -i|--interactive)
        interactive_mode
        ;;
    "")
        interactive_mode
        ;;
    *)
        echo "알 수 없는 옵션: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
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
    
    # Hook 추가 - Notification과 Stop 이벤트 사용
    jq '.hooks.Notification = (.hooks.Notification // []) + [{
        "matcher": "*",
        "hooks": [{
            "type": "command",
            "command": "'"$INSTALL_DIR/hooks/notification-hook.sh"'"
        }]
    }] | .hooks.Stop = (.hooks.Stop // []) + [{
        "matcher": "*", 
        "hooks": [{
            "type": "command",
            "command": "'"$INSTALL_DIR/hooks/stop-hook.sh"'"
        }]
    }]' "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp" && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
    
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
echo "도움말: https://github.com/bartkim0426/claude-code-slack-notifier"