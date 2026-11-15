import unittest
from pathlib import Path


class AppVersionSyncTests(unittest.TestCase):
    def test_pubspec_and_in_app_version_match(self):
        root = Path(__file__).resolve().parents[1]
        pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
        app_constants = (root / "lib/core/constants/app_constants.dart").read_text(encoding="utf-8")

        version_line = next(line for line in pubspec.splitlines() if line.startswith("version:"))
        package_version = version_line.split(":", 1)[1].strip().split("+", 1)
        app_line = next(line for line in app_constants.splitlines() if "String appVersion =" in line)
        app_version = app_line.split("'", 2)[1]

        self.assertEqual(len(package_version), 2, "pubspec version must include a build number")
        self.assertTrue(package_version[1].isdigit(), "pubspec build number must be numeric")
        self.assertEqual(app_version, package_version[0])


if __name__ == "__main__":
    unittest.main()
