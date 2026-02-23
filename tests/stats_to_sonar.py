#!/usr/bin/env python3
"""
Converts the CSV dumped by tests/dump_stats.lua into SonarQube Generic Coverage XML.

SonarQube Generic Coverage XML format:
  https://docs.sonarsource.com/sonarqube-cloud/enriching/test-coverage/generic-test-data/

Usage:
  lua tests/dump_stats.lua luacov.stats.out | python3 tests/stats_to_sonar.py - coverage/sonar-coverage.xml
"""
import sys
import os
import xml.etree.ElementTree as ET


def is_executable(src_line: str) -> bool:
    stripped = src_line.strip()
    return bool(stripped) and not stripped.startswith("--")


def executable_lines(source_path: str) -> set:
    try:
        with open(source_path, encoding="utf-8") as fh:
            return {i + 1 for i, ln in enumerate(fh) if is_executable(ln)}
    except FileNotFoundError:
        return set()


def parse_csv(stream) -> dict:
    """
    Reads the simple CSV produced by dump_stats.lua:
      FILE:<path>
      <linenum>,<hits>
      END
    Returns { "relative/path.lua": { line_no: hit_count, ... }, ... }
    """
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
    """Make path relative to repo_root if it is absolute."""
    abs_path = os.path.abspath(path)
    try:
        return os.path.relpath(abs_path, repo_root)
    except ValueError:
        return path


def should_skip(file_path: str) -> bool:
    lower = file_path.lower().replace("\\", "/")
    return "test" in lower or "luarocks" in lower


def add_file_coverage(root: ET.Element, rel_path: str, hit_lines: dict, repo_root: str) -> None:
    candidates = [rel_path, os.path.join(repo_root, rel_path)]
    exec_lines = set()
    for candidate in candidates:
        exec_lines = executable_lines(candidate)
        if exec_lines:
            break
    if not exec_lines:
        exec_lines = set(hit_lines.keys())
    if not exec_lines:
        return

    sonar_path = rel_path.replace("\\", "/")
    file_elem = ET.SubElement(root, "file", path=sonar_path)
    for line_no in sorted(exec_lines):
        covered = "true" if hit_lines.get(line_no, 0) > 0 else "false"
        ET.SubElement(file_elem, "lineToCover",
                      lineNumber=str(line_no), covered=covered)


def write_xml(root: ET.Element, out_path: str) -> None:
    ET.indent(root)
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    ET.ElementTree(root).write(out_path, encoding="unicode", xml_declaration=True)


def print_summary(root: ET.Element, out_path: str) -> None:
    total = sum(1 for f in root for _ in f)
    uncov = sum(1 for f in root for ln in f if ln.get("covered") == "false")
    cov = 100.0 * (total - uncov) / total if total else 0.0
    print(f"Written:  {out_path}")
    print(f"Coverage: {total - uncov}/{total} lines covered ({cov:.1f}%)")


def convert(csv_source, out_path: str) -> None:
    repo_root = os.getcwd()
    stats = parse_csv(csv_source)

    print(f"Files found in stats: {list(stats.keys())}")

    root = ET.Element("coverage", version="1")
    for raw_path, hit_lines in sorted(stats.items()):
        rel_path = normalize_path(raw_path, repo_root)
        print(f"  {'SKIP' if should_skip(rel_path) else 'ADD ':4s} {rel_path}")
        if not should_skip(rel_path):
            add_file_coverage(root, rel_path, hit_lines, repo_root)

    write_xml(root, out_path)
    print_summary(root, out_path)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: lua tests/dump_stats.lua luacov.stats.out | {sys.argv[0]} - <output.xml>")
        sys.exit(1)

    csv_arg = sys.argv[1]
    out_path = sys.argv[2]

    if csv_arg == "-":
        convert(sys.stdin, out_path)
    else:
        with open(csv_arg, encoding="utf-8") as fh:
            convert(fh, out_path)
