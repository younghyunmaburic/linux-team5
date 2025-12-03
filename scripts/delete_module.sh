#!/bin/bash

# ========================================================
# 기능: 로그/캐시 삭제 및 리포트 (담당: 최영현)
# 특징: Git 추적 파일 보호 (Fail-safe), 리포트 자동 생성
# ========================================================

# 리포트 저장 경로 (현재 스크립트 위치의 상위 폴더(../)의 logs 폴더)
LOG_DIR="../logs"
# 리포트 파일명에 분 단위까지 포함하여 중복 방지
TIMESTAMP=$(date +"%Y-%m-%d_%H%M")
REPORT_FILE="$LOG_DIR/cleanup_report_$TIMESTAMP.txt"

clean_logs() {
    echo "--------------------------------------------"
    echo "🧹 [로그 및 캐시 파일 정리 모드]"
    echo "--------------------------------------------"

    # 삭제 대상 패턴 (기획서대로 설정)
    TARGET_PATTERNS=("*.log" "*.tmp" "*cache*")
    
    DELETE_LIST=()
    TOTAL_SIZE=0
    COUNT=0

    echo " 불필요한 파일을 검색 중입니다..."

    # 검색 및 Git 추적 여부 확인
    # 상위 디렉토리(..) 전체를 대상으로 검색하되, .git 폴더는 제외
    for pattern in "${TARGET_PATTERNS[@]}"; do
        while IFS= read -r file; do
            # [Fail-safe] git ls-files로 버전 관리 중인 파일인지 확인
            # 에러(1)가 리턴되면 => Git 관리 대상 아님 => 삭제 가능
            if git ls-files --error-unmatch "$file" > /dev/null 2>&1; then
                echo "   [SKIP] Git 관리 파일 보호: $file"
            else
                DELETE_LIST+=("$file")
                # 용량 계산 (KB 단위)
                FILE_SIZE=$(du -k "$file" | cut -f1)
                TOTAL_SIZE=$((TOTAL_SIZE + FILE_SIZE))
                ((COUNT++))
            fi
        done < <(find .. -type f -name "$pattern" -not -path '*/.git/*' 2>/dev/null)
    done

    # 검색 결과가 없으면 종료
    if [ ${#DELETE_LIST[@]} -eq 0 ]; then
        echo " 정리할 파일이 없습니다."
        return
    fi

    echo "--------------------------------------------"
    echo " 검색 결과 요약"
    echo "   - 대상 파일 수 : $COUNT 개"
    echo "   - 확보 예상 용량: ${TOTAL_SIZE} KB"
    echo "--------------------------------------------"

    # 사용자 승인 절차
    read -p " 위 파일들을 삭제하고 리포트를 생성하시겠습니까? (y/n): " confirm

    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo " 삭제를 시작합니다..."
        
        # 리포트 파일 헤더 작성
        echo "[Cleanup Report] Date: $TIMESTAMP" > "$REPORT_FILE"
        echo "Total Files: $COUNT, Total Size: ${TOTAL_SIZE} KB" >> "$REPORT_FILE"
        echo "----------------------------------------" >> "$REPORT_FILE"

        deleted_actual=0
        for target in "${DELETE_LIST[@]}"; do
            rm -f "$target"
            echo "   [삭제됨] $target"
            echo "Deleted: $target" >> "$REPORT_FILE"
            ((deleted_actual++))
        done
        
        echo "--------------------------------------------"
        echo " 완료! $deleted_actual 개의 파일이 삭제되었습니다."
        echo " 리포트가 생성되었습니다: $REPORT_FILE"
    else
        echo " 작업이 취소되었습니다."
    fi
}

# (테스트용) 직접 실행 시에만 함수 호출
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    clean_logs
fi
