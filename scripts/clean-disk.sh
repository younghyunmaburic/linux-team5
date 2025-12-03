#!/usr/bin/env bash
# clean-disk.sh : (수정됨) 순수 디스크 정리/삭제 모듈
# Feature 2 전용

set -euo pipefail

VERSION="0.2.1-clean-only"

# ---------------------------
# 0. 경로/환경 설정
# ---------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG_FILE="$PROJECT_ROOT/config/env.sh"
DEFAULT_LOG_DIR="$PROJECT_ROOT/logs"

# env.sh 로딩
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# 기본값 세팅
: "${CMD_LOG_DIR:="$DEFAULT_LOG_DIR"}"
: "${CMD_DRY_RUN:=1}"
: "${CMD_DOWNLOAD_DIR:="$HOME/Downloads"}"
: "${CMD_SCREENSHOT_DIR:="$HOME/Pictures/Screenshots"}"
: "${CMD_SCREENSHOT_DAYS:=30}"

mkdir -p "$CMD_LOG_DIR"
LOG_FILE="$CMD_LOG_DIR/clean-disk-$(date +'%Y%m%d_%H%M%S').log"

# ---------------------------
# 1. 유틸 함수
# ---------------------------
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
    echo "       Clean Disk (삭제 전용 모드)"
    echo "======================================"
    echo "  로그 파일    : $LOG_FILE"
    echo "  dry-run 모드 : $CMD_DRY_RUN (1=가짜실행, 0=실제삭제)"
    echo "--------------------------------------"
    echo "  다운로드 경로: $CMD_DOWNLOAD_DIR"
    echo "  스크린샷 경로: $CMD_SCREENSHOT_DIR"
    echo "======================================"
    echo
}

# ---------------------------
# 2. 정리(Clean) 기능만 유지
# ---------------------------

# (1) 중복 다운로드 정리
find_duplicate_downloads() {
    local dir="$CMD_DOWNLOAD_DIR"
    log "[정리] 중복 다운로드 정리 시작: $dir"

    if [[ ! -d "$dir" ]]; then
        echo "경로를 찾을 수 없음: $dir"
        pause
        return
    fi

    echo ">>> (1), (2) 등이 붙은 중복 파일 검색 중..."
    local count=0
    
    while IFS= read -r path; do
        local base="${path##*/}"
        if [[ "$base" =~ ^.+\([0-9]+\)\.[^.]+$ ]]; then
            ((count++))
            echo "[$count] $path"
            if [[ "${CMD_DRY_RUN}" -eq 0 ]]; then
                rm -v -- "$path" | tee -a "$LOG_FILE"
            fi
        fi
    done < <(find "$dir" -maxdepth 1 -type f 2>/dev/null)

    echo "총 ${count}개의 중복 파일을 처리했습니다."
    pause
}

# (2) 오래된 스크린샷 정리
clean_screenshots() {
    local dir="$CMD_SCREENSHOT_DIR"
    local days="$CMD_SCREENSHOT_DAYS"
    log "[정리] ${days}일 지난 스크린샷 정리 시작"

    if [[ ! -d "$dir" ]]; then
        echo "경로를 찾을 수 없음: $dir"
        pause
        return
    fi

    mapfile -t candidates < <(find "$dir" -maxdepth 1 -type f -mtime +"$days" 2>/dev/null | sort)
    local count="${#candidates[@]}"

    if [[ "$count" -eq 0 ]]; then
        echo "정리할 스크린샷이 없습니다."
    else
        echo "오래된 스크린샷 ${count}개를 발견했습니다."
        if [[ "${CMD_DRY_RUN}" -eq 0 ]]; then
             for path in "${candidates[@]}"; do
                rm -v -- "$path" | tee -a "$LOG_FILE"
            done
        else
            echo "(Dry-run 모드라 삭제하지 않았습니다)"
        fi
    fi
    pause
}

# ---------------------------
# 3. 메뉴 (분석 기능 제거됨)
# ---------------------------
show_menu() {
    print_header
    echo "1) 중복 다운로드 파일 정리"
    echo "2) 오래된 스크린샷 정리"
    echo "3) 종료"
    echo
    read -rp "선택하세요: " choice

    case "$choice" in
        1) find_duplicate_downloads ;;
        2) clean_screenshots ;;
        3) log "종료합니다."; exit 0 ;;
        *) echo "잘못된 입력"; sleep 1 ;;
    esac
}

main() {
    while true; do show_menu; done
}

main "$@"