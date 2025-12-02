
#!/usr/bin/env bash
# Clean Disk: base script (skeleton)

set -euo pipefail

VERSION="0.1.0"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/config/env.sh"
DEFAULT_LOG_DIR="$PROJECT_ROOT/logs"

mkdir -p "$DEFAULT_LOG_DIR"

 env.sh 있으면 로딩
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi

: "${CMD_TARGET_DIR:="$HOME"}"
: "${CMD_TOP_N:=10}"
: "${CMD_LOG_DIR:="$DEFAULT_LOG_DIR"}"
: "${CMD_DRY_RUN:=1}"

mkdir -p "$CMD_LOG_DIR"
LOG_FILE="$CMD_LOG_DIR/clean-disk-$(date +'%Y%m%d_%H%M%S').log"

log() {
  local msg="[$(date +'%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg" | tee -a "$LOG_FILE"
}

print_header() {
  clear
  echo "======================================"
  echo "       Clean Disk (base version)"
  echo "======================================"
  echo "  분석 대상 : $CMD_TARGET_DIR"
  echo "  로그 파일 : $LOG_FILE"
  echo "======================================"
  echo
}

show_menu() {
  print_header
  echo "[설정/설치]"
  echo " 0) setup (추후 구현 예정)"
  echo
  echo " 9) 종료"
  echo
  read -rp "메뉴를 선택하세요: " choice

  case "$choice" in
    9)
      log "프로그램을 종료합니다."
      exit 0
      ;;
    *)
      echo "아직 구현되지 않은 기능입니다."
      sleep 1
      ;;
  esac
}

main_menu_loop() {
  while true; do
    show_menu
  done
}

main() {
  main_menu_loop
}

main "$@"
EOF