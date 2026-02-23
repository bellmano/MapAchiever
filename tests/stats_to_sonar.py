#!/usr/bin/env python3
"""
Converts the CSV dumped by tests/dump_stats.lua into an lcov coverage report
suitable for upload to Codecov.

lcov format (per file):
  SF:<filepath>
  DA:<linenum>,<hits>
  end_of_record

Usage:
  lua tests/dump_stats.lua luacov.stats.out | python3 tests/stats_to_sonar.py - coverage/lcov.info
"""
import sys
import os


def parse_csv(stream) -> dict:
    result = {}
    current_path = None
    current_lines = {}
    for raw in stream:
        line = raw.rstrip("\n")
        if line.startswith("FILE:"):
            current_path = line[5:]
            if not current_path.endswith(".lua"):
                current_path += ".lua"
            current_lines = {}
        elif line == "END" and current_path:
            result[current_path] = current_lines
            current_path = None
            current_lines = {}
        elif current_path and "," in line:
            parts = line.split(",", 1)
            if parts[0].isdigit():
                current_lines[int(parts[0])] = int(parts[1])
    return result


def normalize_path(path: str, repo_root: str) -> str:
    try:
        return os.path.relpath(os.path.abspath(path), repo_root)
    except ValueError:
        return path


def should_skip(file_path: str) -> bool:
    lower = file_path.lower().replace("\\", "/")
    return "test" in lower or "luarocks" in lower


def write_file_block(out, rel_path: str, hit_lines: dict) -> tuple:
    exec_lines = set(hit_lines.keys())
    if not exec_lines:
        return 0, 0
    total = covered = 0
    out.write(f"SF:{rel_path.replace(chr(92), '/')}\n")
    for line_no in sorted(exec_lines):
        hits = hit_lines.get(line_no, 0)
        out.write(f"DA:{line_no},{hits}\n")
        total += 1
        if hits > 0:
            covered += 1
    out.write("end_of_record\n")
    return total, covered


def write_lcov(stats: dict, out_path: str, repo_root: str) -> None:
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    total = covered = 0
    with open(out_path, "w", encoding="utf-8") as out:
        for raw_path, hit_lines in sorted(stats.items()):
            rel_path = normalize_path(raw_path, repo_root)
            print(f"  {'SKIP' if should_skip(rel_path) else 'ADD ':4s} {rel_path}")
            if should_skip(rel_path):
                continue
            t, c = write_file_block(out, rel_path, hit_lines)
            total += t
            covered += c
    cov = 100.0 * covered / total if total else 0.0
    print(f"Written:  {out_path}")
    print(f"Coverage: {covered}/{total} lines covered ({cov:.1f}%)")


def convert(csv_source, out_path: str) -> None:
    repo_root = os.getcwd()
    stats = parse_csv(csv_source)
    print(f"Files found in stats: {len(stats)}")
    write_lcov(stats, out_path, repo_root)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: lua tests/dump_stats.lua luacov.stats.out | {sys.argv[0]} - <output.lcov>")
        sys.exit(1)
    csv_arg, out_path = sys.argv[1], sys.argv[2]
    if csv_arg == "-":
        convert(sys.stdin, out_path)
    else:
        with open(csv_arg, encoding="utf-8") as fh:
            convert(fh, out_path)

