#!/usr/bin/env python3
"""
disk_stats.py : Clean Disk 보조 분석 도구
사용법:
    python3 disk_stats.py [TARGET_DIR] [TOP_N]

- TARGET_DIR : 분석할 루트 디렉토리 (생략 시 현재 작업 디렉토리)
- TOP_N      : 상위 N개 (생략 시 10)

역할:
  1) 전체 파일 개수 / 총 용량
  2) 큰 파일 TOP N
  3) 확장자별 통계 (개수 / 용량 기준 TOP N)
  4) 작은 파일(예: 1MB 미만) 비율
"""

import os
import sys
from collections import defaultdict
from typing import List, Tuple, Dict


def human(size: int) -> str:
    """바이트를 사람이 읽기 좋은 단위로 변환."""
    if size <= 0:
        return "0B"
    units = ["B", "KB", "MB", "GB", "TB"]
    s = float(size)
    i = 0
    while s >= 1024 and i < len(units) - 1:
        s /= 1024.0
        i += 1
    return f"{s:.1f}{units[i]}"


def walk_files(root: str) -> List[Tuple[int, str]]:
    """root 아래의 모든 파일 (size, path) 리스트를 반환."""
    results: List[Tuple[int, str]] = []
    for dirpath, dirnames, filenames in os.walk(root):
        for name in filenames:
            path = os.path.join(dirpath, name)
            try:
                st = os.stat(path)
            except (FileNotFoundError, PermissionError, OSError):
                # 접근 불가/사라진 파일은 그냥 건너뜀
                continue
            results.append((st.st_size, path))
    return results


def ext_of(path: str) -> str:
    """확장자를 소문자로 반환 (없으면 '<noext>')"""
    base = os.path.basename(path)
    name, ext = os.path.splitext(base)
    if not ext:
        return "<noext>"
    return ext.lower()


def analyze(root: str, top_n: int = 10) -> None:
    print(f"[disk_stats] 대상 디렉토리: {root}")
    print(f"[disk_stats] 상위 N       : {top_n}")
    print()

    files = walk_files(root)
    total_files = len(files)
    total_size = sum(size for size, _ in files)

    print("① 전체 요약")
    print(f"  - 파일 개수 : {total_files}")
    print(f"  - 총 용량   : {human(total_size)}")
    print()

    if total_files == 0:
        print("  분석할 파일이 없습니다.")
        return

    # ② 큰 파일 TOP N
    files_sorted = sorted(files, key=lambda x: x[0], reverse=True)
    print("② 큰 파일 TOP N")
    for i, (size, path) in enumerate(files_sorted[:top_n], start=1):
        print(f"  {i:2d}. {human(size):>8s}  {path}")
    print()

    # ③ 확장자별 통계
    ext_stats: Dict[str, Dict[str, int]] = defaultdict(lambda: {"count": 0, "size": 0})
    for size, path in files:
        ext = ext_of(path)
        ext_stats[ext]["count"] += 1
        ext_stats[ext]["size"] += size

    # 용량 기준 TOP N
    ext_by_size = sorted(
        ext_stats.items(),
        key=lambda kv: kv[1]["size"],
        reverse=True,
    )

    print("③ 확장자별 통계 (용량 기준 TOP N)")
    print("    확장자   파일수     총용량")
    for ext, info in ext_by_size[:top_n]:
        print(f"  {ext:8s}  {info['count']:6d}  {human(info['size']):>8s}")
    print()

    # ④ 작은 파일(1MB 미만) 비율
    SMALL_THRESHOLD = 1 * 1024 * 1024  # 1MB
    small_files = [s for s, _ in files if s < SMALL_THRESHOLD]
    cnt_small = len(small_files)
    size_small = sum(small_files)

    ratio_count = cnt_small / total_files * 100.0
    ratio_size = (size_small / total_size * 100.0) if total_size > 0 else 0.0

    print("④ 작은 파일(1MB 미만) 통계")
    print(f"  - 작은 파일 개수 : {cnt_small} ({ratio_count:.1f}%)")
    print(f"  - 작은 파일 용량 : {human(size_small)} ({ratio_size:.1f}% of total)")
    print()

    print("분석이 완료되었습니다.")


def main() -> None:
    args = sys.argv[1:]
    if len(args) >= 1:
        root = args[0]
    else:
        root = os.getcwd()

    if len(args) >= 2:
        try:
            top_n = int(args[1])
        except ValueError:
            top_n = 10
    else:
        top_n = 10

    if not os.path.isdir(root):
        print(f"[에러] 디렉토리가 아닙니다: {root}")
        sys.exit(1)

    analyze(root, top_n)


if __name__ == "__main__":
    main()