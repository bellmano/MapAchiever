#!/usr/bin/env python3
"""
Converts an lcov coverage report (from luacov-reporter-lcov) into
SonarQube's Generic Coverage XML format.

Usage: python3 tests/lcov_to_sonar.py <lcov_file> <output_xml>
Docs : https://docs.sonarsource.com/sonarqube-cloud/enriching/test-coverage/generic-test-data/
"""
import sys
import xml.etree.ElementTree as ET


def convert(lcov_path: str, out_path: str) -> None:
    root = ET.Element("coverage", version="1")
    file_elem = None

    with open(lcov_path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if line.startswith("SF:"):
                path = line[3:]
                # Ensure the .lua extension is present so SonarQube resolves the file
                if not path.endswith(".lua"):
                    path = path + ".lua"
                file_elem = ET.SubElement(root, "file", path=path)
            elif line.startswith("DA:") and file_elem is not None:
                parts = line[3:].split(",")
                line_no  = parts[0]
                hits     = int(parts[1])
                covered  = "true" if hits > 0 else "false"
                ET.SubElement(file_elem, "lineToCover",
                              lineNumber=line_no, covered=covered)

    ET.indent(root)
    tree = ET.ElementTree(root)
    tree.write(out_path, encoding="unicode", xml_declaration=True)
    print(f"Written: {out_path}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <lcov_file> <output_xml>")
        sys.exit(1)
    convert(sys.argv[1], sys.argv[2])
