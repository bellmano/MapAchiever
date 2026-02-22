#!/usr/bin/env python3
"""
Converts luacov.stats.out into SonarQube Generic Coverage XML.

luacov.stats.out is a Lua table written by luacov during test execution:
  return {["file.lua"] = {max=N, [line]=hits, ...}, ...}

Executable lines are determined by reading the source file:
  - blank lines and pure-comment lines are non-executable.

SonarQube Generic Coverage XML format:
  https://docs.sonarsource.com/sonarqube-cloud/enriching/test-coverage/generic-test-data/

Usage:
  python3 tests/stats_to_sonar.py luacov.stats.out coverage/sonar-coverage.xml
"""
import re
import sys
import os
import xml.etree.ElementTree as ET


def is_executable(line: str) -> bool:
    """Heuristic: blank lines and comment-only lines are not executable."""
    stripped = line.strip()
    if not stripped:
        return False
    if stripped.startswith("--"):
        return False
    return True


def executable_lines(source_path: str) -> set:
    try:
        with open(source_path, encoding="utf-8") as fh:
            return {i + 1 for i, ln in enumerate(fh) if is_executable(ln)}
    except FileNotFoundError:
        return set()


def parse_stats(stats_path: str) -> dict:
    """
    Parse luacov.stats.out and return:
      { "file/path.lua": { line_no: hit_count, ... }, ... }
    """
    with open(stats_path, encoding="utf-8") as fh:
        content = fh.read()

    result = {}
    # Each top-level entry: ["path"] = { ... }
    for file_match in re.finditer(r'\["([^"]+)"\]\s*=\s*\{([^}]*)\}', content, re.DOTALL):
        path = file_match.group(1)
        # Ensure .lua extension
        if not path.endswith(".lua"):
            path += ".lua"
        body = file_match.group(2)
        lines = {}
        for m in re.finditer(r'\[(\d+)\]\s*=\s*(\d+)', body):
            lines[int(m.group(1))] = int(m.group(2))
        result[path] = lines

    return result


def should_skip(file_path: str, source_filter: str) -> bool:
    if "test" in file_path.lower():
        return True
    if source_filter and source_filter not in file_path:
        return True
    return False


def add_file_coverage(root: ET.Element, file_path: str, hit_lines: dict) -> None:
    exec_lines = executable_lines(file_path) or set(hit_lines.keys())
    if not exec_lines:
        return
    file_elem = ET.SubElement(root, "file", path=file_path)
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
    print(f"Written: {out_path}")
    print(f"Coverage: {total - uncov}/{total} lines covered ({cov:.1f}%)")


def convert(stats_path: str, out_path: str, source_filter: str = "") -> None:
    root = ET.Element("coverage", version="1")
    for file_path, hit_lines in sorted(parse_stats(stats_path).items()):
        if not should_skip(file_path, source_filter):
            add_file_coverage(root, file_path, hit_lines)
    write_xml(root, out_path)
    print_summary(root, out_path)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <luacov.stats.out> <output.xml> [source_filter]")
        sys.exit(1)
    source_filter = sys.argv[3] if len(sys.argv) > 3 else ""
    convert(sys.argv[1], sys.argv[2], source_filter)
