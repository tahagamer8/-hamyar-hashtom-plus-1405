#!/usr/bin/env python3
"""Set a stable Android application ID and release signing configuration."""
from pathlib import Path
import re

gradle = Path("android/app/build.gradle.kts")
if not gradle.is_file():
    raise SystemExit("Expected android/app/build.gradle.kts; Android project generation failed.")

source = gradle.read_text(encoding="utf-8")
application_id = "ir.fahmino.hamyar_hashtom_plus"

source, ns_count = re.subn(r'namespace\s*=\s*"[^"]+"', f'namespace = "{application_id}"', source, count=1)
source, app_count = re.subn(r'applicationId\s*=\s*"[^"]+"', f'applicationId = "{application_id}"', source, count=1)
if ns_count != 1 or app_count != 1:
    raise SystemExit("Could not safely set Android namespace/applicationId in Gradle file.")

if "import java.util.Properties" not in source:
    source = "import java.util.Properties\nimport java.io.FileInputStream\n\n" + source

marker = "android {"
if marker not in source:
    raise SystemExit("Could not find android { block in Gradle file.")

signing = """
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

"""
if "val keystoreProperties = Properties()" not in source:
    source = source.replace(marker, signing + marker, 1)

signing_configs = """
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

"""
if 'create("release")' not in source:
    source = source.replace(marker, marker + signing_configs, 1)

release_debug = 'signingConfig = signingConfigs.getByName("debug")'
release_custom = 'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")'
if release_debug in source:
    source = source.replace(release_debug, release_custom, 1)
elif 'signingConfig = signingConfigs.getByName("release")' not in source:
    build_types = re.search(r'buildTypes\s*{', source)
    if not build_types:
        raise SystemExit("Could not locate buildTypes block to configure release signing.")
    insertion = """
        getByName("release") {
            signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
"""
    source = source[:build_types.end()] + insertion + source[build_types.end():]

gradle.write_text(source, encoding="utf-8")
print(f"Configured Android application ID: {application_id}")
