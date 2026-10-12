import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from summarize import summarize, read_report


class ReportTests(unittest.TestCase):
    def report(self, **changes):
        return dict({'schemaVersion': 1, 'windowDays': 90, 'elapsedDays': 8,
                     'existingPlayer': False, 'recordingEnabled': True, 'recordingInterrupted': False,
                     'days': {'0': {'appActive': 1, 'gameStarted': 1}, '7': {'gameCompleted': 1}}}, **changes)

    def test_partial_day_and_interrupted_recording_are_not_failures_to_return(self):
        reports = [self.report(), self.report(elapsedDays=7), self.report(recordingInterrupted=True)]
        cohort = summarize(reports)['cohorts']['new_players']
        self.assertEqual(cohort['day_7'], {'eligible': 1, 'returned': 1, 'rate': 1.0})
        self.assertIsNone(cohort['day_30']['rate'])

    def test_existing_players_do_not_inflate_new_player_retention(self):
        result = summarize([self.report(existingPlayer=True), self.report(days={'0': {'appActive': 1}})])
        self.assertEqual(result['cohorts']['new_players']['day_7']['rate'], 0)
        self.assertEqual(result['cohorts']['existing_players']['day_7']['rate'], 1)

    def test_identical_anonymous_reports_can_belong_to_different_people(self):
        with tempfile.TemporaryDirectory() as folder:
            files = [Path(folder) / name for name in ('alice.json', 'bob.json')]
            for file in files:
                file.write_text(json.dumps(self.report()))
            output = subprocess.check_output([sys.executable, str(Path(__file__).with_name('summarize.py')),
                                              str(files[0]), str(files[0]), str(files[1])], text=True)
            self.assertEqual(json.loads(output)['reports'], 2)

    def test_invalid_event_names_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'report.json'
            path.write_text(json.dumps(self.report(days={'0': {'arbitrary': 1}})))
            with self.assertRaises(ValueError):
                read_report(path)


if __name__ == '__main__':
    unittest.main()
