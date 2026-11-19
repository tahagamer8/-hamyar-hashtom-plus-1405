import json
import unicodedata
import unittest
from pathlib import Path


def normalize(value: str) -> str:
    value = unicodedata.normalize("NFKC", value).casefold().replace("\\u0640", "")
    return "".join(ch for ch in value if ch.isalnum())


class ScienceReasoningQualityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root = Path(__file__).resolve().parents[1]
        cls.payload = json.loads(
            (root / "assets/content/subjects/science.json").read_text(encoding="utf-8")
        )

    def test_all_fifteen_science_chapters_have_one_reasoning_question(self):
        self.assertEqual(len(self.payload["chapters"]), 15)
        for chapter in self.payload["chapters"]:
            with self.subTest(chapter=chapter["title"]):
                questions = chapter.get("advancedQuestions", [])
                self.assertEqual(len(questions), 1)
                self.assertEqual(questions[0].get("questionType"), "reasoning")
                self.assertEqual(questions[0].get("difficulty"), "استدلالی")

    def test_options_and_answer_indices_are_valid(self):
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
                    self.assertTrue(question.get("explanation", "").strip())
                    self.assertEqual(question.get("source"), "تألیفی فهمینو")

    def test_selected_option_is_not_copied_into_explanation(self):
        for chapter in self.payload["chapters"]:
            for question in chapter.get("advancedQuestions", []):
                selected = normalize(question["options"][question["answer"]])
                explanation = normalize(question["explanation"])
                with self.subTest(chapter=chapter["title"]):
                    self.assertTrue(selected)
                    self.assertNotIn(selected, explanation)

    def test_old_copy_answer_template_is_removed(self):
        old_template = normalize("کدام استدلال درستی این انتخاب را بهتر توضیح می‌دهد")
        old_prefix = normalize("استدلال درست")
        for chapter in self.payload["chapters"]:
            for question in chapter.get("advancedQuestions", []):
                with self.subTest(chapter=chapter["title"]):
                    self.assertNotIn(old_template, normalize(question["question"]))
                    self.assertNotIn(old_prefix, normalize(question["explanation"]))


if __name__ == "__main__":
    unittest.main()
