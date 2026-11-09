import unittest

from tooling.audit_content_quality import audit_chapter, question_is_valid


def valid_mcq(number):
    return {
        "question": f"پرسش {number} چیست؟",
        "options": ["الف", "ب", "ج", "د"],
        "answer": 0,
        "explanation": "زیرا پاسخ با تعریف و داده‌های مسئله سازگار است.",
    }


def complete_fixture():
    chapter = {
        "title": "فصل آزمایشی",
        "lessonContent": "درسنامهٔ مستقل. " * 30,
        "summary": "خلاصهٔ فصل",
        "points": ["مفهوم اول", "مفهوم دوم", "مفهوم سوم"],
        "example": "یک مثال آموزشی با صورت مسئله، داده‌های کافی، روش انتخاب رابطه، حل مرحله‌به‌مرحله و بررسی نتیجه برای یادگیری مستقل.",
        "solutionSteps": ["گام نخست را با دقت از روی داده‌های مسئله مشخص می‌کنیم.", "رابطهٔ مناسب را با توجه به مفهوم فصل می‌نویسیم.", "نتیجه را با جای‌گذاری دوباره و بررسی واحدها کنترل می‌کنیم."],
        "commonMistakes": ["اشتباه اول", "اشتباه دوم"],
        "pageStart": 10,
        "pageEnd": 20,
        "sourceLesson": "فصل آزمایشی",
        "questions": [valid_mcq(i) for i in range(4)] + [{
            "question": "نتیجه را با یک جمله توضیح بده.",
            "questionType": "short_answer",
            "answer": "نتیجه با داده‌ها سازگار است.",
            "explanation": "در پاسخ تشریحی باید رابطهٔ داده‌ها و نتیجه بیان شود.",
        }],
        "chapterExam": [valid_mcq(i + 10) for i in range(5)],
    }
    pack = {
        "textbookEdition": "چاپ آزمایشی ۱۴۰۵",
        "textbookSourceFile": "sample.pdf",
    }
    return pack, chapter


class ContentQualityAuditTests(unittest.TestCase):
    def test_complete_requires_all_pedagogical_and_source_gates(self):
        pack, chapter = complete_fixture()
        result = audit_chapter("sample", "نمونه", pack, chapter, 1)
        self.assertEqual(result["status"], "کامل")
        self.assertTrue(result["sourceMapped"])
        self.assertTrue(result["hasDedicatedLesson"])
        self.assertTrue(result["hasChapterExam"])
        self.assertEqual(result["questionFormats"], ["multiple_choice", "short_answer"])
        self.assertEqual(result["gaps"], [])

    def test_missing_official_source_is_not_misreported_as_complete(self):
        pack, chapter = complete_fixture()
        pack.pop("textbookSourceFile")
        pack.pop("textbookEdition")
        result = audit_chapter("sample", "نمونه", pack, chapter, 1)
        self.assertEqual(result["status"], "نیازمند منبع")
        self.assertFalse(result["sourceMapped"])

    def test_generic_reasoning_wrapper_and_tautology_are_flagged(self):
        pack, chapter = complete_fixture()
        chapter["advancedQuestions"] = [{
            "question": "برای پرسش «حاصل چیست؟» پاسخ «۴» انتخاب شده است. کدام استدلال، درستی این انتخاب را بهتر توضیح می‌دهد؟",
            "options": ["۴", "۳", "۲", "۱"],
            "answer": 0,
            "explanation": "استدلال درست: ۴",
        }]
        result = audit_chapter("sample", "نمونه", pack, chapter, 1)
        self.assertEqual(result["genericReasoningQuestionCount"], 1)
        self.assertEqual(result["tautologicalReasoningExplanationCount"], 1)
        self.assertEqual(result["status"], "ناقص")

    def test_short_example_is_a_review_flag(self):
        pack, chapter = complete_fixture()
        chapter["example"] = "مثال کوتاه"
        result = audit_chapter("sample", "نمونه", pack, chapter, 1)
        self.assertIn("مثال کمتر از ۸۰ نویسه است؛ نیازمند بازبینی انسانی", result["gaps"])
        self.assertEqual(result["status"], "ناقص")

    def test_question_validation_rejects_out_of_range_answer(self):
        question = valid_mcq(1)
        question["answer"] = 4
        self.assertFalse(question_is_valid(question))


if __name__ == "__main__":
    unittest.main()
