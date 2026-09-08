#!/usr/bin/env python3
"""
Coverage pass over Further/Resources/exercises.json.

Applies per D-037:
  - Rename ugly source names on the user's active exercises to preferred names
  - Populate `aliases` so search finds exercises via common terminology
  - Correct primary-muscle metadata where the source data is wrong
  - Add new entries for exercises the user does that the source lacks

Idempotent: safe to re-run. Overwrites Further/Resources/exercises.json.

Provenance: user's active-exercise list comes from a MacroFactor training-program
export dated 2026-08-31. This script encodes the coverage decisions in code
so the transformation from base seed → curated seed is reproducible.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
JSON_PATH = REPO / "Further" / "Resources" / "exercises.json"

# --- Renames (id → new display name). Existing id preserved to keep any references stable.
RENAMES: dict[str, str] = {
    "barbell-bench-press-medium-grip": "Barbell Bench Press",
    "seated-cable-rows": "Seated Cable Row",
    "split-squat-with-dumbbells": "Dumbbell Bulgarian Split Squat",
    "seated-dumbbell-press": "Seated Dumbbell Overhead Press",
    "lying-leg-curls": "Lying Leg Curl",
    "pallof-press": "Cable Pallof Press",
    "wide-grip-lat-pulldown": "Cable Lat Pulldown",
    "barbell-hip-thrust": "Hip Thrust",
    "leg-extensions": "Leg Extension",
    "side-lateral-raise": "Dumbbell Lateral Raise",
    "hammer-curls": "Dumbbell Hammer Curl",
    "cable-rope-overhead-triceps-extension": "Cable Overhead Triceps Extension",
    "pullups": "Pull-Up",
}

# --- Aliases (id → list of alternate search terms; lowercased).
ALIASES: dict[str, list[str]] = {
    "barbell-bench-press-medium-grip":       ["bench press", "bb bench", "flat bench"],
    "seated-cable-rows":                     ["cable row", "neutral grip cable row", "seated row"],
    "split-squat-with-dumbbells":            ["bulgarian split squat", "bss", "dumbbell bss"],
    "seated-dumbbell-press":                 ["seated db press", "seated ohp", "seated shoulder press", "seated overhead press"],
    "cable-rear-delt-fly":                   ["single arm rear delt fly", "rear delt fly", "cable reverse fly"],
    "lying-leg-curls":                       ["lying hamstring curl", "hamstring curl", "leg curl", "lying leg curl"],
    "ez-bar-curl":                           ["ez curl", "ez bar biceps curl", "ezb curl"],
    "pallof-press":                          ["pallof press"],
    "incline-dumbbell-press":                ["low incline dumbbell press", "incline db press", "low incline"],
    "wide-grip-lat-pulldown":                ["lat pulldown", "overhand grip cable lat pulldown", "pulldown", "cable pulldown"],
    "barbell-hip-thrust":                    ["machine hip thrust", "hip thrust", "glute thrust", "plate loaded hip thrust"],
    "leg-extensions":                        ["leg ext", "leg extension"],
    "side-lateral-raise":                    ["lateral raise", "side raise", "standing dumbbell lateral raise", "db lateral raise", "dumbbell lateral raise"],
    "hammer-curls":                          ["hammer curl", "standing hammer curl", "db hammer curl"],
    "cable-rope-overhead-triceps-extension": ["overhead triceps extension", "cable overhead triceps", "ohte", "high pulley triceps", "cable straight bar overhead triceps extension"],
    "seated-calf-raise":                     ["seated calf", "machine calf raise", "seated machine calf raise", "plate loaded calf raise"],
    "pullups":                               ["pullup", "pull up", "pull-up", "neutral grip pull-up", "chinup", "neutral grip pullup"],
    "leg-press":                             ["45 leg press", "45° leg press", "45 degree leg press", "plate loaded leg press"],
    "incline-dumbbell-curl":                 ["incline dumbbell curl", "incline db curl", "incline biceps curl"],
    "dead-bug":                              ["dead bug"],
}

# --- Primary-muscle corrections (id → new primaryMuscles list).
PRIMARY_MUSCLE_FIXES: dict[str, list[str]] = {
    # Source lists "back" as primary for barbell-hip-thrust in some entries; ensure it's glutes.
    "barbell-hip-thrust": ["glutes"],
}

# --- Equipment corrections (id → new equipment list).
# Per D-046: `plateLoadedMachine` distinguishes plate-loaded strength machines
# (Hammer Strength-style, plate-loaded hip thrust, 45° leg press) from
# selectorized/stack-loaded machines (`machine`). Source data doesn't
# distinguish, so we override specific known exercises here.
EQUIPMENT_FIXES: dict[str, list[str]] = {
    "barbell-hip-thrust": ["plateLoadedMachine", "barbell"],
    "leg-press":          ["plateLoadedMachine"],
    "seated-calf-raise":  ["plateLoadedMachine"],
}

# --- New entries (list of full exercise dicts).
NEW_ENTRIES: list[dict] = [
    {
        "id": "back-extension",
        "name": "Back Extension",
        "aliases": ["hyperextension", "roman chair back extension", "45 back extension", "roman chair hip hinge"],
        "loadingMode": "bodyweight",
        "primaryMuscles": ["hamstrings", "glutes", "back"],
        "secondaryMuscles": [],
        "equipment": ["bodyweight"],
        "movementPattern": "hinge",
        "instructions": (
            "Position yourself on a back-extension bench (Roman chair or 45° bench) with the pad "
            "at your hips and feet secured.\n\n"
            "Cross your arms across your chest or place your hands behind your head.\n\n"
            "Hinge at the hips to lower your torso toward the floor, keeping a neutral spine.\n\n"
            "Squeeze the glutes and hamstrings to raise your torso back to horizontal. Do not "
            "hyperextend past neutral.\n\n"
            "Repeat for the recommended amount of repetitions."
        ),
    },
    {
        "id": "chest-supported-dumbbell-row",
        "name": "Chest-Supported Dumbbell Row",
        "aliases": ["chest supported row", "incline bench row", "chest supported elbows in dumbbell row"],
        "loadingMode": "weighted",
        "primaryMuscles": ["back"],
        "secondaryMuscles": ["lats", "biceps"],
        "equipment": ["dumbbell"],
        "movementPattern": "pull",
        "instructions": (
            "Set an incline bench to roughly 30–45°. Lie face-down with your chest on the pad "
            "and a dumbbell in each hand hanging beneath you.\n\n"
            "Row both dumbbells toward your hips with your elbows tucked close to your torso "
            "(elbows-in variant), squeezing the mid-back at the top.\n\n"
            "Lower under control back to the start position. Keep your chest on the pad throughout.\n\n"
            "Repeat for the recommended amount of repetitions."
        ),
    },
    {
        "id": "dumbbell-y-raise",
        "name": "Dumbbell Y-Raise",
        "aliases": ["y raise", "y-raise", "chest supported dumbbell y raise", "prone y raise"],
        "loadingMode": "weighted",
        "primaryMuscles": ["shoulders"],
        "secondaryMuscles": ["traps"],
        "equipment": ["dumbbell"],
        "movementPattern": "isolate",
        "instructions": (
            "Set an incline bench to roughly 30–45°. Lie face-down with your chest on the pad "
            "and a light dumbbell in each hand.\n\n"
            "With arms slightly bent, raise both dumbbells overhead in a 'Y' shape — thumbs up, "
            "arms wide of the head. Squeeze the mid-back and rear delts at the top.\n\n"
            "Lower under control. Keep your chest on the pad and avoid shrugging.\n\n"
            "Repeat for the recommended amount of repetitions."
        ),
    },
    {
        "id": "pec-deck",
        "name": "Pec Deck",
        "aliases": ["pec deck fly", "machine chest fly", "pec fly", "machine fly"],
        "loadingMode": "weighted",
        "primaryMuscles": ["chest"],
        "secondaryMuscles": [],
        "equipment": ["machine"],
        "movementPattern": "isolate",
        "instructions": (
            "Sit on the Pec Deck machine with your back flat against the pad and forearms or "
            "hands on the pads (depending on the machine variant). Adjust the seat so your upper "
            "arms are roughly parallel to the floor.\n\n"
            "Squeeze the handles or pads together in front of your chest, focusing on the "
            "contraction in the pecs.\n\n"
            "Return under control to the starting position without letting the weight stack "
            "touch down between reps.\n\n"
            "Repeat for the recommended amount of repetitions."
        ),
    },
    {
        "id": "cable-lateral-raise",
        "name": "Cable Lateral Raise",
        "aliases": ["single arm cable lateral raise", "cable side raise", "high cable lateral raise"],
        "loadingMode": "weighted",
        "primaryMuscles": ["shoulders"],
        "secondaryMuscles": [],
        "equipment": ["cable"],
        "movementPattern": "isolate",
        "instructions": (
            "Set the cable to hip height (or high, for the high-cable variant). Stand side-on "
            "to the cable and grip the handle with the far hand.\n\n"
            "With a slight bend at the elbow, raise your arm out to the side until it reaches "
            "shoulder height. Keep the shoulder down and away from the ear.\n\n"
            "Lower under control back to the start position. Complete all reps on one side, "
            "then switch.\n\n"
            "Repeat for the recommended amount of repetitions."
        ),
    },
    {
        "id": "seated-dumbbell-overhead-triceps-extension",
        "name": "Seated Dumbbell Overhead Triceps Extension",
        "aliases": ["seated db overhead triceps extension", "seated overhead triceps extension", "seated tricep extension"],
        "loadingMode": "weighted",
        "primaryMuscles": ["triceps"],
        "secondaryMuscles": [],
        "equipment": ["dumbbell"],
        "movementPattern": "isolate",
        "instructions": (
            "Sit upright on a bench with back support. Hold a single dumbbell (or two dumbbells) "
            "overhead with your arms extended.\n\n"
            "Keeping your upper arms stationary, bend at the elbows to lower the dumbbell behind "
            "your head. Keep the elbows close to the head, not flaring out.\n\n"
            "Extend at the elbows to press the dumbbell back to the starting position, "
            "squeezing the triceps at the top.\n\n"
            "Repeat for the recommended amount of repetitions."
        ),
    },
]


def apply_coverage_pass(seed: list[dict]) -> list[dict]:
    by_id: dict[str, dict] = {e["id"]: e for e in seed}

    # Renames
    for slug, new_name in RENAMES.items():
        if slug in by_id:
            by_id[slug]["name"] = new_name
        else:
            print(f"WARN: rename target not found: {slug}", file=sys.stderr)

    # Aliases (merge, dedupe, lowercase)
    for slug, aliases in ALIASES.items():
        if slug in by_id:
            existing = set(a.lower() for a in by_id[slug].get("aliases") or [])
            for a in aliases:
                existing.add(a.lower())
            by_id[slug]["aliases"] = sorted(existing)
        else:
            print(f"WARN: alias target not found: {slug}", file=sys.stderr)

    # Primary-muscle corrections
    for slug, muscles in PRIMARY_MUSCLE_FIXES.items():
        if slug in by_id:
            by_id[slug]["primaryMuscles"] = muscles
        else:
            print(f"WARN: primary-muscle target not found: {slug}", file=sys.stderr)

    # Equipment corrections
    for slug, equipment in EQUIPMENT_FIXES.items():
        if slug in by_id:
            by_id[slug]["equipment"] = equipment
        else:
            print(f"WARN: equipment target not found: {slug}", file=sys.stderr)

    # New entries
    for entry in NEW_ENTRIES:
        if entry["id"] in by_id:
            print(f"WARN: new entry id already exists, overwriting: {entry['id']}", file=sys.stderr)
        by_id[entry["id"]] = entry

    # Return sorted by name for stable output
    return sorted(by_id.values(), key=lambda e: e["name"].lower())


def main() -> None:
    with JSON_PATH.open("r", encoding="utf-8") as f:
        seed = json.load(f)
    before_count = len(seed)

    updated = apply_coverage_pass(seed)
    after_count = len(updated)

    with JSON_PATH.open("w", encoding="utf-8") as f:
        json.dump(updated, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Before: {before_count} exercises.", file=sys.stderr)
    print(f"After:  {after_count} exercises (+{after_count - before_count} new).", file=sys.stderr)
    print(f"Applied {len(RENAMES)} renames, {len(ALIASES)} alias sets, "
          f"{len(PRIMARY_MUSCLE_FIXES)} muscle fixes, {len(EQUIPMENT_FIXES)} equipment fixes.",
          file=sys.stderr)


if __name__ == "__main__":
    main()
