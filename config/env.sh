# 디스크 분석 기본 설정

# 1) 기본 분석 대상 디렉토리 (df, du 등에서 사용할 기본 경로)
CMD_TARGET_DIR="$HOME"

# 2) 상위 몇 개의 대용량 디렉토리를 보여줄지
CMD_TOP_N=10

# 3) 로그 디렉토리
CMD_LOG_DIR="logs"

# 4) dry-run 모드 (1이면 실제 삭제 X, 미리보기/목록만 출력)
CMD_DRY_RUN=1

# 5) 중복 다운로드 파일을 찾을 디렉토리 (보통 Downloads)
CMD_DOWNLOAD_DIR="$HOME/Downloads"

# 6) 스크린샷이 저장되는 디렉토리 (리눅스 환경에 따라 맞춰서 수정)
#   예) GNOME 기본: $HOME/Pictures, $HOME/Pictures/Screenshots 등
CMD_SCREENSHOT_DIR="$HOME/Pictures/Screenshots"

# 7) 스크린샷 정리 대상 기준 (며칠 이전 파일을 후보로 볼 것인지)
CMD_SCREENSHOT_DAYS=30
