import json
import tempfile
import unittest
from pathlib import Path

from tooling.audit_chapter_coverage import (
    SUBJECT_IDS,
    audit_chapter,
    build_report,
    normalize_question,
)


def complete_fixture():
    return {
        "title": "فصل آزمایشی",
        "pageStart": 1,
        "pageEnd": 4,
        "sourceLesson": "درس آزمایشی",
        "summary": "خلاصهٔ آموزشی " * 12,
        "points": ["نکتهٔ یک", "نکتهٔ دو", "نکتهٔ سه"],
        "example": "مثال حل‌شدهٔ نمونه با توضیح کافی",
        "solutionSteps": ["گام اول", "گام دوم", "گام سوم"],
        "commonMistakes": ["اشتباه یک", "اشتباه دو"],
        "questions": [
            {
                "questionType": "multiple_choice",
                "question": "پرسش چهارگزینه‌ای",
                "options": ["الف", "ب"],
                "answer": 0,
                "explanation": "توضیح پاسخ چهارگزینه‌ای به اندازهٔ کافی روشن است.",
            },
            {
                "questionType": "short_answer",
                "question": "پرسش پاسخ‌کوتاه",
                "answer": "پاسخ",
                "explanation": "توضیح پاسخ‌کوتاه به اندازهٔ کافی روشن است.",
            },
            {
                "questionType": "essay",
                "question": "پرسش تشریحی",
                "answer": "پاسخ",
                "explanation": "توضیح پاسخ تشریحی به اندازهٔ کافی روشن است.",
            },
            {
                "questionType": "true_false",
                "question": "پرسش درست یا نادرست",
                "answer": "درست",
                "explanation": "توضیح پاسخ درست یا نادرست به اندازهٔ کافی روشن است.",
            },
            {
                "questionType": "fill_blank",
                "question": "پرسش جای خالی",
                "answer": "واژه",
                "explanation": "توضیح پاسخ جای خالی به اندازهٔ کافی روشن است.",
            },
        ],
        "chapterTest": [{"question": "آزمون مستقل"}],
        "answerKey": [{"answer": "پاسخ"}],
        "solvedExampleVerified": True,
        "officialMappingVerified": True,
        "humanReviewStatus": "approved",
    }


class ChapterCoverageAuditTests(unittest.TestCase):
    def test_complete_requires_all_content_source_and_review_gates(self):
        result = audit_chapter("sample", 1, complete_fixture())
        self.assertEqual(result["status"], "complete")
        self.assertEqual(result["gaps"], [])

    def test_missing_page_range_is_needs_source(self):
        chapter = complete_fixture()
        chapter.pop("pageEnd")
        result = audit_chapter("sample", 1, chapter)
        self.assertEqual(result["status"], "needs_source")
        self.assertIn("missing_official_reference_fields", result["gaps"])

    def test_referenced_chapter_without_chapter_test_is_incomplete(self):
        chapter = complete_fixture()
        chapter.pop("chapterTest")
        result = audit_chapter("sample", 1, chapter)
        self.assertEqual(result["status"], "incomplete")
        self.assertIn("chapter_test_missing", result["gaps"])

    def test_multiple_choice_only_does_not_count_as_diverse(self):
        chapter = complete_fixture()
        chapter["questions"] = [
            {
                "question": f"پرسش {index}",
                "options": ["الف", "ب"],
                "answer": 0,
                "explanation": "توضیح کافی برای پاسخ این پرسش",
            }
            for index in range(5)
        ]
        result = audit_chapter("sample", 1, chapter)
        self.assertIn("question_types_not_diverse", result["gaps"])

    def test_aggregate_question_type_counts_count_question_instances(self):
        with tempfile.TemporaryDirectory() as directory:
            subjects_dir = Path(directory)
            for subject_id in SUBJECT_IDS:
                payload = {"title": subject_id, "chapters": []}
                if subject_id == "math":
                    chapter = complete_fixture()
                    chapter["questions"] = [
                        {
                            "questionType": "multiple_choice",
                            "question": "پرسش چهارگزینه‌ای یک",
                            "options": ["الف", "ب"],
                            "answer": 0,
                            "explanation": "توضیح کافی برای پرسش چهارگزینه‌ای اول.",
                        },
                        {
                            "questionType": "multiple_choice",
                            "question": "پرسش چهارگزینه‌ای دو",
                            "options": ["الف", "ب"],
                            "answer": 1,
                            "explanation": "توضیح کافی برای پرسش چهارگزینه‌ای دوم.",
                        },
                        {
                            "questionType": "essay",
                            "question": "پرسش تشریحی",
                            "answer": "پاسخ نمونه",
                            "explanation": "توضیح کافی برای پاسخ تشریحی نمونه.",
                        },
                    ]
                    payload["chapters"] = [chapter]
                (subjects_dir / f"{subject_id}.json").write_text(
                    json.dumps(payload, ensure_ascii=False), encoding="utf-8"
                )

            report = build_report(subjects_dir)
            self.assertEqual(report["totals"]["questionCount"], 3)
            self.assertEqual(
                report["totals"]["questionTypeCounts"],
                {"essay": 1, "multiple_choice": 2},
            )
            self.assertEqual(
                report["totals"]["chapterTypePresenceCounts"],
                {"essay": 1, "multiple_choice": 1},
            )
            math = next(subject for subject in report["subjects"] if subject["id"] == "math")
            self.assertEqual(math["questionTypeCounts"], {"essay": 1, "multiple_choice": 2})

    def test_question_normalization_ignores_spacing_and_punctuation(self):
        self.assertEqual(
            normalize_question("پرسشِ نمونه، با فاصله"),
            normalize_question("پرسش نمونه با فاصله"),
        )


if __name__ == "__main__":
    unittest.main()
