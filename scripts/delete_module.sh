#!/bin/bash

# ========================================================
# 기능: 고급 정리(Autoclean) 및 리포트 생성 (담당: 최영현)
# 역할: 삭제 후보를 받아 일괄 정리하고, 요약 리포트를 남김
# ========================================================

# 설정 로딩
LOG_DIR="${LOG_DIR:-../logs}"
DATE_KEY=$(date +"%Y%m%d")
REPORT_FILE="$LOG_DIR/report-${DATE_KEY}.txt"

# 자동 정리 함수
run_autoclean() {
    local target_path="$1"
    local pattern="$2"
    
    mkdir -p "$LOG_DIR"
    local count=0
    local saved_size=0
    local deleted_list=()

    echo "--------------------------------------------"
    echo "🧹 [AutoClean] 정리 작업을 시작합니다..."
    echo "--------------------------------------------"

    while IFS= read -r file; do
        # [Fail-safe] Git 추적 파일 보호
        if git ls-files --error-unmatch "$file" > /dev/null 2>&1; then
            echo "  ⚠️ [SKIP] Git 보호 파일: $file"
        else
            size=$(du -k "$file" | cut -f1)
            rm -f "$file"
            if [ $? -eq 0 ]; then
                echo "  🗑️ [삭제됨] $file (${size}KB)"
                deleted_list+=("$file")
                saved_size=$((saved_size + size))
                ((count++))
            fi
        fi
    done < <(find "$target_path" -type f -name "$pattern" -not -path '*/.git/*' 2>/dev/null)

    if [ $count -eq 0 ]; then
        echo "✅ 정리할 파일이 발견되지 않았습니다."
        return
    fi

    write_report "$count" "$saved_size" "${deleted_list[@]}"
}

# 리포트 작성 함수
write_report() {
    local count="$1"
    local size="$2"
    shift 2
    local files=("$@")
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    if [ ! -f "$REPORT_FILE" ]; then
        echo "============================================" > "$REPORT_FILE"
        echo " 📄 Clean-Disk 일일 정리 리포트 ($DATE_KEY)" >> "$REPORT_FILE"
        echo "============================================" >> "$REPORT_FILE"
    fi

    {
        echo ""
        echo "[실행 시간: $timestamp]"
        echo "--------------------------------------------"
        echo "📊 정리 요약"
        echo "   - 삭제된 파일 수 : $count 개"
        echo "   - 확보된 용량    : ${size} KB"
        echo "--------------------------------------------"
        echo "📋 상세 삭제 목록:"
        printf '%s\n' "${files[@]}"
        echo "============================================"
    } >> "$REPORT_FILE"

    echo "✨ 리포트가 업데이트되었습니다: $REPORT_FILE"
}