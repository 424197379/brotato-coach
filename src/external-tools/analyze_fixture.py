from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CORE_PATH = ROOT / "src" / "coach-core"
sys.path.insert(0, str(CORE_PATH))

from coach_core import OfflineRuleEngine, load_fixture  # noqa: E402
from coach_core.deterministic import canonical_json  # noqa: E402
from coach_core.markdown import render_report  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Analyze a Brotato coach fixture.")
    parser.add_argument("fixture", help="Fixture directory to analyze.")
    parser.add_argument("--json-out", help="Path for structured JSON report.")
    parser.add_argument("--markdown-out", help="Path for Markdown report.")
    return parser.parse_args()


def default_output_paths(fixture: Path) -> tuple[Path, Path]:
    report_dir = Path(__file__).resolve().parent / "reports" / fixture.name
    return report_dir / "coach-report.json", report_dir / "coach-report.md"


def main() -> int:
    args = parse_args()
    fixture = Path(args.fixture)
    json_out, markdown_out = default_output_paths(fixture)
    if args.json_out:
        json_out = Path(args.json_out)
    if args.markdown_out:
        markdown_out = Path(args.markdown_out)

    loaded = load_fixture(fixture)
    report = OfflineRuleEngine().analyze(loaded)
    json_text = canonical_json(report) + "\n"
    markdown_text = render_report(report)

    json_out.parent.mkdir(parents=True, exist_ok=True)
    markdown_out.parent.mkdir(parents=True, exist_ok=True)
    json_out.write_text(json_text, encoding="utf-8", newline="\n")
    markdown_out.write_text(markdown_text, encoding="utf-8", newline="\n")

    print(json_text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
