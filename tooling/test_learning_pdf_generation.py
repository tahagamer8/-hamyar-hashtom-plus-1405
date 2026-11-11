import unittest

from tooling.generate_learning_pdfs import collect_questions, selected_chapters


def question(text, answer=0):
    return {
        "question": text,
        "options": ["الف", "ب", "پ", "ت"],
        "answer": answer,
        "explanation": "توضیح پاسخ",
    }


class PdfQuestionSelectionTests(unittest.TestCase):
    def setUp(self):
        self.subject = {
            "chapters": [
                {
                    "title": "فصل اول",
                    "examTerm": "first",
                    "questions": [question("پرسش عادی ۱")],
                    "advancedQuestions": [question("پرسش استدلالی ۱")],
                },
                {
                    "title": "فصل دوم",
                    "examTerm": "first",
                    "questions": [question("پرسش عادی ۲")],
                    "advancedQuestions": [question("پرسش استدلالی ۲")],
                },
                {
                    "title": "فصل سوم",
                    "examTerm": "second",
                    "questions": [question("پرسش عادی ۳")],
                    "advancedQuestions": [question("پرسش استدلالی ۳")],
                },
            ]
        }

    def test_term_filter_uses_explicit_curriculum_assignment(self):
        first = selected_chapters(self.subject, "first")
        second = selected_chapters(self.subject, "second")
        self.assertEqual([item["title"] for item in first], ["فصل اول", "فصل دوم"])
        self.assertEqual([item["title"] for item in second], ["فصل سوم"])
        self.assertEqual(len(collect_questions(self.subject, "first")), 4)
        self.assertEqual(len(collect_questions(self.subject, "second")), 2)

    def test_gifted_pdf_contains_only_reasoning_questions(self):
        rows = collect_questions(self.subject, "gifted")
        self.assertEqual(len(rows), 3)
        self.assertTrue(all("استدلالی" in item["question"] for _, item in rows))

    def test_full_bank_contains_regular_and_advanced_questions(self):
        rows = collect_questions(self.subject, "all")
        self.assertEqual(len(rows), 6)


if __name__ == "__main__":
    unittest.main()
