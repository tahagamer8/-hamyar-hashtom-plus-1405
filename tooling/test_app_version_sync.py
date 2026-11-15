import re
import unittest
from pathlib import Path


class AppVersionSyncTests(unittest.TestCase):
    def test_pubspec_and_in_app_version_match(self):
        root = Path(__file__).resolve().parents[1]
        pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
        app_constants = (root / "lib/core/constants/app_constants.dart").read_text(encoding="utf-8")

        pubspec_match = re.search(r"(?m)^version:\\s*([0-9]+\\.[0-9]+\\.[0-9]+)\\+(\\d+)\\s*$", pubspec)
        app_match = re.search(
            r"static const String appVersion = ['\"]([^'\"]+)['\"];",
            app_constants,
        )

        self.assertIsNotNone(pubspec_match, "pubspec.yaml must contain a semantic version and build number")
        self.assertIsNotNone(app_match, "AppConstants.appVersion must be declared")
        self.assertEqual(app_match.group(1), pubspec_match.group(1))


if __name__ == "__main__":
    unittest.main()
