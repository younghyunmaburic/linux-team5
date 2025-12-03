import os
import sys

# 로그 파일들이 있는 디렉토리
LOG_DIR = sys.argv[1] if len(sys.argv) > 1 else "logs"

def show_stats():
    total_files = 0
    total_size_kb = 0
    report_count = 0

    if not os.path.exists(LOG_DIR):
        print(f" '{LOG_DIR}' 디렉토리가 없습니다.")
        return

    print(f" [디스크 정리 통계] 대상 폴더: {LOG_DIR}")
    print("-" * 40)

    # logs 폴더 내의 모든 파일을 읽음
    for filename in os.listdir(LOG_DIR):
        if filename.startswith("report-") and filename.endswith(".txt"):
            report_count += 1
            filepath = os.path.join(LOG_DIR, filename)
            
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()
                # 간단한 파싱: "삭제된 파일 수 : N"과 "확보된 용량 : N KB"를 찾음
                for line in content.splitlines():
                    if "삭제된 파일 수" in line:
                        try:
                            count = int(line.split(":")[-1].replace("개", "").strip())
                            total_files += count
                        except: pass
                    if "확보된 용량" in line:
                        try:
                            size = int(line.split(":")[-1].replace("KB", "").strip())
                            total_size_kb += size
                        except: pass

    print(f" 총 리포트 수 : {report_count} 개")
    print(f" 총 삭제 파일 : {total_files} 개")
    print(f" 총 확보 용량 : {total_size_kb} KB")
    print("-" * 40)

if __name__ == "__main__":
    show_stats()
    