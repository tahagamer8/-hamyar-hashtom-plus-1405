import json
import unittest
from pathlib import Path


class MathPrimeContentRegressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root = Path(__file__).resolve().parents[1]
        pack = json.loads((root / "assets/content/subjects/math.json").read_text(encoding="utf-8"))
        cls.chapter = next(item for item in pack["chapters"] if item["title"] == "عددهای اول")

    def test_37_question_includes_every_prime_divisor_through_sqrt(self):
        question = next(
            item for item in self.chapter["questions"]
            if "بررسی اول بودن ۳۷" in item["question"]
        )
        self.assertEqual(question["options"][question["answer"]], "۲، ۳ و ۵")
        self.assertIn("۲، ۳ و ۵", question["explanation"])
        self.assertNotEqual(question["options"][question["answer"]], "۲ و ۳")

    def test_reasoning_question_matches_its_selected_answer(self):
        question = next(
            item for item in self.chapter["advancedQuestions"]
            if "بررسی اول بودن ۳۷" in item["question"]
        )
        self.assertIn("پاسخ «۲، ۳ و ۵»", question["question"])
        self.assertIn("۲، ۳ و ۵", question["options"][question["answer"]])
        self.assertIn("۲، ۳ و ۵", question["explanation"])


if __name__ == "__main__":
    unittest.main()
