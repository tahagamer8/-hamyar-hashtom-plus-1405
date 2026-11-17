import json
import re
import unicodedata
import unittest
from pathlib import Path


def normalize(value: str) -> str:
    value = unicodedata.normalize("NFKC", value).casefold().replace("\u200c", "")
    return re.sub(r"[\W_]+", "", value, flags=re.UNICODE)


class MathReasoningContentTests(unittest.TestCase):
    def test_prime_37_reasoning_item_has_valid_distinct_explanation(self):
        root = Path(__file__).resolve().parents[1]
        payload = json.loads(
            (root / "assets/content/subjects/math.json").read_text(encoding="utf-8")
        )
        chapter = next(item for item in payload["chapters"] if item["title"] == "عددهای اول")
        self.assertEqual(len(chapter["advancedQuestions"]), 1)
        question = chapter["advancedQuestions"][0]
        self.assertEqual(len(question["options"]), 4)
        self.assertEqual(len(set(question["options"])), 4)
        self.assertIsInstance(question["answer"], int)
        self.assertGreaterEqual(question["answer"], 0)
        self.assertLess(question["answer"], len(question["options"]))
        selected = question["options"][question["answer"]]
        self.assertNotEqual(normalize(selected), normalize(question["explanation"]))
        self.assertIn("ریشهٔ دوم", selected)
        self.assertIn("۳۷ بر هیچ‌یک بخش‌پذیر نیست", question["explanation"])


if __name__ == "__main__":
    unittest.main()
