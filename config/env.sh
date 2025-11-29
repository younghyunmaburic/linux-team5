# config/env.sh
# Clean Disk 환경 설정 파일
# - 이 파일은 ./scripts/clean-disk.sh setup 으로 자동 생성/수정할 수 있음.
# - 필요하면 수동으로 값들을 바꿔도 됨.

# 기본 분석 대상 디렉토리 (설정 안 하면 OS별 Desktop 자동 추론 사용)
# CMD_TARGET_DIR="$HOME/Desktop"

# topdirs / topfiles 에서 보여줄 상위 개수
# CMD_TOP_N=10

# 로그 디렉토리 (프로젝트 기준 상대경로)
# CMD_LOG_DIR="logs"

# dry-run 모드 (1 = 삭제 안 함, 0 = 실제 삭제)
# CMD_DRY_RUN=1

# 중복 다운로드 의심 파일을 찾을 디렉토리
# CMD_DOWNLOAD_DIR="$HOME/Downloads"

# 스크린샷 정리 대상 디렉토리와 기준 일수
# CMD_SCREENSHOT_DIR="$HOME/Desktop"
# CMD_SCREENSHOT_DAYS=30
