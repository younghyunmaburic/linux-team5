#!/usr/bin/env bash
# clean-disk.sh : 디스크 분석/정리 메인 스크립트

set -euo pipefail

VERSION="0.2.0"

# ---------------------------
# 0. 경로/환경 설정
# ---------------------------

# 이 스크립트가 있는 디렉토리 (예: /home/.../clean-disk/scripts)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# 프로젝트 루트 (= scripts 상위)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG_FILE="$PROJECT_ROOT/config/env.sh"
TOOLS_DIR="$PROJECT_ROOT/tools"
DEFAULT_LOG_DIR="$PROJECT_ROOT/logs"

# env.sh 로딩 (있으면)
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# env.sh에 값이 없으면 기본값 세팅
: "${CMD_TARGET_DIR:="$HOME"}"
: "${CMD_TOP_N:=10}"
: "${CMD_LOG_DIR:="$DEFAULT_LOG_DIR"}"
: "${CMD_DRY_RUN:=1}"
: "${CMD_DOWNLOAD_DIR:="$HOME/Downloads"}"
: "${CMD_SCREENSHOT_DIR:="$HOME/Pictures/Screenshots"}"
: "${CMD_SCREENSHOT_DAYS:=30}"

mkdir -p "$CMD_LOG_DIR"

LOG_FILE="$CMD_LOG_DIR/clean-disk-$(date +'%Y%m%d_%H%M%S').log"

# ---------------------------
# 1. 공통 유틸 함수
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
    echo "           Clean Disk v$VERSION"
    echo "======================================"
    echo "  프로젝트 루트 : $PROJECT_ROOT"
    echo "  분석 대상    : $CMD_TARGET_DIR"
    echo "  로그 파일    : $LOG_FILE"
    echo "  dry-run 모드 : $CMD_DRY_RUN"
    echo "--------------------------------------"
    echo "  다운로드 경로: $CMD_DOWNLOAD_DIR"
    echo "  스크린샷 경로: $CMD_SCREENSHOT_DIR"
    echo "  스샷 기준일수: $CMD_SCREENSHOT_DAYS일 이전"
    echo "======================================"
    echo
}

# ---------------------------
# 2. 디스크 분석 기능
# ---------------------------

# (1) 전체 디스크 사용량(df -h)
analyze_disk_overview() {
    log "[분석] 전체 디스크 사용량(df -h)"
    df -h | tee -a "$LOG_FILE"
    echo
    pause
}

# (2) 대상 디렉토리 하위의 상위 대용량 디렉토리
analyze_top_directories() {
    log "[분석] $CMD_TARGET_DIR 하위 디렉토리 용량 상위 목록"
    echo ">>> $CMD_TARGET_DIR 하위 디렉토리 용량 상위 $CMD_TOP_N개"
    du -sh "$CMD_TARGET_DIR"/* 2>/dev/null | sort -h | tail -n "$CMD_TOP_N" \
        | tee -a "$LOG_FILE"
    echo
    pause
}

# (3) Python 보조 도구 호출
analyze_with_python_tool() {
    log "[분석] Python 보조 도구(disk_stats.py) 실행"

    if ! command -v python3 &>/dev/null; then
        echo "python3 명령을 찾을 수 없습니다. Python이 설치되어 있는지 확인하세요." | tee -a "$LOG_FILE"
        pause
        return
    fi

    local target="$CMD_TARGET_DIR"
    local top_n="$CMD_TOP_N"

    echo ">>> Python 분석 도구 실행:"
    echo "    - 대상 디렉토리: $target"
    echo "    - 상위 파일 개수: $top_n"
    echo

    python3 "$TOOLS_DIR/disk_stats.py" "$target" "$top_n" | tee -a "$LOG_FILE"
    echo
    pause
}

# ---------------------------
# 3. 중복 다운로드 / 스크린샷 정리 기능
# ---------------------------

# (4) 중복 다운로드 의심 파일 찾기/정리
find_duplicate_downloads() {
    local dir="$CMD_DOWNLOAD_DIR"

    log "[분석] 중복 다운로드 의심 파일 검색: $dir"

    if [[ ! -d "$dir" ]]; then
        echo "중복 다운로드 디렉토리($dir)를 찾을 수 없습니다." | tee -a "$LOG_FILE"
        pause
        return
    fi

    echo ">>> $dir 안에서 이름에 (2), (3) 같은 숫자가 붙은 파일을 찾습니다."
    echo "    예) report.pdf, report(2).pdf, report(3).pdf ..."
    echo

    local count=0

    # 예: 1234(2).pdf, 보고서(3).hwp 등
    while IFS= read -r path; do
        local base="${path##*/}"
        if [[ "$base" =~ ^.+\([0-9]+\)\.[^.]+$ ]]; then
            ((count++))
            echo "[$count] $path"

            if [[ "${CMD_DRY_RUN}" -eq 0 ]]; then
                read -rp "  → 이 파일을 삭제할까요? [y/N]: " ans
                case "$ans" in
                    y|Y)
                        rm -v -- "$path" | tee -a "$LOG_FILE"
                        ;;
                    *)
                        echo "  유지함."
                        ;;
                esac
            fi
        fi
    done < <(find "$dir" -maxdepth 1 -type f 2>/dev/null)

    if [[ "$count" -eq 0 ]]; then
        echo "중복 다운로드 의심 파일을 찾지 못했습니다."
    else
        echo
        echo "총 ${count}개의 중복 다운로드 의심 파일을 찾았습니다."
        if [[ "${CMD_DRY_RUN}" -eq 1 ]]; then
            echo "(현재 dry-run 모드이므로 실제 삭제는 하지 않았습니다.)"
        fi
    fi

    echo
    pause
}

# (5) 스크린샷 정리 (X일 이전 파일들 후보로)
clean_screenshots() {
    local dir="$CMD_SCREENSHOT_DIR"
    local days="$CMD_SCREENSHOT_DAYS"

    log "[정리] 스크린샷 정리 후보 검색: $dir, ${days}일 이전 파일"

    if [[ ! -d "$dir" ]]; then
        echo "스크린샷 디렉토리($dir)를 찾을 수 없습니다." | tee -a "$LOG_FILE"
        pause
        return
    fi

    echo ">>> $dir 안에서 ${days}일 이전의 스크린샷 파일을 찾습니다."
    echo "    (보통 공부/과제 끝난 뒤 오래된 캡처들을 정리하는 용도)"
    echo

    mapfile -t candidates < <(find "$dir" -maxdepth 1 -type f -mtime +"$days" 2>/dev/null | sort)

    local count="${#candidates[@]}"

    if [[ "$count" -eq 0 ]]; then
        echo "${days}일 이전 스크린샷 후보가 없습니다."
        pause
        return
    fi

    echo "=== 정리 후보 스크린샷 (${count}개) ==="
    for path in "${candidates[@]}"; do
        echo "$path"
    done
    echo

    if [[ "${CMD_DRY_RUN}" -eq 1 ]]; then
        echo "(dry-run 모드이므로 실제 삭제는 하지 않습니다.)"
        pause
        return
    fi

    read -rp "위 스크린샷들을 모두 삭제할까요? [y/N]: " all_ans
    case "$all_ans" in
        y|Y)
            for path in "${candidates[@]}"; do
                rm -v -- "$path" | tee -a "$LOG_FILE"
            done
            echo "스크린샷 정리가 완료되었습니다."
            ;;
        *)
            echo "삭제를 취소했습니다."
            ;;
    esac

    echo
    pause
}

# ---------------------------
# 4. 메뉴 & 메인 루프
# ---------------------------

show_menu() {
    print_header
    echo "1) 전체 디스크 사용량 보기(df -h)"
    echo "2) 대상 디렉토리 상위 대용량 디렉토리(du -sh)"
    echo "3) Python 보조 도구로 상세 파일 분석"
    echo "4) 중복 다운로드 의심 파일 찾기/정리"
    echo "5) 스크린샷 정리 (X일 이전 파일들)"
    echo "6) 종료"
    echo
    read -rp "메뉴를 선택하세요: " choice

    case "$choice" in
        1) analyze_disk_overview ;;
        2) analyze_top_directories ;;
        3) analyze_with_python_tool ;;
        4) find_duplicate_downloads ;;
        5) clean_screenshots ;;
        6) log "프로그램을 종료합니다."; exit 0 ;;
        *) echo "잘못된 입력입니다."; sleep 1 ;;
    esac
}

main() {
    while true; do
        show_menu
    done
}

main "$@"
