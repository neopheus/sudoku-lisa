# Escales — implementation and validation

Scope: 25 scenery stops for Voyage and Libre only; existing puzzles, difficulty profiles, rewards and controls retained.

Decisions:
- Work in the existing dirty checkout and preserve prior edits; no commit requested.
- Bundle five original, reproducible synthesized compositions without external samples. Source and provenance accompany the audio; listening on a physical device remains necessary.
- Persist a stop ID per game plus a bounded shuffled free-play route. Consume a stop only after successful generation. Migration uses puzzle seed in Libre and stage in Voyage.
- Introductions are transient (never restored), skippable, bounded to 1.8 seconds. Reduced motion, paper mode and disabled decor bypass them. Lifecycle departure ends the introduction.

Validation results will be recorded here after execution.
