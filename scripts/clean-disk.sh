#!/usr/bin/env bash
# clean-disk.sh : 데스크탑/사용자 디렉토리 정리·분석 도구
# - 박성현 담당:
#   1) 메인 스크립트 기본 구조
#   2) 환경 변수 로딩 (config/env.sh)
#   3) 디스크 분석 기능 (df / topdirs / topfiles / old + Python 통계)
#   4) Python 보조 도구(disk_stats.py) 연동
#
# + OS 감지, Desktop 자동 탐색, 설정 마법사(setup)

set -euo pipefail

VERSION="0.5.0"

# ---------------------------
# 0. 기본 경로 설정
# ---------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG_FILE="$PROJECT_ROOT/config/env.sh"
TOOLS_DIR="$PROJECT_ROOT/tools"
DEFAULT_LOG_DIR="$PROJECT_ROOT/logs"

mkdir -p "$DEFAULT_LOG_DIR"

DELETE_MODULE="$SCRIPT_DIR/delete_module.sh"
if [[ -f "$DELETE_MODULE" ]]; then
    # shellcheck source=/dev/null
    source "$DELETE_MODULE"

    # delete_module.sh 안의 clean_logs가 쓸 로그 경로를 프로젝트 루트 기준으로 맞춰줌 (선택사항)
    if declare -F clean_logs &>/dev/null; then
        LOG_DIR="$DEFAULT_LOG_DIR"
        TIMESTAMP="$(date +'%Y-%m-%d_%H%M')"
        REPORT_FILE="$LOG_DIR/cleanup_report_$TIMESTAMP.txt"
        mkdir -p "$LOG_DIR"
    fi
else
    :
fi

# ---------------------------
# 0-1. OS 감지 / Desktop 경로 자동 탐색
# ---------------------------

detect_os() {
    local u
    u="$(uname -s 2>/dev/null || echo "UNKNOWN")"

    case "$u" in
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "WSL"
            else
                echo "Linux"
            fi
            ;;
        Darwin)
            echo "macOS"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "GitBash"
            ;;
        *)
            echo "UNKNOWN"
            ;;
    esac
}

detect_desktop_dir() {
    local kind="$1"
    local d=""

    case "$kind" in
        Linux|WSL)
            if command -v xdg-user-dir &>/dev/null; then
                d="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
            fi
            if [[ -z "$d" ]]; then
                for cand in "$HOME/Desktop" "$HOME/바탕 화면" "$HOME/바탕화면"; do
                    if [[ -d "$cand" ]]; then
                        d="$cand"
                        break
                    fi
                done
            fi
            ;;
        macOS)
            if [[ -d "$HOME/Desktop" ]]; then
                d="$HOME/Desktop"
            fi
            ;;
        GitBash)
            if [[ -n "${USERPROFILE:-}" ]]; then
                local win_desktop="${USERPROFILE}\\Desktop"
                if command -v cygpath &>/dev/null; then
                    d="$(cygpath "$win_desktop" 2>/dev/null || echo "")"
                fi
            fi
            if [[ -z "$d" && -d "$HOME/Desktop" ]]; then
                d="$HOME/Desktop"
            fi
            ;;
        *)
            ;;
    esac

    if [[ -z "$d" ]]; then
        d="$HOME"
    fi

    echo "$d"
}

OS_KIND="$(detect_os)"
DEFAULT_DESKTOP_DIR="$(detect_desktop_dir "$OS_KIND")"

# ---------------------------
# 0-2. env.sh 로딩 + 기본값 세팅
# ---------------------------

if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# env.sh에 없으면 기본값으로 세팅
: "${CMD_TARGET_DIR:="$DEFAULT_DESKTOP_DIR"}"
: "${CMD_TOP_N:=10}"
: "${CMD_LOG_DIR:="$DEFAULT_LOG_DIR"}"
: "${CMD_DRY_RUN:=1}"

: "${CMD_DOWNLOAD_DIR:="$DEFAULT_DESKTOP_DIR"}"
: "${CMD_SCREENSHOT_DAYS:=30}"

# ----- 스크린샷 경로 자동 감지 (env.sh에 값 없을 때만) -----
if [[ -z "${CMD_SCREENSHOT_DIR:-}" ]]; then
    case "$OS_KIND" in
        macOS)
            # macOS: 시스템에 설정된 스크린샷 위치 읽기
            if command -v defaults &>/dev/null; then
                ss_dir="$(defaults read com.apple.screencapture location 2>/dev/null || true)"
                if [[ -n "$ss_dir" && -d "$ss_dir" ]]; then
                    CMD_SCREENSHOT_DIR="$ss_dir"
                else
                    CMD_SCREENSHOT_DIR="$DEFAULT_DESKTOP_DIR"
                fi
            else
                CMD_SCREENSHOT_DIR="$DEFAULT_DESKTOP_DIR"
            fi
            ;;
        GitBash)
            # Windows + Git Bash 환경 (추측입니다: 일반적인 기본값 기준)
            if [[ -n "${USERPROFILE:-}" ]]; then
                win_ss="${USERPROFILE}\\Pictures\\Screenshots"
                if command -v cygpath &>/dev/null; then
                    ss_dir="$(cygpath "$win_ss" 2>/dev/null || echo "")"
                else
                    ss_dir=""
                fi

                if [[ -n "$ss_dir" && -d "$ss_dir" ]]; then
                    CMD_SCREENSHOT_DIR="$ss_dir"
                else
                    # 기본 Screenshots 폴더가 없으면 Desktop으로 fallback
                    if command -v cygpath &>/dev/null; then
                        win_desktop="${USERPROFILE}\\Desktop"
                        desk_dir="$(cygpath "$win_desktop" 2>/dev/null || echo "")"
                        CMD_SCREENSHOT_DIR="${desk_dir:-$DEFAULT_DESKTOP_DIR}"
                    else
                        CMD_SCREENSHOT_DIR="$DEFAULT_DESKTOP_DIR"
                    fi
                fi
            else
                CMD_SCREENSHOT_DIR="$DEFAULT_DESKTOP_DIR"
            fi
            ;;
        *)
            # Linux/WSL 등은 OS별 Desktop 자동 추론값 사용
            CMD_SCREENSHOT_DIR="$DEFAULT_DESKTOP_DIR"
            ;;
    esac
fi

mkdir -p "$CMD_LOG_DIR"
LOG_FILE="$CMD_LOG_DIR/clean-disk-$(date +'%Y%m%d_%H%M%S').log"


# ---------------------------
# 1. 공통 유틸
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
    echo "  OS 종류       : $OS_KIND"
    echo "  프로젝트 루트 : $PROJECT_ROOT"
    echo "  분석 대상     : $CMD_TARGET_DIR"
    echo "  로그 파일     : $LOG_FILE"
    echo "--------------------------------------"
    echo "  TOP N         : $CMD_TOP_N"
    echo "  다운로드 경로 : $CMD_DOWNLOAD_DIR"
    echo "  스크린샷 경로 : $CMD_SCREENSHOT_DIR"
    echo "  스샷 기준일수 : $CMD_SCREENSHOT_DAYS일 이전"
    echo "  dry-run 모드  : $CMD_DRY_RUN"
    echo "======================================"
    echo
}

# ---------------------------
# 2. 설정 마법사 (setup)
# ---------------------------

run_setup_wizard() {
    echo "======================================"
    echo "      Clean Disk 설정 마법사"
    echo "======================================"
    echo "감지된 OS 종류 : ${OS_KIND:-unknown}"
    echo "추천 데스크탑 : ${DEFAULT_DESKTOP_DIR:-$HOME}"
    echo

    echo "[1] 기본 정리 대상 디렉토리"
    read -rp "  위 데스크탑 경로를 기본 대상으로 사용할까요? [Y/n]: " ans
    ans=${ans:-Y}
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        TARGET_DIR="$DEFAULT_DESKTOP_DIR"
    else
        read -rp "  직접 경로를 입력하세요 (예: /home/user/Desktop): " custom
        TARGET_DIR="${custom:-$DEFAULT_DESKTOP_DIR}"
    fi
    echo "  → 선택된 기본 대상: $TARGET_DIR"
    echo

    echo "[2] 중복 다운로드 / 스크린샷 경로"
    read -rp "  중복 다운로드 탐색 디렉토리 (기본: $TARGET_DIR): " dd
    DOWNLOAD_DIR="${dd:-$TARGET_DIR}"

    read -rp "  스크린샷 정리 디렉토리 (기본: $TARGET_DIR): " ss
    SCREENSHOT_DIR="${ss:-$TARGET_DIR}"

    read -rp "  스크린샷을 몇 일 이전부터 정리 후보로 볼까요? (기본 30): " days
    SCREENSHOT_DAYS="${days:-30}"
    echo

    echo "[3] 분석 옵션"
    read -rp "  topdirs/topfiles 에서 상위 몇 개를 볼까요? (기본 10): " n
    TOP_N="${n:-10}"

    read -rp "  기본 모드를 dry-run(실제 삭제 X)로 둘까요? [Y/n]: " dr
    dr=${dr:-Y}
    if [[ "$dr" =~ ^[Yy]$ ]]; then
        DRY_RUN=1
    else
        DRY_RUN=0
    fi
    echo

    echo "[4] config/env.sh 파일에 설정을 저장합니다."
    cat > "$CONFIG_FILE" <<EOF
# 자동 생성된 Clean Disk 설정 파일
# 생성 시각: $(date +'%Y-%m-%d %H:%M:%S')

CMD_TARGET_DIR="$TARGET_DIR"
CMD_TOP_N=$TOP_N
CMD_LOG_DIR="logs"
CMD_DRY_RUN=$DRY_RUN

CMD_DOWNLOAD_DIR="$DOWNLOAD_DIR"
CMD_SCREENSHOT_DIR="$SCREENSHOT_DIR"
CMD_SCREENSHOT_DAYS=$SCREENSHOT_DAYS
EOF

    echo
    echo "설정이 저장되었습니다: $CONFIG_FILE"
    echo "이후에는 ./scripts/clean-disk.sh 를 바로 실행하면 됩니다."
    echo
    pause
}

# ---------------------------
# 3. 분석 기능 (df / topdirs / topfiles / old / python)
# ---------------------------

analyze_disk_overview() {
    log "[df] 대상 디렉토리 기준 디스크 사용량"

    echo ">>> 분석 대상 디렉토리: $CMD_TARGET_DIR"
    echo

    # 1) CMD_TARGET_DIR가 올라가 있는 파일시스템의 사용량만 표시
    df -h "$CMD_TARGET_DIR" | tee -a "$LOG_FILE"
    echo

    # 2) 그 디렉토리 자체의 용량도 같이 보여주기
    echo ">>> 분석 대상 디렉토리 자체 용량"
    du -sh "$CMD_TARGET_DIR" 2>/dev/null | tee -a "$LOG_FILE"
    echo
}

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

cmd_topfiles() {
    local n="${1:-$CMD_TOP_N}"

    log "[topfiles] $CMD_TARGET_DIR 하위 큰 파일 상위 ${n}개"
    echo ">>> [topfiles] $CMD_TARGET_DIR 하위 큰 파일 상위 ${n}개"
    echo

    if ! command -v python3 &>/dev/null; then
        echo "python3를 찾을 수 없어 topfiles 기능을 사용할 수 없습니다." | tee -a "$LOG_FILE"
        echo
        return
    fi

    python3 - "$CMD_TARGET_DIR" "$n" << 'PY'
import os, sys

def human(size):
    if size == 0:
        return "0B"
    units = ["B","KB","MB","GB","TB"]
    i = 0
    s = float(size)
    while s >= 1024 and i < len(units)-1:
        s /= 1024.0
        i += 1
    return f"{s:.1f}{units[i]}"

if len(sys.argv) < 3:
    sys.exit(1)

root = sys.argv[1]
try:
    top_n = int(sys.argv[2])
except ValueError:
    top_n = 10

files = []
for dirpath, dirnames, filenames in os.walk(root):
    for name in filenames:
        path = os.path.join(dirpath, name)
        try:
            st = os.stat(path)
        except (FileNotFoundError, PermissionError):
            continue
        files.append((st.st_size, path))

files.sort(key=lambda x: x[0], reverse=True)

for i, (size, path) in enumerate(files[:top_n], start=1):
    print(f"{i:2d}. {human(size):>10s}  {path}")
PY

    echo
}

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
# 4. 정리 후보 기능 (dup / shots)
# ---------------------------

find_duplicate_downloads() {
    local dir="$CMD_DOWNLOAD_DIR"

    log "[dup] 중복 다운로드 의심 파일 검색: $dir"

    if [[ ! -d "$dir" ]]; then
        echo "중복 다운로드 디렉토리($dir)를 찾을 수 없습니다." | tee -a "$LOG_FILE"
        echo
        pause
        return
    fi

    echo ">>> $dir 안에서 이름에 (2), (3) 같은 숫자가 붙은 파일을 찾습니다."
    echo "    예) report.pdf, report(2).pdf, report(3).pdf ..."
    echo

    local count=0

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

clean_screenshots() {
    local dir="$CMD_SCREENSHOT_DIR"
    local days="$CMD_SCREENSHOT_DAYS"

    log "[screenshots] ${days}일 이전 스크린샷 정리 후보 검색: $dir"

    if [[ ! -d "$dir" ]]; then
        echo "스크린샷 디렉토리($dir)를 찾을 수 없습니다." | tee -a "$LOG_FILE"
        echo
        pause
        return
    fi

    echo ">>> $dir 안에서 ${days}일 이전의 스크린샷 파일을 찾습니다."
    echo "    (정리 후보만 보여주고, dry-run 모드에서는 삭제하지 않습니다.)"
    echo

    mapfile -t candidates < <(find "$dir" -maxdepth 1 -type f -mtime +"$days" 2>/dev/null | sort)

    local count="${#candidates[@]}"

    if [[ "$count" -eq 0 ]]; then
        echo "${days}일 이전 스크린샷 후보가 없습니다."
        echo
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
        echo
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
# 5. 메뉴 & CLI
# ---------------------------

show_menu() {
    print_header
    echo "[설정/설치]"
    echo " 0) setup     : 설정 마법사 (env.sh 생성/수정)"
    echo
    echo "[분석 기능]"
    echo " 1) df        : 전체 디스크 사용량(df -h)"
    echo " 2) topdirs   : 큰 디렉토리 TOP N"
    echo " 3) topfiles  : 큰 파일 TOP N"
    echo " 4) old       : 오래된 파일 목록(days 기준)"
    echo " 5) python    : Python 보조 도구 통계"
    echo
    echo "[정리/삭제 기능]"
    echo " 6) dup       : 중복 다운로드 의심 파일"
    echo " 7) shots     : 오래된 스크린샷 후보"
    echo " 8) autoclean : 로그/캐시 자동 정리 + 리포트(파트너 모듈)"
    echo
    echo " 9) 종료"
    echo
    read -rp "메뉴를 선택하세요: " choice

    case "$choice" in
        0) run_setup_wizard ;;
        1) analyze_disk_overview;    pause ;;
        2) cmd_topdirs;              pause ;;
        3) cmd_topfiles;             pause ;;
        4) read -rp "며칠 이전 파일을 볼까요? (기본 30): " d; d=${d:-30}; cmd_old "$d"; pause ;;
        5) cmd_python_stats;         pause ;;
        6) find_duplicate_downloads ;;
        7) clean_screenshots ;;
        8)
        if declare -F clean_logs &>/dev/null; then
            # clean_logs 내부에서 에러가 나도 스크립트 전체가 죽지 않도록 서브쉘 + set +e
            ( set +e; clean_logs )
        else
            echo "autoclean 기능을 사용할 수 없습니다."
            echo "→ scripts/delete_module.sh 가 없거나 clean_logs 함수가 정의되어 있지 않습니다."
        fi
        pause
        ;;
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

dispatch_cli() {
    local cmd="$1"
    shift || true

    case "$cmd" in
        setup)
            run_setup_wizard
            ;;
        df)
            analyze_disk_overview
            ;;
        topdirs)
            cmd_topdirs "${1:-$CMD_TOP_N}"
            ;;
        topfiles)
            cmd_topfiles "${1:-$CMD_TOP_N}"
            ;;
        old)
            cmd_old "${1:-30}"
            ;;
        python)
            cmd_python_stats
            ;;
        dup)
            find_duplicate_downloads
            ;;
        shots)
            clean_screenshots
            ;;
        autoclean)
            if declare -F clean_logs &>/dev/null; then
                ( set +e; clean_logs )
            else
                 echo "autoclean 기능을 사용할 수 없습니다."
                 echo "→ scripts/delete_module.sh 가 없거나 clean_logs 함수가 정의되어 있지 않습니다."
            fi
            ;;
        menu|*)
            main_menu_loop
            ;;
    esac
}


main() {
    if [[ $# -gt 0 ]]; then
        dispatch_cli "$@"
    else
        main_menu_loop
    fi
}

main "$@"