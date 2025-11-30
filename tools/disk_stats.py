#!/usr/bin/env python3
"""
disk_stats.py : 디스크 통계/분석 보조 도구

역할:
- 특정 디렉토리 전체를 스캔해서
  1) 전체 파일 개수 / 총 용량
  2) 용량 구간별(자잘한 파일 위주) 파일 수
  3) 확장자별 용량 Top N
  4) 중복 다운로드 의심 파일 개수 (이름에 (2), (3) 붙은 파일)
  5) 스크린샷 추정 파일 개수(Screenshot, 스크린샷 등 이름 패턴)
  6) 가장 큰 파일 Top N

삭제는 하지 않고, **분석/리포트만 출력**.
"""

import os
import re
import sys
from collections import defaultdict
from typing import Dict, List, Tuple


DUP_PATTERN = re.compile(r".+\([0-9]+\)\.[^.]+$")  # 예: report(2).pdf
SCREENSHOT_KEYWORDS = ["screenshot", "screen shot", "스크린샷", "스크린 샷"]


def human_size(size_bytes: int) -> str:
    """바이트를 사람이 보기 좋은 단위로."""
    if size_bytes == 0:
        return "0B"
    units = ["B", "KB", "MB", "GB", "TB"]
    idx = 0
    s = float(size_bytes)
    while s >= 1024 and idx < len(units) - 1:
        s /= 1024.0
        idx += 1
    return f"{s:.1f}{units[idx]}"


def size_bucket(size: int) -> str:
    """
    용량 구간 이름 리턴.
    - 0 ~ 100KB
    - 100KB ~ 1MB
    - 1MB ~ 10MB
    - 10MB ~ 100MB
    - 100MB 이상
    """
    kb = 1024
    mb = 1024 * kb
    gb = 1024 * mb

    if size < 100 * kb:
        return "0~100KB"
    elif size < 1 * mb:
        return "100KB~1MB"
    elif size < 10 * mb:
        return "1MB~10MB"
    elif size < 100 * mb:
        return "10MB~100MB"
    elif size < 1 * gb:
        return "100MB~1GB"
    else:
        return "1GB 이상"


def is_duplicate_name(filename: str) -> bool:
    """다운로드 중복 파일 패턴 여부 (예: something(2).pdf)."""
    return bool(DUP_PATTERN.match(filename))


def is_screenshot_name(filename: str) -> bool:
    """스크린샷일 것 같은 파일명인지 간단히 체크."""
    lower = filename.lower()
    return any(key in lower for key in SCREENSHOT_KEYWORDS)


def walk_and_collect(root: str):
    total_size = 0
    file_count = 0

    # 확장자별 통계
    ext_sizes: Dict[str, int] = defaultdict(int)
    ext_counts: Dict[str, int] = defaultdict(int)

    # 용량 구간별 카운트
    bucket_counts: Dict[str, int] = defaultdict(int)

    # 중복 다운로드 / 스샷 카운트
    duplicate_count = 0
    screenshot_count = 0

    # 대용량 파일 목록
    big_files: List[Tuple[int, str]] = []

    for dirpath, dirnames, filenames in os.walk(root):
        for name in filenames:
            path = os.path.join(dirpath, name)
            try:
                st = os.stat(path)
            except (FileNotFoundError, PermissionError):
                # 권한 없거나 이미 삭제된 파일은 스킵
                continue

            size = st.st_size
            total_size += size
            file_count += 1
            big_files.append((size, path))

            # 확장자 통계
            _, ext = os.path.splitext(name)
            ext = ext.lower() if ext else "<no_ext>"
            ext_sizes[ext] += size
            ext_counts[ext] += 1

            # 용량 구간 통계
            bucket = size_bucket(size)
            bucket_counts[bucket] += 1

            # 중복 다운로드 패턴
            if is_duplicate_name(name):
                duplicate_count += 1

            # 스크린샷 추정
            if is_screenshot_name(name):
                screenshot_count += 1

    return (
        total_size,
        file_count,
        ext_sizes,
        ext_counts,
        bucket_counts,
        duplicate_count,
        screenshot_count,
        big_files,
    )


def main():
    # 인자: [TARGET_DIR] [TOP_N]
    if len(sys.argv) < 2:
        print("사용법: python3 disk_stats.py [TARGET_DIR] [TOP_N]")
        sys.exit(1)

    target = sys.argv[1]
    if len(sys.argv) >= 3:
        try:
            top_n = int(sys.argv[2])
        except ValueError:
            top_n = 10
    else:
        top_n = 10

    if not os.path.isdir(target):
        print(f"디렉토리 아님: {target}")
        sys.exit(1)

    print(f"[Python 분석 도구] 대상 디렉토리: {target}")
    print("파일 정보를 수집하는 중입니다...\n")

    (
        total_size,
        file_count,
        ext_sizes,
        ext_counts,
        bucket_counts,
        duplicate_count,
        screenshot_count,
        big_files,
    ) = walk_and_collect(target)

    # 1) 전체 요약
    print("=== 1. 전체 요약 ===")
    print(f"- 총 파일 개수 : {file_count}")
    print(f"- 총 용량      : {human_size(total_size)}")
    print(f"- 중복 다운로드 의심 파일 수 : {duplicate_count}")
    print(f"- 스크린샷 추정 파일 수       : {screenshot_count}")
    print()

    # 2) 용량 구간별 파일 수
    print("=== 2. 용량 구간별 파일 수 ===")
    # 정렬: 대략 작은 구간부터 보기 좋게
    order = ["0~100KB", "100KB~1MB", "1MB~10MB", "10MB~100MB", "100MB~1GB", "1GB 이상"]
    for b in order:
        c = bucket_counts.get(b, 0)
        print(f"{b:10s} : {c}")
    print()

    # 3) 확장자별 Top N (용량 기준)
    print(f"=== 3. 확장자별 용량 Top {top_n} ===")
    sorted_ext = sorted(ext_sizes.items(), key=lambda x: x[1], reverse=True)
    for ext, size in sorted_ext[:top_n]:
        cnt = ext_counts[ext]
        print(f"{ext:10s}  {human_size(size):>10s}  ({cnt}개)")
    print()

    # 4) 대용량 파일 Top N
    print(f"=== 4. 대용량 파일 Top {top_n} ===")
    big_files.sort(key=lambda x: x[0], reverse=True)
    for i, (size, path) in enumerate(big_files[:top_n], start=1):
        print(f"{i:2d}. {human_size(size):>10s}  {path}")
    print()

    print("※ 이 도구는 '삭제'는 하지 않고, 분석/리포트만 제공합니다.")
    print("   (실제 정리/삭제는 clean-disk.sh의 메뉴에서 수행)")


if __name__ == "__main__":
    main()
