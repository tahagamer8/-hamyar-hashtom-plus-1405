import json
import unicodedata
import unittest
from pathlib import Path


def normalize(value: str) -> str:
    value = unicodedata.normalize("NFKC", value).casefold().replace("\u0640", "")
    return "".join(ch for ch in value if ch.isalnum())


class ArabicReasoningQualityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root = Path(__file__).resolve().parents[1]
        cls.payload = json.loads(
            (root / "assets/content/subjects/arabic.json").read_text(encoding="utf-8")
        )

    def test_all_ten_arabic_chapters_have_one_reasoning_question(self):
        self.assertEqual(len(self.payload["chapters"]), 10)
        for chapter in self.payload["chapters"]:
            with self.subTest(chapter=chapter["title"]):
                self.assertEqual(len(chapter.get("advancedQuestions", [])), 1)

    def test_reasoning_items_have_valid_distinct_options_and_answers(self):
        for chapter in self.payload["chapters"]:
            for question in chapter.get("advancedQuestions", []):
                with self.subTest(chapter=chapter["title"]):
                    options = question["options"]
                    self.assertEqual(len(options), 4)
                    self.assertEqual(len({normalize(option) for option in options}), 4)
                    answer = question["answer"]
                    self.assertIsInstance(answer, int)
                    self.assertGreaterEqual(answer, 0)
                    self.assertLess(answer, len(options))

    def test_selected_option_is_not_repeated_in_explanation(self):
        for chapter in self.payload["chapters"]:
            for question in chapter.get("advancedQuestions", []):
                selected = normalize(question["options"][question["answer"]])
                explanation = normalize(question["explanation"])
                with self.subTest(chapter=chapter["title"]):
                    self.assertTrue(selected)
                    self.assertNotIn(selected, explanation)

    def test_old_copy_answer_template_is_removed(self):
        old_question_template = "کدام استدلال درستی این انتخاب را بهتر توضیح می‌دهد"
        for chapter in self.payload["chapters"]:
            for question in chapter.get("advancedQuestions", []):
                with self.subTest(chapter=chapter["title"]):
                    self.assertNotIn(normalize(old_question_template), normalize(question["question"]))
                    self.assertNotIn(normalize("استدلال درست"), normalize(question["explanation"]))


if __name__ == "__main__":
    unittest.main()
