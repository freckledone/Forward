#!/usr/bin/env python3
"""
Transform Free Exercise DB (Unlicense) into Further's schema.

Source: https://github.com/yuhonas/free-exercise-db
Spec: docs/06-exercise-database-specification.md

Usage:
  python3 scripts/transform-exercises.py > Further/Resources/exercises.json

Deterministic; running twice on the same source produces identical output.
"""
from __future__ import annotations

import json
import re
import sys
import urllib.request
from typing import Optional

SOURCE_URL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json"

KEEP_CATEGORIES = {"strength", "powerlifting", "olympic weightlifting", "strongman"}
DROP_EQUIPMENT_VALUES = {"exercise ball", "foam roll", "medicine ball", "other"}

MUSCLE_MAP: dict[str, str] = {
    "abdominals": "core",
    "quadriceps": "quads",
    "middle back": "back",
    "lower back": "back",
    "chest": "chest",
    "back": "back",
    "lats": "lats",
    "shoulders": "shoulders",
    "biceps": "biceps",
    "triceps": "triceps",
    "hamstrings": "hamstrings",
    "glutes": "glutes",
    "calves": "calves",
    "forearms": "forearms",
    "traps": "traps",
}
DROP_MUSCLES = {"abductors", "adductors", "neck"}

EQUIPMENT_MAP: dict[str, str] = {
    "body only": "bodyweight",
    "bands": "band",
    "kettlebells": "kettlebell",
    "e-z curl bar": "ezBar",
    "barbell": "barbell",
    "dumbbell": "dumbbell",
    "cable": "cable",
    "machine": "machine",
}


def slugify(s: str) -> str:
    s = s.lower()
    s = re.sub(r"[_\s]+", "-", s)
    s = re.sub(r"[^a-z0-9-]", "", s)
    s = re.sub(r"-+", "-", s).strip("-")
    return s


def derive_movement_pattern(name: str, force: Optional[str], mechanic: Optional[str]) -> Optional[str]:
    n = name.lower()
    if "squat" in n and "swing" not in n:
        return "squat"
    if any(k in n for k in ("deadlift", "romanian", "hip thrust", "good morning")):
        return "hinge"
    if any(k in n for k in ("lunge", "step-up", "step up", "split squat", "bulgarian")):
        return "lunge"
    if any(k in n for k in ("carry", "farmer", "sled")):
        return "carry"
    if mechanic == "isolation":
        return "isolate"
    if force == "push":
        return "push"
    if force == "pull":
        return "pull"
    return None


def transform(entry: dict) -> Optional[dict]:
    if entry.get("category") not in KEEP_CATEGORIES:
        return None
    equipment = entry.get("equipment")
    if equipment is None or equipment in DROP_EQUIPMENT_VALUES:
        return None

    def map_muscles(muscles: list[str]) -> list[str]:
        out: list[str] = []
        for m in muscles or []:
            if m in DROP_MUSCLES:
                continue
            mapped = MUSCLE_MAP.get(m)
            if mapped and mapped not in out:
                out.append(mapped)
        return out

    primary = map_muscles(entry.get("primaryMuscles", []))
    if not primary:
        return None
    secondary = [m for m in map_muscles(entry.get("secondaryMuscles", [])) if m not in primary]

    mapped_equipment = EQUIPMENT_MAP.get(equipment)
    if mapped_equipment is None:
        return None
    loading_mode = "bodyweight" if mapped_equipment == "bodyweight" else "weighted"

    instructions = entry.get("instructions") or []
    joined_instructions = "\n\n".join(instructions) if instructions else None

    return {
        "id": slugify(entry["id"]),
        "name": entry["name"],
        "aliases": [],
        "loadingMode": loading_mode,
        "primaryMuscles": primary,
        "secondaryMuscles": secondary,
        "equipment": [mapped_equipment],
        "movementPattern": derive_movement_pattern(
            entry["name"], entry.get("force"), entry.get("mechanic")
        ),
        "instructions": joined_instructions,
    }


def main() -> list[dict]:
    print("Fetching source...", file=sys.stderr)
    with urllib.request.urlopen(SOURCE_URL) as r:
        source = json.load(r)
    print(f"Loaded {len(source)} source exercises.", file=sys.stderr)

    transformed: list[dict] = []
    seen_ids: set[str] = set()
    dupe_count = 0
    for entry in source:
        result = transform(entry)
        if result is None:
            continue
        if result["id"] in seen_ids:
            disambig = f"{result['id']}-{result['equipment'][0]}"
            if disambig in seen_ids:
                dupe_count += 1
                continue
            result["id"] = disambig
        seen_ids.add(result["id"])
        transformed.append(result)

    transformed.sort(key=lambda e: e["name"].lower())
    print(f"Transformed to {len(transformed)} exercises ({dupe_count} unresolvable duplicates dropped).", file=sys.stderr)
    return transformed


if __name__ == "__main__":
    result = main()
    json.dump(result, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")
