from __future__ import annotations

from typing import Any


def render_report(report: dict[str, Any]) -> str:
    lines: list[str] = [
        "# Coach Report",
        "",
        f"- Report ID: `{report['report_id']}`",
        f"- Fingerprint: `{report['snapshot_fingerprint']}`",
        f"- Rule pack: `{report['rule_pack_version']}`",
        f"- Summary: `{report['summary']['message_key']}` ({report['summary']['severity']})",
        f"- Confidence: `{report['confidence']}`",
        "",
    ]

    if report.get("shop_advice"):
        lines.extend(["## Shop Advice", ""])
        for action in report["shop_advice"]:
            codes = ", ".join(action.get("reason_codes", []))
            lines.append(
                f"- {action['rank']}. `{action['item_id']}` -> `{action['action']}` "
                f"price `{action['price']}` reasons `{codes}`"
            )
        lines.append("")

    if report.get("stat_diagnosis"):
        lines.extend(["## Stat Diagnosis", ""])
        for gap in report["stat_diagnosis"]:
            lines.append(
                f"- `{gap['stat_id']}` current `{gap['current']}` target "
                f"`{gap['target']}` by wave `{gap['deadline_wave']}`"
            )
        lines.append("")

    plans = report.get("plans", {})
    if plans:
        lines.extend(["## Plans", ""])
        for key in ["wave_plus_3", "wave_plus_5"]:
            plan = plans.get(key, {})
            lines.append(f"### {key}")
            lines.append("")
            lines.append(f"- Deadline wave: `{plan.get('deadline_wave')}`")
            lines.append(f"- Targets: `{plan.get('targets', {})}`")
            lines.append(f"- Priorities: `{plan.get('priorities', [])}`")
            lines.append(f"- Avoid: `{plan.get('avoid', [])}`")
            lines.append("")

    run_review = report.get("run_review")
    if run_review:
        lines.extend(["## Run Review", ""])
        coverage = run_review.get("coverage", {})
        lines.append(f"- Coverage: `{coverage}`")
        lines.append("")
        for finding in run_review.get("findings", []):
            lines.append(
                f"- `{finding['id']}` ({finding['severity']}, "
                f"{finding['direct_or_root_cause']}): `{finding['evidence']}`"
            )
        lines.append("")

    if report.get("warnings"):
        lines.extend(["## Warnings", ""])
        for warning in report["warnings"]:
            lines.append(f"- `{warning}`")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"
