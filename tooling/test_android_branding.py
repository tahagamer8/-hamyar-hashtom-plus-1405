import tempfile
import unittest
from pathlib import Path

from PIL import Image

from tooling.configure_android_branding import (
    APP_ID,
    APP_LABEL,
    configure_android_branding,
)


class AndroidBrandingTests(unittest.TestCase):
    def test_release_identity_is_separate_but_display_name_is_fahmino(self):
        self.assertEqual(APP_LABEL, "فهمینو")
        self.assertEqual(APP_ID, "ir.fahmino.clone.fahminoseparate")
        self.assertNotEqual(APP_ID, "com.example.hamyar_hashtom_plus")

    def test_sets_separate_application_id_label_and_launcher_icons(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            image_dir = root / "assets" / "images"
            image_dir.mkdir(parents=True)
            Image.new("RGB", (64, 64), "#17215f").save(
                image_dir / "fahmino_app_icon.jpg"
            )

            app_dir = root / "android" / "app"
            manifest_dir = app_dir / "src" / "main"
            manifest_dir.mkdir(parents=True)
            (manifest_dir / "AndroidManifest.xml").write_text(
                '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
                '<application android:label="old" android:icon="@mipmap/old" />'
                '</manifest>',
                encoding="utf-8",
            )
            (app_dir / "build.gradle.kts").write_text(
                'android {\n    namespace = "com.example.old"\n'
                '    defaultConfig {\n        applicationId = "com.example.old"\n'
                '    }\n}\n',
                encoding="utf-8",
            )

            configure_android_branding(root)

            gradle = (app_dir / "build.gradle.kts").read_text(encoding="utf-8")
            manifest = (manifest_dir / "AndroidManifest.xml").read_text(encoding="utf-8")
            self.assertIn(APP_ID, gradle)
            self.assertIn(APP_LABEL, manifest)
            self.assertIn('@mipmap/ic_launcher', manifest)

            for density in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"):
                self.assertTrue(
                    (app_dir / "src" / "main" / "res" / f"mipmap-{density}" /
                     "ic_launcher.png").is_file()
                )
            self.assertTrue(
                (app_dir / "src" / "main" / "res" / "mipmap-anydpi-v26" /
                 "ic_launcher.xml").is_file()
            )


if __name__ == "__main__":
    unittest.main()
