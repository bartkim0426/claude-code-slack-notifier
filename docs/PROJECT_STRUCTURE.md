# 프로젝트 구조

```
claude-code-slack-notifier/
├── README.md                    # 메인 문서
├── CONTRIBUTING.md              # 기여 가이드
├── CHANGELOG.md                 # 변경 이력
├── LICENSE                      # MIT 라이센스
├── install.sh                   # 원클릭 설치 스크립트
├── setup.sh                     # 수동 설치 스크립트
├── test.sh                      # 테스트 스위트
│
├── hooks/                       # Hook 스크립트
│   ├── notification-hook.sh     # 권한 요청 알림
│   ├── stop-hook.sh            # 작업 완료 알림
│   ├── error-hook.sh           # 에러 알림 (선택사항)
│   └── base-hook.sh            # 공통 함수 라이브러리
│
├── config/                      # 설정 템플릿
│   ├── config.example          # 기본 설정 예시
│   ├── channel-map.example.json # 채널 매핑 예시
│   └── filters.example.json    # 필터 설정 예시
│
├── utils/                       # 유틸리티 명령어
│   ├── claude-slack-config     # 설정 편집
│   ├── claude-slack-doctor     # 설치 진단
│   ├── claude-slack-test       # 테스트 알림
│   ├── claude-slack-update     # 업데이트
│   ├── claude-slack-uninstall  # 제거
│   ├── claude-slack-export     # 설정 내보내기
│   └── claude-slack-import     # 설정 가져오기
│
├── scripts/                     # 개발/배포 스크립트
│   ├── setup-dev.sh            # 개발 환경 설정
│   ├── build.sh                # 빌드 스크립트
│   └── release.sh              # 릴리즈 스크립트
│
├── tests/                       # 테스트
│   ├── test_helper.sh          # 테스트 헬퍼
│   ├── test_installation.sh    # 설치 테스트
│   ├── test_notifications.sh   # 알림 테스트
│   └── test_utilities.sh       # 유틸리티 테스트
│
├── docs/                        # 문서 및 이미지
│   ├── demo.gif                # 데모 GIF
│   ├── permission-request.png  # 스크린샷
│   ├── work-complete.png       # 스크린샷
│   └── setup-guide.md          # 상세 설정 가이드
│
├── examples/                    # 예시
│   ├── team-config.json        # 팀 설정 예시
│   ├── custom-template.json    # 커스텀 템플릿
│   └── integration.yml         # CI/CD 통합 예시
│
└── .github/                     # GitHub 설정
    ├── workflows/
    │   ├── test.yml            # 테스트 자동화
    │   └── release.yml         # 릴리즈 자동화
    ├── ISSUE_TEMPLATE/
    │   ├── bug_report.md       # 버그 리포트 템플릿
    │   └── feature_request.md  # 기능 요청 템플릿
    └── PULL_REQUEST_TEMPLATE.md # PR 템플릿
```

## 🚀 GitHub에 올리기

```bash
# 1. 프로젝트 디렉토리 생성
mkdir claude-code-slack-notifier
cd claude-code-slack-notifier

# 2. 파일 구조 생성
mkdir -p hooks config utils scripts tests docs examples .github/workflows .github/ISSUE_TEMPLATE

# 3. 기존 스크립트 복사
cp ~/claude-stop-final.sh hooks/stop-hook.sh
cp ~/claude-notification-detail.sh hooks/notification-hook.sh

# 4. Git 초기화
git init
git add .
git commit -m "🎉 Initial commit - Claude Code Slack Notifier"

# 5. GitHub 레포 생성 후 push
git remote add origin https://github.com/YOUR_USERNAME/claude-code-slack-notifier.git
git branch -M main
git push -u origin main

# 6. 태그 추가
git tag -a v1.0.0 -m "First release"
git push origin v1.0.0
```

## 📝 마지막 체크리스트

- [ ] README.md의 [your-username] 부분을 실제 GitHub 사용자명으로 변경
- [ ] 실제 Slack webhook URL 예시는 가짜로 교체
- [ ] 스크린샷/데모 GIF 추가 (선택사항)
- [ ] GitHub Actions 설정 (선택사항)
- [ ] GitHub Pages로 문서 사이트 만들기 (선택사항)