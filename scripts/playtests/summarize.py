#!/usr/bin/env python3
"""Aggregate voluntarily shared Lisa reports. Keep one latest export per tester.

Usage: python3 scripts/playtests/summarize.py /path/to/reports/*.json
No files are uploaded. Day offsets refer to UTC calendar days from observation start.
"""
import argparse
import json
from pathlib import Path

EVENTS = {'appActive', 'firstJourneySelected', 'gameStarted', 'gameResumed', 'firstMove',
          'gameCompleted', 'hintViewed', 'hintExplained', 'hintApplied', 'souvenirViewed'}


def read_report(path):
    if path.stat().st_size > 256_000:
        raise ValueError(f'{path.name}: report too large')
    data = path.read_bytes()
    report = json.loads(data)
    if report.get('schemaVersion') != 1 or report.get('windowDays') != 90:
        raise ValueError(f'{path.name}: unsupported report')
    for key in ('existingPlayer', 'recordingEnabled', 'recordingInterrupted'):
        if not isinstance(report.get(key), bool):
            raise ValueError(f'{path.name}: invalid {key}')
    if type(report.get('elapsedDays')) is not int or report['elapsedDays'] < 0:
        raise ValueError(f'{path.name}: invalid observation duration')
    days = report.get('days')
    if not isinstance(days, dict) or len(days) > 90:
        raise ValueError(f'{path.name}: invalid days')
    for day, counts in days.items():
        if not day.isdigit() or not 0 <= int(day) < 90 or not isinstance(counts, dict):
            raise ValueError(f'{path.name}: invalid daily counters')
        if any(event not in EVENTS or type(n) is not int or not 1 <= n <= 1_000_000
               for event, n in counts.items()):
            raise ValueError(f'{path.name}: invalid event')
    return report


def summarize(reports):
    result = {'reports': len(reports), 'cohorts': {}}
    for existing, label in [(False, 'new_players'), (True, 'existing_players')]:
        cohort = [r for r in reports if r['existingPlayer'] == existing]
        continuous = [r for r in cohort if r['recordingEnabled'] and not r['recordingInterrupted']]
        # Only completed UTC days enter a denominator, so today's partial day cannot imply churn.
        day_zero = [r for r in continuous if r['elapsedDays'] > 0 and r['days'].get('0', {}).get('appActive', 0) > 0]
        metrics = {'reports': len(cohort), 'continuous_reports': len(continuous),
                   'day_zero_eligible': len(day_zero),
                   'day_zero_started': sum(r['days'].get('0', {}).get('gameStarted', 0) > 0 for r in day_zero),
                   'day_zero_completed': sum(r['days'].get('0', {}).get('gameCompleted', 0) > 0 for r in day_zero)}
        for day in (1, 7, 30):
            eligible = [r for r in continuous if r['elapsedDays'] > day and r['days'].get('0', {}).get('appActive', 0) > 0]
            returned = sum(bool(r['days'].get(str(day), {})) for r in eligible)
            metrics[f'day_{day}'] = {'eligible': len(eligible), 'returned': returned,
                                    'rate': returned / len(eligible) if eligible else None}
        result['cohorts'][label] = metrics
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reports', nargs='+', type=Path)
    args = parser.parse_args()
    reports, seen = [], set()
    try:
        for path in args.reports:
            resolved = path.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            reports.append(read_report(path))
    except (ValueError, OSError) as error:
        parser.error(str(error))
    print(json.dumps(summarize(reports), indent=2))


if __name__ == '__main__':
    main()
