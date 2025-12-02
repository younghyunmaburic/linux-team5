# 자동 생성된 Clean Disk 설정 파일 (기본값 템플릿)

# 1) 기본 분석 대상 디렉토리 (보통 홈이나 Desktop)
CMD_TARGET_DIR="$HOME"

# 2) 상위 몇 개의 대용량 디렉토리를 보여줄지
CMD_TOP_N=10

# 3) 로그 디렉토리 (프로젝트 루트 기준 상대경로)
CMD_LOG_DIR="logs"

# 4) dry-run 모드 (1 = 삭제 안 함, 0 = 실제 삭제)
CMD_DRY_RUN=1

# 5) 중복 다운로드 디렉토리 (보통 Downloads)
CMD_DOWNLOAD_DIR="$HOME/Downloads"

# 6) 스크린샷 디렉토리 (OS별 자동 감지용으로 기본은 주석 처리)
# CMD_SCREENSHOT_DIR="$HOME/Pictures/Screenshots"

# 7) 스크린샷 정리 기준 일수
CMD_SCREENSHOT_DAYS=30