"""Offline Brotato coach core.

The core accepts plain dictionaries and returns plain dictionaries so the rule
surface can later be ported to GDScript without carrying Python object state
into the game adapter.
"""

from .engine import OfflineRuleEngine
from .loaders import load_events_jsonl, load_fixture

__all__ = ["OfflineRuleEngine", "load_events_jsonl", "load_fixture"]
