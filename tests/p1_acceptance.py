from __future__ import annotations

import hashlib
import importlib
import json
import re
import subprocess
import sys
import zipfile
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CORE_PATH = ROOT / "src" / "coach-core"
REPORT_DIR = ROOT / "private" / "dev-docs" / "test-reports"
GENERATED_DIR = REPORT_DIR / "generated"
PYTHON = sys.executable

FIXTURES = {
    "case001": ROOT / "tests" / "fixtures" / "case-001-apprentice-endless-wave-30",
    "case002": ROOT / "tests" / "fixtures" / "case-002-double-illusionist-wave-3",
}

EXPECTED_ZIP_ENTRIES = {
    "mods-unpacked/BrotatoCoach-BrotatoCoach/manifest.json",
    "mods-unpacked/BrotatoCoach-BrotatoCoach/mod_main.gd",
    "mods-unpacked/BrotatoCoach-BrotatoCoach/core/coach_coordinator.gd",
    "mods-unpacked/BrotatoCoach-BrotatoCoach/core/coach_recorder.gd",
    "mods-unpacked/BrotatoCoach-BrotatoCoach/core/offline_rule_engine.gd",
    "mods-unpacked/BrotatoCoach-BrotatoCoach/core/rule_pack_loader.gd",
    "mods-unpacked/BrotatoCoach-BrotatoCoach/extensions/ui/menus/shop/base_shop.gd",
    "mods-unpacked/BrotatoCoach-BrotatoCoach/extensions/ui/menus/ingame/ingame_main_menu.gd",
    "mods-unpacked/BrotatoCoach-BrotatoCoach/extensions/ui/menus/run/end_run.gd",
    "mods-unpacked/BrotatoCoach-BrotatoCoach/rules/rule-pack-0.1.0.json",
    "mods-unpacked/BrotatoCoach-BrotatoCoach/ui/coach_report_panel.gd",
}

MOD_ID = "BrotatoCoach-BrotatoCoach"
MOD_ROOT = ROOT / "src" / "brotato-mod" / MOD_ID


@dataclass
class CheckResult:
    name: str
    status: str
    detail: str = ""


class Acceptance:
    def __init__(self) -> None:
        sys.path.insert(0, str(CORE_PATH))
        self.results: list[CheckResult] = []
        self.reports: dict[str, dict[str, Any]] = {}
        self.fixture_hashes_before = self._fixture_hashes()

    def pass_(self, name: str, detail: str = "") -> None:
        self.results.append(CheckResult(name, "PASS", detail))

    def fail(self, name: str, detail: str) -> None:
        self.results.append(CheckResult(name, "FAIL", detail))

    def gap(self, name: str, detail: str) -> None:
        self.results.append(CheckResult(name, "GAP", detail))

    def run(self) -> int:
        GENERATED_DIR.mkdir(parents=True, exist_ok=True)
        self.check_json_parse()
        self.check_native_nan_loader()
        self.generate_reports_with_cli()
        self.check_report_shape()
        self.check_case002_assertions()
        self.check_case001_assertions()
        self.check_determinism()
        self.check_budget()
        self.check_missing_wave_coverage()
        self.check_jsonl_loader()
        self.check_mod_static()
        self.check_runtime_reader_static()
        self.check_modloader_zip_manifest()
        self.check_chinese_panel_static()
        self.check_minimal_recorder_static()
        self.check_no_legacy_mod_id_residue()
        self.check_fixture_hashes_unchanged()
        self.write_results()
        return 1 if any(result.status in {"FAIL", "GAP"} for result in self.results) else 0

    def check_json_parse(self) -> None:
        paths = [
            ROOT / "data" / "schemas" / "coach-snapshot.schema.json",
            ROOT / "data" / "schemas" / "coach-event.schema.json",
            ROOT / "data" / "schemas" / "coach-report.schema.json",
            ROOT / "data" / "rules" / "rule-pack-0.1.0.json",
            FIXTURES["case001"] / "assertions.json",
            FIXTURES["case001"] / "run-timeline.json",
            FIXTURES["case002"] / "assertions.json",
            FIXTURES["case002"] / "coach-snapshot.json",
            FIXTURES["case002"] / "source-runtracker.json",
        ]
        try:
            for path in paths:
                self._json(path)
            self.pass_("standard_json_schema_rule_fixture_parse", f"parsed {len(paths)} JSON files")
        except Exception as exc:
            self.fail("standard_json_schema_rule_fixture_parse", str(exc))

    def check_native_nan_loader(self) -> None:
        try:
            text = (FIXTURES["case002"] / "source-brotato-state.json").read_text(encoding="utf-8")
            if re.search(r"(?<![A-Za-z0-9_\"'])nan(?![A-Za-z0-9_\"'])", text) is None:
                self.fail("case002_native_brotato_contains_lowercase_nan", "source file has no lowercase nan token")
                return
            from coach_core import load_fixture

            loaded = load_fixture(FIXTURES["case002"])
            if "native_brotato" not in loaded:
                self.fail("case002_native_brotato_nan_adapter", "native_brotato key not loaded")
                return
            warnings = loaded.get("warnings", [])
            if "native_brotato_json_loaded_with_nan_compat" not in warnings:
                self.fail("case002_native_brotato_nan_adapter", f"missing nan compat warning: {warnings}")
                return
            self.pass_("case002_native_brotato_nan_adapter", "lowercase nan parsed through load_fixture")
        except Exception as exc:
            self.fail("case002_native_brotato_nan_adapter", str(exc))

    def generate_reports_with_cli(self) -> None:
        analyzer = ROOT / "src" / "external-tools" / "analyze_fixture.py"
        for key, fixture in FIXTURES.items():
            json_out = GENERATED_DIR / key / "coach-report.json"
            md_out = GENERATED_DIR / key / "coach-report.md"
            json_out.parent.mkdir(parents=True, exist_ok=True)
            command = [
                PYTHON,
                str(analyzer),
                str(fixture),
                "--json-out",
                str(json_out),
                "--markdown-out",
                str(md_out),
            ]
            proc = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
            if proc.returncode != 0:
                self.fail(f"{key}_analyze_fixture_cli", proc.stderr.strip() or proc.stdout.strip())
                continue
            try:
                self.reports[key] = self._json(json_out)
                self.pass_(f"{key}_analyze_fixture_cli", str(json_out.relative_to(ROOT)))
            except Exception as exc:
                self.fail(f"{key}_analyze_fixture_cli_output_parse", str(exc))

    def check_report_shape(self) -> None:
        required = {
            "schema_version",
            "report_id",
            "snapshot_fingerprint",
            "rule_pack_version",
            "summary",
            "shop_advice",
            "stat_diagnosis",
            "plans",
            "run_review",
            "warnings",
            "confidence",
        }
        for key, report in self.reports.items():
            missing = sorted(required - set(report))
            if missing:
                self.fail(f"{key}_coach_report_required_fields", f"missing {missing}")
                continue
            if not re.match(r"^sha256:[0-9a-f]{64}$", str(report["snapshot_fingerprint"])):
                self.fail(f"{key}_coach_report_fingerprint", str(report["snapshot_fingerprint"]))
                continue
            if set(report.get("plans", {})) != {"wave_plus_3", "wave_plus_5"}:
                self.fail(f"{key}_coach_report_plans", str(report.get("plans")))
                continue
            self.pass_(f"{key}_coach_report_required_shape")

    def check_case002_assertions(self) -> None:
        report = self.reports.get("case002")
        if report is None:
            return
        snapshot = self._json(FIXTURES["case002"] / "coach-snapshot.json")
        actions = {action["item_id"]: action for action in report.get("shop_advice", [])}
        expected_actions = {
            "weapon_new_katana_2": ("buy_now", 1),
            "item_scar": ("buy_now", 2),
            "item_head_injury": ("lock", None),
            "weapon_sword_paladin_1": ("lock", None),
        }
        mismatches = []
        for item_id, (action, rank) in expected_actions.items():
            actual = actions.get(item_id)
            if actual is None:
                mismatches.append(f"{item_id}: missing")
                continue
            if actual.get("action") != action:
                mismatches.append(f"{item_id}: action {actual.get('action')} != {action}")
            if rank is not None and actual.get("rank") != rank:
                mismatches.append(f"{item_id}: rank {actual.get('rank')} != {rank}")
        if mismatches:
            self.fail("case002_shop_actions", "; ".join(mismatches))
        else:
            self.pass_("case002_shop_actions", "katana/scar buy_now, remaining pair lock")

        materials = snapshot["player"]["materials"]
        buy_total = sum(action.get("price", 0) for action in actions.values() if action.get("action") == "buy_now")
        if buy_total <= materials:
            self.pass_("case002_budget_not_exceeded", f"buy_now total {buy_total} <= materials {materials}")
        else:
            self.fail("case002_budget_not_exceeded", f"buy_now total {buy_total} > materials {materials}")

        expected_codes = {
            "weapon_new_katana_2": {"distinct_weapon_increases_slot_cap", "slashing_set_crosses_threshold"},
            "item_scar": {"early_experience_compounds", "range_penalty_is_low_cost_for_current_build"},
            "item_head_injury": {"budget_cannot_buy_all_priority_candidates"},
            "weapon_sword_paladin_1": {"duplicate_weapon_can_immediately_combine_next_shop"},
        }
        missing_codes = []
        for item_id, codes in expected_codes.items():
            actual_codes = set(actions.get(item_id, {}).get("reason_codes", []))
            if not codes <= actual_codes:
                missing_codes.append(f"{item_id}: missing {sorted(codes - actual_codes)}")
        if missing_codes:
            self.fail("case002_shop_reason_codes", "; ".join(missing_codes))
        else:
            self.pass_("case002_shop_reason_codes")

        gaps = {gap["stat_id"]: gap for gap in report.get("stat_diagnosis", [])}
        expected_gaps = {
            "harvesting": 0,
            "recovery": 0,
            "speed": 0,
            "percent_damage": -34,
        }
        gap_errors = []
        for stat_id, expected_current in expected_gaps.items():
            actual = gaps.get(stat_id)
            if actual is None:
                gap_errors.append(f"{stat_id}: missing")
            elif float(actual.get("current")) != float(expected_current):
                gap_errors.append(f"{stat_id}: current {actual.get('current')} != {expected_current}")
        if gap_errors:
            self.fail("case002_stat_gaps", "; ".join(gap_errors))
        else:
            self.pass_("case002_stat_gaps", "primary gaps and observed values matched")

        plans = report.get("plans", {})
        wave_plus_3 = plans.get("wave_plus_3", {}).get("targets", {})
        wave_plus_5 = plans.get("wave_plus_5", {}).get("targets", {})
        plan_errors = []
        for stat_id in ["distinct_weapons", "max_hp", "armor", "speed", "harvesting", "percent_damage"]:
            if stat_id not in wave_plus_3:
                plan_errors.append(f"wave_plus_3 missing {stat_id}")
        for stat_id in ["max_hp", "armor", "speed", "percent_damage"]:
            if stat_id not in wave_plus_5:
                plan_errors.append(f"wave_plus_5 missing {stat_id}")
        if wave_plus_3.get("requires_recovery") is not True:
            plan_errors.append("wave_plus_3 requires_recovery is not true")
        if plan_errors:
            self.fail("case002_plans_plus3_plus5", "; ".join(plan_errors))
        else:
            self.pass_("case002_plans_plus3_plus5", "contains requested +3/+5 targets")

    def check_case001_assertions(self) -> None:
        report = self.reports.get("case001")
        if report is None:
            return
        review = report.get("run_review") or {}
        findings = {finding["id"]: finding for finding in review.get("findings", [])}
        expected_ids = {
            "review.summary",
            "review.early_defense_debt",
            "review.curse_not_closed_loop",
            "review.damage_growth_lags_enemy_hp",
            "review.final_trigger.ancient_altar",
            "review.bad_timing.scar_wave_30",
            "review.positive_growth_engines",
        }
        missing = sorted(expected_ids - set(findings))
        if missing:
            self.fail("case001_required_review_findings", f"missing {missing}")
        else:
            self.pass_("case001_required_review_findings")

        checks = []
        defense = findings.get("review.early_defense_debt", {}).get("evidence", {})
        checks.append(("armor_entering_wave_19", defense.get("armor_entering_wave_19"), 8))
        checks.append(("armor_wave_30", defense.get("armor_wave_30"), 9))
        checks.append(("dodge_wave_30", defense.get("dodge_wave_30"), 14))
        checks.append(("speed_wave_30", defense.get("speed_wave_30"), 5))
        curse = findings.get("review.curse_not_closed_loop", {}).get("evidence", {})
        checks.append(("curse", curse.get("curse"), 47))
        checks.append(("cursed_items", curse.get("cursed_items"), 1))
        checks.append(("cursed_weapons", curse.get("cursed_weapons"), 0))
        final = findings.get("review.final_trigger.ancient_altar", {})
        final_evidence = final.get("evidence", {})
        checks.append(("hp_start_wave_percent", final_evidence.get("hp_start_wave_percent"), 10))
        checks.append(("start_hp_approx", final_evidence.get("start_hp_approx"), 12))
        value_errors = [
            f"{name}: {actual} != {expected}"
            for name, actual, expected in checks
            if actual != expected
        ]
        if final.get("direct_or_root_cause") != "direct" or final.get("severity") != "critical":
            value_errors.append("ancient altar finding is not critical direct cause")
        if value_errors:
            self.fail("case001_review_evidence", "; ".join(value_errors))
        else:
            self.pass_("case001_review_evidence", "defense/mobility, curse, output and final trigger evidence matched")

        early_claims = [
            finding
            for finding in findings.values()
            if isinstance(finding.get("first_observed_wave"), int)
            and 1 <= finding["first_observed_wave"] <= 17
        ]
        if early_claims:
            self.fail("case001_no_fabricated_waves_1_to_17", str(early_claims))
        else:
            self.pass_("case001_no_fabricated_waves_1_to_17", "no finding claims first_observed_wave before 19")

    def check_determinism(self) -> None:
        analyzer = ROOT / "src" / "external-tools" / "analyze_fixture.py"
        for key, fixture in FIXTURES.items():
            hashes = []
            for index in [1, 2]:
                json_out = GENERATED_DIR / key / f"determinism-{index}.json"
                md_out = GENERATED_DIR / key / f"determinism-{index}.md"
                proc = subprocess.run(
                    [
                        PYTHON,
                        str(analyzer),
                        str(fixture),
                        "--json-out",
                        str(json_out),
                        "--markdown-out",
                        str(md_out),
                    ],
                    cwd=ROOT,
                    text=True,
                    capture_output=True,
                )
                if proc.returncode != 0:
                    self.fail(f"{key}_determinism_cli_run_{index}", proc.stderr.strip() or proc.stdout.strip())
                    break
                hashes.append(hashlib.sha256(json_out.read_bytes()).hexdigest())
            if len(hashes) == 2:
                if hashes[0] == hashes[1]:
                    self.pass_(f"{key}_deterministic_json_hash", hashes[0])
                else:
                    self.fail(f"{key}_deterministic_json_hash", f"{hashes[0]} != {hashes[1]}")

    def check_budget(self) -> None:
        for key, report in self.reports.items():
            if not report.get("shop_advice"):
                continue
            loaded = self._json(FIXTURES[key] / "coach-snapshot.json")
            materials = loaded["player"]["materials"]
            buy_total = sum(
                action.get("price", 0)
                for action in report.get("shop_advice", [])
                if action.get("action") == "buy_now"
            )
            if buy_total <= materials:
                self.pass_(f"{key}_generic_budget_guard", f"{buy_total} <= {materials}")
            else:
                self.fail(f"{key}_generic_budget_guard", f"{buy_total} > {materials}")

    def check_missing_wave_coverage(self) -> None:
        report = self.reports.get("case001")
        if report is None:
            return
        coverage = (report.get("run_review") or {}).get("coverage", {})
        warnings = set(report.get("warnings", [])) | set(coverage.get("warnings", []))
        if coverage.get("missing_ranges") != [[1, 17]]:
            self.fail("case001_missing_ranges_preserved", str(coverage.get("missing_ranges")))
        elif "waves_1_to_17_not_available_as_per_wave_history" not in warnings:
            self.fail("case001_missing_ranges_warning", str(sorted(warnings)))
        else:
            self.pass_("case001_missing_ranges_preserved", "missing_ranges [[1, 17]] and warning present")

    def check_jsonl_loader(self) -> None:
        try:
            from coach_core import load_events_jsonl

            jsonl_path = GENERATED_DIR / "jsonl-loader" / "events-with-corruption.jsonl"
            jsonl_path.parent.mkdir(parents=True, exist_ok=True)
            valid_0 = {
                "schema_version": "0.1.0",
                "run_id": "jsonl-test",
                "sequence": 0,
                "captured_at_utc": "2026-07-24T00:00:00Z",
                "event_type": "run_started",
                "player_index": 0,
                "payload": {"character_id": "character_test"},
            }
            unknown_1 = {
                "schema_version": "0.1.0",
                "run_id": "jsonl-test",
                "sequence": 1,
                "captured_at_utc": "2026-07-24T00:00:01Z",
                "event_type": "unknown_future_event",
                "player_index": 0,
                "payload": {"kept": True},
            }
            valid_4 = {
                "schema_version": "0.1.0",
                "run_id": "jsonl-test",
                "sequence": 4,
                "captured_at_utc": "2026-07-24T00:00:04Z",
                "event_type": "wave_completed",
                "player_index": 0,
                "payload": {"wave": 1},
            }
            lines = [
                "\ufeff" + json.dumps(valid_0, ensure_ascii=False),
                json.dumps(unknown_1, ensure_ascii=False),
                '{"schema_version":"0.1.0","run_id":"jsonl-test","sequence":2,',
                json.dumps(valid_4, ensure_ascii=False),
                '{"schema_version":"0.1.0","run_id":"jsonl-test","sequence":5',
            ]
            jsonl_path.write_text("\n".join(lines), encoding="utf-8", newline="\n")
            loaded = load_events_jsonl(jsonl_path)
            events = loaded.get("events", [])
            quality = loaded.get("data_quality", {})
            warnings = set(quality.get("warnings", []))

            errors = []
            if [event.get("sequence") for event in events] != [0, 1, 4]:
                errors.append(f"events sequence list {events}")
            if events[1].get("event_type") != "unknown_future_event":
                errors.append("unknown event_type was not preserved")
            if "truncated_tail" not in warnings:
                errors.append(f"missing truncated_tail warning: {warnings}")
            if "invalid_jsonl_event" not in warnings:
                errors.append(f"missing invalid_jsonl_event warning: {warnings}")
            if "sequence_gap" not in warnings:
                errors.append(f"missing sequence_gap warning: {warnings}")
            if 3 not in quality.get("skipped_lines", []):
                errors.append(f"middle bad line not recorded: {quality.get('skipped_lines')}")
            if 2 not in quality.get("skipped_sequences", []):
                errors.append(f"middle bad sequence not recorded: {quality.get('skipped_sequences')}")
            if {"after": 1, "before": 4} not in quality.get("sequence_gaps", []):
                errors.append(f"sequence gap not recorded: {quality.get('sequence_gaps')}")
            if errors:
                self.fail("jsonl_loader_recovery_contract", "; ".join(errors))
            else:
                self.pass_("jsonl_loader_recovery_contract", "BOM, tail truncation, middle corruption, unknown event and sequence gap handled")
            self.pass_("jsonl_loader_public_import", "coach_core.load_events_jsonl")
        except Exception as exc:
            self.fail("jsonl_loader_recovery_contract", str(exc))

    def check_mod_static(self) -> None:
        zip_path = ROOT / "src" / "brotato-mod" / "dist" / "BrotatoCoach.zip"
        mod_root = MOD_ROOT
        if not zip_path.exists():
            self.fail("mod_zip_exists", "missing src/brotato-mod/dist/BrotatoCoach.zip")
        else:
            with zipfile.ZipFile(zip_path) as archive:
                raw_names = [name for name in archive.namelist() if not name.endswith("/")]
                invalid_names = sorted(name for name in raw_names if "\\" in name)
                names = set(raw_names)
            missing = sorted(EXPECTED_ZIP_ENTRIES - names)
            if invalid_names:
                self.fail(
                    "mod_zip_expected_entries",
                    f"non-portable path separators in {invalid_names[:3]}",
                )
            elif missing:
                self.fail("mod_zip_expected_entries", f"missing {missing}")
            else:
                self.pass_("mod_zip_expected_entries", f"{len(EXPECTED_ZIP_ENTRIES)} expected files present")

        gd_files = sorted(mod_root.rglob("*.gd"))
        gd_text_by_path = {path: path.read_text(encoding="utf-8") for path in gd_files}
        forbidden_patterns = {
            "http_call": re.compile(r"HTTPRequest|HTTPClient|http://|https://", re.IGNORECASE),
            "external_process": re.compile(r"OS\.execute|OS\.shell_open|shell_open|create_process", re.IGNORECASE),
            "enemy_or_main_extension": re.compile(r"res://(?:.*/)?(?:enemy|boss|unit|neutral|main)\.gd"),
            "manual_parent_ready": re.compile(r"(\.\s*_ready\s*\(|super\s*\.\s*_ready\s*\()"),
            "process_collection": re.compile(r"func\s+_process\s*\("),
        }
        for label, pattern in forbidden_patterns.items():
            hits = [
                f"{path.relative_to(ROOT)}"
                for path, text in gd_text_by_path.items()
                if pattern.search(text)
            ]
            if hits:
                self.fail(f"mod_static_no_{label}", "; ".join(hits))
            else:
                self.pass_(f"mod_static_no_{label}")

        entry_paths = {
            "shop": mod_root / "extensions" / "ui" / "menus" / "shop" / "base_shop.gd",
            "pause": mod_root / "extensions" / "ui" / "menus" / "ingame" / "ingame_main_menu.gd",
            "run_end": mod_root / "extensions" / "ui" / "menus" / "run" / "end_run.gd",
        }
        missing_entries = [name for name, path in entry_paths.items() if not path.exists()]
        if missing_entries:
            self.fail("mod_static_three_ui_entries", str(missing_entries))
        else:
            self.pass_("mod_static_three_ui_entries", ", ".join(entry_paths))

        dedupe_errors = []
        for name, path in entry_paths.items():
            text = path.read_text(encoding="utf-8")
            if "get_node_or_null" not in text:
                dedupe_errors.append(f"{name}: no get_node_or_null guard")
            if re.search(r'\.name\s*=\s*"BrotatoCoach(?:Shop|Pause|RunEnd)Button"', text) is None:
                dedupe_errors.append(f"{name}: no stable BrotatoCoach button node name")
        if dedupe_errors:
            self.fail("mod_static_injection_node_dedupe", "; ".join(dedupe_errors))
        else:
            self.pass_("mod_static_injection_node_dedupe")

        panel_path = mod_root / "ui" / "coach_report_panel.gd"
        panel = panel_path.read_text(encoding="utf-8")
        panel_errors = []
        for token in ["ScrollContainer.new", "_on_close_pressed", "queue_free", "focus_mode"]:
            if token not in panel:
                panel_errors.append(token)
        if panel_errors:
            self.fail("mod_static_panel_scroll_close_focus", f"missing {panel_errors}")
        else:
            self.pass_("mod_static_panel_scroll_close_focus")

    def check_runtime_reader_static(self) -> None:
        coordinator_path = MOD_ROOT / "core" / "coach_coordinator.gd"
        text = coordinator_path.read_text(encoding="utf-8")
        required_tokens = [
            "Utils.get_stat(",
            "Keys.stat_armor_hash",
            "RunData.is_endless_run",
            "RunData.players_data",
            "current_health",
            "current_xp",
            "active_sets",
            "RunData.get_player_effects(0)",
            "Keys.stat_max_hp_hash",
        ]
        missing = [token for token in required_tokens if token not in text]
        forbidden_tokens = [
            "/root/Keys",
            "get_player_current_health",
            "get_player_max_health",
            "get_player_xp",
            "get_player_sets",
        ]
        present_forbidden = [token for token in forbidden_tokens if token in text]
        if missing or present_forbidden:
            self.fail(
                "runtime_reader_rundata_keys_static",
                f"missing={missing}; forbidden={present_forbidden}",
            )
        else:
            self.pass_("runtime_reader_rundata_keys_static", "uses global RunData/Utils/Keys and avoids obsolete getters")

    def check_modloader_zip_manifest(self) -> None:
        manifest_path = MOD_ROOT / "manifest.json"
        manifest = self._json(manifest_path)
        godot = manifest.get("extra", {}).get("godot")
        errors = []
        if not isinstance(godot, dict):
            errors.append("extra.godot is not an object")
            godot = {}
        for key in [
            "id",
            "authors",
            "incompatibilities",
            "load_before",
            "compatible_mod_loader_version",
            "compatible_game_version",
        ]:
            if key not in godot:
                errors.append(f"missing extra.godot.{key}")
        if godot.get("id") != MOD_ID:
            errors.append(f"extra.godot.id {godot.get('id')} != {MOD_ID}")
        gd_text = "\n".join(path.read_text(encoding="utf-8") for path in sorted(MOD_ROOT.rglob("*.gd")))
        if f"res://mods-unpacked/{MOD_ID}/" not in gd_text:
            errors.append("source preload/extension paths do not use standard internal ID")
        if "res://mods-unpacked/BrotatoCoach/" in gd_text:
            errors.append("source still references non-standard BrotatoCoach root")
        if errors:
            self.fail("modloader_manifest_standard_structure", "; ".join(errors))
        else:
            self.pass_("modloader_manifest_standard_structure", "manifest extra.godot and source paths use standard ID")

    def check_chinese_panel_static(self) -> None:
        panel_path = MOD_ROOT / "ui" / "coach_report_panel.gd"
        text = panel_path.read_text(encoding="utf-8")
        required_tokens = [
            "土豆教练",
            "立即购买",
            "锁定",
            "稍后购买",
            "跳过",
            "_summary_text",
            "_reason_text",
            "_phrase_text",
            "_finding_text",
            "_targets_text",
            "未来 3 波",
            "未来 5 波",
            "复盘",
        ]
        missing = [token for token in required_tokens if token not in text]
        forbidden_direct = [
            "report.summary.",
            "buy_now",
            "reason_codes",
            "item_id",
            'str(plan.get("targets"',
            'str(action.get("item_id"',
        ]
        present_forbidden = [token for token in forbidden_direct if token in text]
        if missing or present_forbidden:
            self.fail("chinese_panel_no_internal_value_fallback", f"missing={missing}; forbidden={present_forbidden}")
        else:
            self.pass_("chinese_panel_no_internal_value_fallback", "main panel maps internal report fields to Chinese text")

    def check_minimal_recorder_static(self) -> None:
        recorder_path = MOD_ROOT / "core" / "coach_recorder.gd"
        mod_main_path = MOD_ROOT / "mod_main.gd"
        coordinator_path = MOD_ROOT / "core" / "coach_coordinator.gd"
        shop_path = MOD_ROOT / "extensions" / "ui" / "menus" / "shop" / "base_shop.gd"
        pause_path = MOD_ROOT / "extensions" / "ui" / "menus" / "ingame" / "ingame_main_menu.gd"
        run_end_path = MOD_ROOT / "extensions" / "ui" / "menus" / "run" / "end_run.gd"
        errors = []
        if not recorder_path.exists():
            errors.append("missing core/coach_recorder.gd")
        recorder = recorder_path.read_text(encoding="utf-8") if recorder_path.exists() else ""
        mod_main = mod_main_path.read_text(encoding="utf-8")
        coordinator = coordinator_path.read_text(encoding="utf-8")
        shop = shop_path.read_text(encoding="utf-8")
        pause = pause_path.read_text(encoding="utf-8")
        run_end = run_end_path.read_text(encoding="utf-8")
        required_pairs = [
            ("mod_main creates recorder", "BrotatoCoachRecorder" in mod_main and "root.add_child(recorder)" in mod_main),
            ("recorder writes user runs path", "user://brotato_coach/runs" in recorder),
            ("shop ready records snapshot", "record_shop_ready" in shop and "record_shop_snapshot" in recorder),
            ("shop snapshot dedupe", "_last_shop_key" in recorder and "_shop_key" in recorder),
            ("pause records coach_requested", '"pause"' in pause and "record_coach_requested" in coordinator),
            ("run_end records and loads history", '"run_end"' in run_end and "record_run_end" in coordinator and "load_current_events" in coordinator),
            ("no process sampling", "func _process(" not in recorder and "func _process(" not in coordinator),
        ]
        errors.extend(label for label, ok in required_pairs if not ok)
        if errors:
            self.fail("minimal_recorder_static_contract", "; ".join(errors))
        else:
            self.pass_("minimal_recorder_static_contract", "recorder exists, is mounted, logs key events and avoids _process sampling")

    def check_no_legacy_mod_id_residue(self) -> None:
        terms = ["Fu" + "bo", "Fu" + "bo-BrotatoCoach"]
        hits = []
        for path in sorted(ROOT.rglob("*")):
            if ".git" in path.parts or not path.is_file():
                continue
            relative = str(path.relative_to(ROOT)).replace("\\", "/")
            if any(term in relative for term in terms):
                hits.append(f"{relative}:filename")
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                text = path.read_text(encoding="utf-8", errors="ignore")
            for term in terms:
                if term in text:
                    hits.append(f"{relative}:contains {term}")
                    break
        if hits:
            self.fail("no_legacy_mod_id_residue", "; ".join(hits[:20]))
        else:
            self.pass_("no_legacy_mod_id_residue", "no exact legacy ID residue found outside .git")

    def check_fixture_hashes_unchanged(self) -> None:
        after = self._fixture_hashes()
        if after == self.fixture_hashes_before:
            self.pass_("fixture_hashes_unchanged", f"{len(after)} files unchanged")
        else:
            before_keys = set(self.fixture_hashes_before)
            after_keys = set(after)
            changed = sorted(
                path
                for path in before_keys & after_keys
                if self.fixture_hashes_before[path] != after[path]
            )
            added = sorted(after_keys - before_keys)
            removed = sorted(before_keys - after_keys)
            self.fail("fixture_hashes_unchanged", f"changed={changed}; added={added}; removed={removed}")

    def write_results(self) -> None:
        summary = {
            "counts": {
                "PASS": sum(1 for result in self.results if result.status == "PASS"),
                "FAIL": sum(1 for result in self.results if result.status == "FAIL"),
                "GAP": sum(1 for result in self.results if result.status == "GAP"),
            },
            "results": [asdict(result) for result in self.results],
        }
        (REPORT_DIR / "p1-acceptance-results.json").write_text(
            json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )

    def _json(self, path: Path) -> Any:
        return json.loads(path.read_text(encoding="utf-8"))

    def _fixture_hashes(self) -> dict[str, str]:
        hashes = {}
        fixture_root = ROOT / "tests" / "fixtures"
        for path in sorted(fixture_root.rglob("*")):
            if path.is_file():
                hashes[str(path.relative_to(ROOT)).replace("\\", "/")] = hashlib.sha256(path.read_bytes()).hexdigest()
        return hashes


if __name__ == "__main__":
    raise SystemExit(Acceptance().run())
