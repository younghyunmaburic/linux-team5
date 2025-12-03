#!/usr/bin/env bash
# clean-disk.sh : 데스크탑/사용자 디렉토리 정리·분석 도구
# - 박성현 담당:
#   1) 메인 스크립트 기본 구조
#   2) 환경 변수 로딩 (config/env.sh)
#   3) 디스크 분석 기능 (df / topdirs / topfiles / old)
#   4) Python 보조 도구(disk_stats.py) 연동 (이 브랜치 포인트)
# ** Merge Conflict 해결하기

set -euo pipefail

VERSION="0.3.0"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/config/env.sh"
TOOLS_DIR="$PROJECT_ROOT/tools"
DEFAULT_LOG_DIR="$PROJECT_ROOT/logs"

mkdir -p "$DEFAULT_LOG_DIR"

# env.sh 로딩
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi

# env.sh에 없으면 기본값
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

pause() {
  read -rp "계속하려면 Enter를 누르세요..." _
}

print_header() {
  clear
  echo "======================================"
  echo "   Clean Disk (disk + python stats)"
  echo "======================================"
  echo "  분석 대상 : $CMD_TARGET_DIR"
  echo "  로그 파일 : $LOG_FILE"
  echo "  TOP N     : $CMD_TOP_N"
  echo "======================================"
  echo
}

# ---------------------------
# 1) df: 대상 디렉토리 기준 디스크 사용량
# ---------------------------
analyze_disk_overview() {
  log "[df] 대상 디렉토리 기준 디스크 사용량"

  echo ">>> 분석 대상 디렉토리: $CMD_TARGET_DIR"
  echo

  # 1) CMD_TARGET_DIR가 올라가 있는 파일시스템의 사용량
  df -h "$CMD_TARGET_DIR" | tee -a "$LOG_FILE"
  echo

  # 2) 그 디렉토리 자체의 용량
  echo ">>> 분석 대상 디렉토리 자체 용량"
  du -sh "$CMD_TARGET_DIR" 2>/dev/null | tee -a "$LOG_FILE"
  echo
}

# ---------------------------
# 2) topdirs: 큰 디렉토리 TOP N
# ---------------------------
cmd_topdirs() {
  local n="${1:-$CMD_TOP_N}"

  log "[topdirs] $CMD_TARGET_DIR 하위 디렉토리 용량 상위 ${n}개"
  echo ">>> [topdirs] $CMD_TARGET_DIR 하위 디렉토리 용량 상위 ${n}개"
  echo

  du -sh "$CMD_TARGET_DIR"/* 2>/dev/null \
    | sort -h \
    | tail -n "$n" \
    | tee -a "$LOG_FILE"

  echo
}

# ---------------------------
# 3) topfiles: 큰 파일 TOP N (간단 버전, Bash-only)
# ---------------------------
cmd_topfiles() {
  local n="${1:-$CMD_TOP_N}"

  log "[topfiles] $CMD_TARGET_DIR 하위 큰 파일 상위 ${n}개"
  echo ">>> [topfiles] $CMD_TARGET_DIR 하위 큰 파일 상위 ${n}개"
  echo

  # GNU find 기준 (-printf). macOS에서는 gfind를 쓰거나, 이 부분은 Linux 중심이라고 보고 감안.
  find "$CMD_TARGET_DIR" -type f -printf '%s %p\n' 2>/dev/null \
    | sort -nr \
    | head -n "$n" \
    | awk '{
        sz=$1; path=$2;
        unit="B";
        if (sz>1024){sz/=1024;unit="KB"}
        if (sz>1024){sz/=1024;unit="MB"}
        if (sz>1024){sz/=1024;unit="GB"}
        printf "%8.1f%s  %s\n", sz, unit, path
      }' \
    | tee -a "$LOG_FILE"

  echo
}

# ---------------------------
# 4) old: 오래된 파일 목록 (정리 후보 보기용)
# ---------------------------
cmd_old() {
  local days="${1:-30}"

  log "[old] $CMD_TARGET_DIR 기준 ${days}일 이전 파일 목록"
  echo ">>> [old] $CMD_TARGET_DIR 기준 ${days}일 이전 파일 목록"
  echo "    (정리 후보만 보여주며, 실제 삭제는 하지 않습니다.)"
  echo

  find "$CMD_TARGET_DIR" -type f -mtime "+$days" 2>/dev/null \
    | sort \
    | tee -a "$LOG_FILE"

  echo
}

# ---------------------------
# 5) python: Python 보조 도구(disk_stats.py) 실행
# ---------------------------
cmd_python_stats() {
  log "[python] Python 보조 도구(disk_stats.py) 실행"

  if ! command -v python3 &>/dev/null; then
    echo "python3 명령을 찾을 수 없습니다. Python이 설치되어 있는지 확인하세요." | tee -a "$LOG_FILE"
    echo
    return
  fi

  local target="$CMD_TARGET_DIR"
  local top_n="$CMD_TOP_N"

  echo ">>> [python] 분석 도구 실행:"
  echo "    - 대상 디렉토리: $target"
  echo "    - 상위 파일/확장자 개수: $top_n"
  echo

  python3 "$TOOLS_DIR/disk_stats.py" "$target" "$top_n" | tee -a "$LOG_FILE"
  echo
}

# ---------------------------
# 메뉴
# ---------------------------
show_menu() {
  print_header
  echo "[분석 기능]"
  echo " 1) df        : 대상 디렉토리 기준 디스크 사용량"
  echo " 2) topdirs   : 큰 디렉토리 TOP N"
  echo " 3) topfiles  : 큰 파일 TOP N (Bash 버전)"
  echo " 4) old       : 오래된 파일 목록(days 기준)"
  echo " 5) python    : Python 보조 통계 도구(disk_stats.py)"
  echo
  echo " 9) 종료"
  echo
  read -rp "메뉴를 선택하세요: " choice

  case "$choice" in
    1) analyze_disk_overview; pause ;;
    2) cmd_topdirs;           pause ;;
    3) cmd_topfiles;          pause ;;
    4)
       read -rp "며칠 이전 파일을 볼까요? (기본 30): " d
       d=${d:-30}
       cmd_old "$d"
       pause
       ;;
    5) cmd_python_stats;      pause ;;
    9)
       log "프로그램을 종료합니다."
       exit 0
       ;;
    *)
       echo "잘못된 입력입니다."
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