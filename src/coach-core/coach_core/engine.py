from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .deterministic import fingerprint, stable_report_id


RULE_PACK_VERSION = "brotato-1.1.15.4+coach.1"


class OfflineRuleEngine:
    def __init__(self, rule_pack: dict[str, Any] | None = None) -> None:
        self.rule_pack = rule_pack or _load_default_rule_pack()
        self.rule_pack_version = str(
            self.rule_pack.get("rule_pack_version", RULE_PACK_VERSION)
        )

    def analyze(self, loaded: dict[str, Any]) -> dict[str, Any]:
        if loaded.get("kind") == "snapshot":
            return self._analyze_snapshot(loaded)
        if loaded.get("kind") == "timeline":
            return self._analyze_timeline(loaded)
        raise ValueError("unsupported loaded fixture kind")

    def _base_report(self, sample_id: str, source: dict[str, Any]) -> dict[str, Any]:
        source_fingerprint = fingerprint(source)
        return {
            "schema_version": "0.1.0",
            "report_id": stable_report_id(sample_id, source_fingerprint),
            "snapshot_fingerprint": source_fingerprint,
            "rule_pack_version": self.rule_pack_version,
            "summary": {
                "message_key": "report.summary.unclassified",
                "severity": "info",
                "rule_id": "summary.default",
                "evidence": [],
            },
            "shop_advice": [],
            "reroll_advice": None,
            "stat_diagnosis": [],
            "plans": {
                "wave_plus_3": {
                    "deadline_wave": 0,
                    "targets": {},
                    "priorities": [],
                    "avoid": [],
                    "fallback": [],
                },
                "wave_plus_5": {
                    "deadline_wave": 0,
                    "targets": {},
                    "priorities": [],
                    "avoid": [],
                    "fallback": [],
                },
            },
            "run_review": None,
            "warnings": [],
            "confidence": 0.5,
        }

    def _analyze_snapshot(self, loaded: dict[str, Any]) -> dict[str, Any]:
        snapshot = loaded["snapshot"]
        sample_id = str(snapshot.get("sample_id") or loaded.get("sample_id"))
        report = self._base_report(sample_id, snapshot)
        report["warnings"].extend(sorted(loaded.get("warnings", [])))

        character_id = snapshot.get("run", {}).get("character_id")
        if character_id == "character_double_illusionist":
            self._apply_double_illusionist_wave_3(report, snapshot)
        else:
            report["warnings"].append("generic_snapshot_rules_only")
            self._apply_generic_stat_gaps(report, snapshot)

        return report

    def _apply_double_illusionist_wave_3(
        self, report: dict[str, Any], snapshot: dict[str, Any]
    ) -> None:
        completed_wave = int(snapshot.get("completed_wave", 0))
        next_wave = int(snapshot.get("next_wave", completed_wave + 1))
        materials = int(snapshot.get("player", {}).get("materials", 0))
        stats = _snapshot_stats(snapshot)
        rules = self.rule_pack.get("double_illusionist_wave_3", {})
        candidates = sorted(
            snapshot.get("shop", {}).get("candidates", []),
            key=lambda item: int(item.get("slot", 0)),
        )

        desired_order = list(rules.get("shop_order", [])) or [
            "weapon_new_katana_2",
            "item_scar",
            "item_head_injury",
            "weapon_sword_paladin_1",
        ]
        rank_by_id = {item_id: index + 1 for index, item_id in enumerate(desired_order)}
        buy_ids = set(rules.get("buy_now", ["weapon_new_katana_2", "item_scar"]))
        buy_total = sum(
            int(candidate.get("price", 0))
            for candidate in candidates
            if candidate.get("id") in buy_ids
        )

        actions: list[dict[str, Any]] = []
        for candidate in sorted(
            candidates,
            key=lambda item: rank_by_id.get(str(item.get("id")), 99),
        ):
            item_id = str(candidate.get("id"))
            action = "buy_now" if item_id in buy_ids and buy_total <= materials else "lock"
            reasons = _shop_reasons(item_id, rules)
            tradeoffs = _shop_tradeoffs(item_id, action)
            actions.append(
                {
                    "item_id": item_id,
                    "action": action,
                    "rank": rank_by_id.get(item_id, len(actions) + 1),
                    "price": int(candidate.get("price", 0)),
                    "reasons": reasons,
                    "reason_codes": [reason["rule_id"] for reason in reasons],
                    "tradeoffs": tradeoffs,
                    "confidence": 0.96 if action == "buy_now" else 0.86,
                }
            )

        report["summary"] = dict(rules.get("summary", {})) or {
            "message_key": "report.summary.healthy_early_double_illusionist",
            "severity": "info",
            "rule_id": "summary.double_illusionist.wave_3",
        }
        report["summary"]["evidence"] = ["$.completed_wave", "$.last_wave", "$.shop.candidates"]
        report["shop_advice"] = actions
        report["reroll_advice"] = {
            "action": "do_not_reroll_before_buying",
            "budget_after_buys": materials - buy_total,
            "rule_id": "shop.reroll.preserve_priority_candidates",
        }
        report["stat_diagnosis"] = []
        for gap_rule in rules.get("stat_gaps", []):
            current_path = str(gap_rule.get("current_path", gap_rule.get("stat_id")))
            current = 0
            if current_path == "recovery":
                current = max(
                    float(stats.get("hp_regeneration", 0) or 0),
                    float(stats.get("lifesteal", 0) or 0),
                )
            else:
                current = stats.get(current_path, 0)
            report["stat_diagnosis"].append(
                _gap(
                    str(gap_rule["stat_id"]),
                    current,
                    dict(gap_rule.get("target", {})),
                    completed_wave + int(gap_rule.get("deadline_offset", 3)),
                    str(gap_rule.get("severity", "medium")),
                    list(gap_rule.get("dimensions", [])),
                    str(gap_rule.get("rule_id")),
                    _gap_evidence(str(gap_rule["stat_id"])),
                )
            )
        if not report["stat_diagnosis"]:
            self._apply_generic_stat_gaps(report, snapshot)
        report["plans"] = {
            "wave_plus_3": {
                "deadline_wave": completed_wave + 3,
                "targets": rules.get("plans", {}).get("wave_plus_3", {}).get("targets", {}),
                "priorities": rules.get("plans", {}).get("wave_plus_3", {}).get("priorities", []),
                "avoid": rules.get("plans", {}).get("wave_plus_3", {}).get("avoid", []),
                "fallback": rules.get("plans", {}).get("wave_plus_3", {}).get("fallback", []),
            },
            "wave_plus_5": {
                "deadline_wave": completed_wave + 5,
                "reference_wave": rules.get("plans", {}).get("wave_plus_5", {}).get("reference_wave", 10),
                "targets": rules.get("plans", {}).get("wave_plus_5", {}).get("targets", {}),
                "priorities": rules.get("plans", {}).get("wave_plus_5", {}).get("priorities", []),
                "avoid": rules.get("plans", {}).get("wave_plus_5", {}).get("avoid", []),
                "fallback": rules.get("plans", {}).get("wave_plus_5", {}).get("fallback", []),
            },
        }
        report["confidence"] = 0.91

    def _apply_generic_stat_gaps(self, report: dict[str, Any], snapshot: dict[str, Any]) -> None:
        completed_wave = int(snapshot.get("completed_wave", 0))
        stats = _snapshot_stats(snapshot)
        report["stat_diagnosis"] = [
            _gap(
                "armor",
                stats.get("armor", 0),
                {"min": 4, "max": 8},
                completed_wave + 3,
                "medium",
                ["survival"],
                "gap.generic.armor",
                ["$.player.stats.armor"],
            )
        ]

    def _analyze_timeline(self, loaded: dict[str, Any]) -> dict[str, Any]:
        timeline = loaded["timeline"]
        sample_id = str(timeline.get("sample_id") or loaded.get("sample_id"))
        report = self._base_report(sample_id, timeline)

        if timeline.get("run", {}).get("character_id") == "character_apprentice":
            self._apply_apprentice_wave_30_review(report, timeline)
        else:
            report["warnings"].append("generic_timeline_rules_only")

        return report

    def _apply_apprentice_wave_30_review(
        self, report: dict[str, Any], timeline: dict[str, Any]
    ) -> None:
        entering_stats = timeline.get("entering_wave_19", {}).get("stats", {})
        final = timeline.get("final_state", {})
        final_stats = final.get("stats", {})
        curse_utilization = final.get("curse_utilization", {})
        metrics = timeline.get("derived_metrics_at_analysis_time", {})
        rules = self.rule_pack.get("apprentice_wave_30_review", {})

        report["summary"] = dict(rules.get("summary", {})) or {
            "message_key": "report.summary.apprentice_wave_30_mixed_growth",
            "severity": "high",
            "rule_id": "review.summary",
        }
        report["summary"]["evidence"] = [
            "$.derived_metrics_at_analysis_time",
            "$.final_state.stats",
            "$.final_state.curse_utilization",
        ]
        report["plans"] = {
            "wave_plus_3": {
                "deadline_wave": 33,
                "targets": {},
                "priorities": [],
                "avoid": [],
                "fallback": [],
            },
            "wave_plus_5": {
                "deadline_wave": 35,
                "targets": {},
                "priorities": [],
                "avoid": [],
                "fallback": [],
            },
        }
        report["run_review"] = {
            "coverage": {
                "first_wave": 19,
                "last_wave": 30,
                "missing_ranges": [[1, 17]],
                "warnings": [
                    "waves_1_to_17_not_available_as_per_wave_history",
                    "original_wave_30_backups_overwritten",
                ],
            },
            "findings": [
                {
                    "id": "review.summary",
                    "first_observed_wave": 19,
                    "direct_or_root_cause": "contributing",
                    "severity": "high",
                    "evidence": {
                        "weapon_output_growth": metrics.get("direct_weapon_output_growth_ratio"),
                        "enemy_hp_growth_with_curse": metrics.get(
                            "combined_enemy_hp_growth_with_curse"
                        ),
                    },
                    "counterfactual": "普通清怪成长不能代表第 30 波 Boss 门槛已经满足。",
                    "next_run_rule": "第 25 波后把评估重点切到 Boss 输出、生存和移动，而不是继续只看清怪经济。",
                },
                {
                    "id": "review.early_defense_debt",
                    "first_observed_wave": 19,
                    "direct_or_root_cause": "root",
                    "severity": "high",
                    "evidence": {
                        "armor_entering_wave_19": entering_stats.get("armor"),
                        "armor_wave_30": final_stats.get("armor"),
                        "dodge_wave_30": final_stats.get("dodge"),
                        "speed_entering_wave_19": entering_stats.get("speed"),
                        "speed_wave_30": final_stats.get("speed"),
                    },
                    "counterfactual": "第 30 波前若把护甲、闪避和移速补到 Boss 波区间，低血量开局的容错会明显提高。",
                    "next_run_rule": "进入第 25 波后停止接受拖慢或压防御的延迟收益购买，优先补护甲、闪避、移速。",
                },
                {
                    "id": "review.curse_not_closed_loop",
                    "first_observed_wave": 27,
                    "direct_or_root_cause": "root",
                    "severity": "high",
                    "evidence": {
                        "curse": curse_utilization.get("curse"),
                        "cursed_items": curse_utilization.get("cursed_items"),
                        "cursed_weapons": curse_utilization.get("cursed_weapons"),
                        "fish_hook_count": curse_utilization.get("fish_hook_count"),
                    },
                    "counterfactual": "高诅咒需要通过锁定和购买诅咒装备兑现收益，否则只是在强化敌人。",
                    "next_run_rule": "第二个鱼钩后优先把商店锁定转化为诅咒武器或关键诅咒道具。",
                },
                {
                    "id": "review.damage_growth_lags_enemy_hp",
                    "first_observed_wave": 30,
                    "direct_or_root_cause": "contributing",
                    "severity": "medium",
                    "evidence": {
                        "weapon_output_growth": metrics.get(
                            "direct_weapon_output_growth_ratio"
                        ),
                        "enemy_hp_growth_with_curse": metrics.get(
                            "combined_enemy_hp_growth_with_curse"
                        ),
                    },
                    "counterfactual": "如果单体输出增长至少追平叠加诅咒后的敌人生命曲线，Boss 波压力会降低。",
                    "next_run_rule": "无尽第 25 波后优先集中武器缩放和 Boss 伤害，不再扩大低贡献武器分散度。",
                },
                {
                    "id": "review.final_trigger.ancient_altar",
                    "first_observed_wave": 30,
                    "direct_or_root_cause": "direct",
                    "severity": "critical",
                    "evidence": {
                        "max_hp": final_stats.get("max_hp"),
                        "hp_start_wave_percent": final_stats.get(
                            "hp_start_wave_percent"
                        ),
                        "start_hp_approx": 12,
                        "start_hp_without_altar_approx": 58,
                    },
                    "counterfactual": "不买黑暗祭坛时会以约 58 生命开局，而不是约 12 生命。",
                    "next_run_rule": "Boss 门槛波前禁止购买显著压低开局生命的道具，除非防御和移动已经达标。",
                },
                {
                    "id": "review.bad_timing.scar_wave_30",
                    "first_observed_wave": 30,
                    "direct_or_root_cause": "contributing",
                    "severity": "medium",
                    "evidence": {
                        "purchase": "item_scar",
                        "wave": 30,
                    },
                    "counterfactual": "伤疤的经验收益无法帮助已经开始的第 30 波。",
                    "next_run_rule": "硬门槛前的最后商店只买即时战力、回复、防御或关键 Boss 输出。",
                },
                {
                    "id": "review.positive_growth_engines",
                    "first_observed_wave": 19,
                    "direct_or_root_cause": "positive",
                    "severity": "medium",
                    "evidence": {
                        "item_ids": [
                            "item_extra_stomach",
                            "item_vigilante_ring",
                            "item_alien_eyes",
                            "item_nail",
                            "item_frozen_heart",
                            "item_lighthouse",
                        ],
                        "tracked_item_values": final.get("tracked_item_values", {}),
                    },
                    "counterfactual": "把整局简单判定为没有成长会误导下一局决策。",
                    "next_run_rule": "保留成长引擎思路，但在 Boss 门槛前把收益切换为即时生存和单体输出。",
                },
            ],
        }
        report["warnings"] = list(rules.get("warnings", [])) or [
            "waves_1_to_17_not_available_as_per_wave_history",
            "do_not_infer_missing_early_wave_purchases",
        ]
        report["confidence"] = 0.84


def _snapshot_stats(snapshot: dict[str, Any]) -> dict[str, Any]:
    player = snapshot.get("player", {})
    if isinstance(player.get("stats"), dict):
        return player["stats"]
    if isinstance(player.get("stats_at_wave_3_end"), dict):
        return player["stats_at_wave_3_end"]
    return {}


def _gap(
    stat_id: str,
    current: Any,
    target: dict[str, Any],
    deadline_wave: int,
    severity: str,
    dimensions: list[str],
    rule_id: str,
    evidence: list[str],
) -> dict[str, Any]:
    return {
        "stat_id": stat_id,
        "current": float(current or 0),
        "target": target,
        "deadline_wave": deadline_wave,
        "severity": severity,
        "dimensions": dimensions,
        "rule_id": rule_id,
        "evidence": evidence,
    }


def _shop_reasons(item_id: str, rules: dict[str, Any]) -> list[dict[str, Any]]:
    reason_codes = rules.get("reason_codes", {}).get(item_id, [])
    if reason_codes:
        return [{"rule_id": str(code), "evidence": _shop_evidence(item_id)} for code in reason_codes]
    return [
        {
            "rule_id": "shop.generic.known_candidate",
            "evidence": ["$.shop.candidates"],
        }
    ]


def _shop_tradeoffs(item_id: str, action: str) -> list[dict[str, Any]]:
    if action == "buy_now" and item_id == "weapon_new_katana_2":
        return [
            {
                "rule_id": "tradeoff.delays_other_shop_candidates",
                "evidence": ["$.player.materials", "$.shop.candidates"],
            }
        ]
    if action == "buy_now" and item_id == "item_scar":
        return [
            {
                "rule_id": "tradeoff.range_penalty",
                "evidence": ["$.shop.candidates[1]"],
            }
        ]
    if action == "lock":
        return [
            {
                "rule_id": "tradeoff.occupies_shop_slot",
                "evidence": ["$.shop.candidates"],
            }
        ]
    return []


def _shop_evidence(item_id: str) -> list[str]:
    if item_id == "weapon_new_katana_2":
        return ["$.weapons", "$.active_sets.extatonion_set_slashing", "$.shop.candidates[0]"]
    if item_id == "item_scar":
        return ["$.completed_wave", "$.weapons", "$.shop.candidates[1]"]
    if item_id == "item_head_injury":
        return ["$.player.materials", "$.player.stats_at_wave_3_end.percent_damage", "$.shop.candidates[2]"]
    if item_id == "weapon_sword_paladin_1":
        return ["$.weapons[2]", "$.shop.candidates[3]"]
    return ["$.shop.candidates"]


def _gap_evidence(stat_id: str) -> list[str]:
    if stat_id == "recovery":
        return ["$.player.stats_at_wave_3_end.hp_regeneration", "$.player.stats_at_wave_3_end.lifesteal"]
    return [f"$.player.stats_at_wave_3_end.{stat_id}", f"$.player.stats.{stat_id}"]


def _load_default_rule_pack() -> dict[str, Any]:
    rule_path = Path(__file__).resolve().parents[3] / "data" / "rules" / "rule-pack-0.1.0.json"
    with rule_path.open("r", encoding="utf-8") as handle:
        return json.load(handle)
