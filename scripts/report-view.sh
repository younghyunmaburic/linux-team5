#!/usr/bin/env bash
# report-view.sh : 통합 분석 및 리포트 (Feature 4)
# 위치: scripts/report-view.sh

set -euo pipefail

# 1. 경로 설정
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLS_DIR="$PROJECT_ROOT/tools"
LOG_DIR="$PROJECT_ROOT/logs"

# 2. Python 명령어 자동 감지 (이게 핵심!)
if command -v python3 &>/dev/null; then
    PYTHON_CMD=python3
elif command -v python &>/dev/null; then
    PYTHON_CMD=python
else
    echo "[오류] Python이 설치되어 있지 않거나 경로(PATH) 설정이 안 되어 있습니다."
    exit 1
fi

# 3. 윈도우 Git Bash 호환성 (한글/특수문자 출력 깨짐 방지)
export PYTHONIOENCODING=utf-8

# ---------------------------
# 메뉴 기능 구현
# ---------------------------

system_overview() {
    clear
    echo "======================================"
    echo "       [1] 시스템 디스크 전체 현황"
    echo "======================================"
    df -h
    echo ""
    echo "엔터를 누르면 메뉴로 돌아갑니다."
    read
}

top_dir_analysis() {
    clear
    echo "======================================"
    echo "       [2] 현재 디렉토리 용량 순위"
    echo "======================================"
    echo "분석 대상: $PROJECT_ROOT"
    # 윈도우 du 호환성을 위해 에러 무시
    du -sh "$PROJECT_ROOT"/* 2>/dev/null | sort -h | tail -n 10
    echo ""
    echo "엔터를 누르면 메뉴로 돌아갑니다."
    read
}

advanced_analysis() {
    clear
    echo "======================================"
    echo "       [3] 정밀 파일 분석 (Python)"
    echo "======================================"
    
    # tools 폴더 안의 disk_stats.py 실행
    if [ -f "$TOOLS_DIR/disk_stats.py" ]; then
        # $PYTHON_CMD 변수 사용
        "$PYTHON_CMD" "$TOOLS_DIR/disk_stats.py" "$PROJECT_ROOT" 10
    else
        echo "[오류] tools/disk_stats.py 파일이 없습니다."
    fi
    echo ""
    echo "엔터를 누르면 메뉴로 돌아갑니다."
    read
}

history_stats() {
    clear
    echo "======================================"
    echo "       [4] Clean Disk 로그 통계"
    echo "======================================"
    
    if [ -f "$TOOLS_DIR/stats.py" ]; then
        if [ -d "$LOG_DIR" ]; then
            "$PYTHON_CMD" "$TOOLS_DIR/stats.py" "$LOG_DIR"
        else
            echo "[알림] 아직 생성된 로그 폴더(logs)가 없습니다."
        fi
    else
        echo "[오류] tools/stats.py 파일을 찾을 수 없습니다."
    fi
    echo ""
    echo "엔터를 누르면 메뉴로 돌아갑니다."
    read
}

# ---------------------------
# 메인 메뉴 Loop
# ---------------------------
show_menu() {
    clear
    echo "======================================"
    echo "      REPORT VIEW (종합 분석 센터)    "
    echo "======================================"
    echo " 1. 시스템 디스크 전체 현황 (df)"
    echo " 2. 프로젝트 폴더 용량 순위 (du)"
    echo " 3. 정밀 파일 분석 (Python)"
    echo " 4. Clean Disk 수행 이력 통계"
    echo " 0. 종료"
    echo "======================================"
    echo -n " 메뉴를 선택하세요: "
    read choice

    case $choice in
        1) system_overview ;;
        2) top_dir_analysis ;;
        3) advanced_analysis ;;
        4) history_stats ;;
        0) exit 0 ;;
        *) echo "잘못된 선택입니다."; sleep 1 ;;
    esac
}

while true; do
    show_menu
done