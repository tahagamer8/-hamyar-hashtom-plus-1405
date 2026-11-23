import json
import unittest
from pathlib import Path

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
        "sourceMapping": {
            "status": "verified",
            "pdfPhysicalPageStart": 12,
            "pdfPhysicalPageEnd": 22,
            "verifiedAt": "2026-11-20",
            "method": "manual visual comparison with the official PDF contents and printed page range",
        },
        "questions": [valid_mcq(i) for i in range(4)] + [{
            "question": "نتیجه را با یک جمله توضیح بده.",
            "questionType": "short_answer",
            "answer": "نتیجه با داده‌ها سازگار است.",
            "explanation": "در پاسخ تشریحی باید رابطهٔ داده‌ها و نتیجه بیان شود.",
        }, {
            "question": "این گزاره درست است یا نادرست؟",
            "questionType": "true_false",
            "answer": "درست",
            "explanation": "گزاره با تعریف ارائه‌شده در صورت مسئله سازگار است.",
        }],
        "chapterExam": [valid_mcq(i + 10) for i in range(5)],
    }
    pack = {
        "textbookEdition": "چاپ آزمایشی ۱۴۰۵",
        "textbookSourceFile": "sample.pdf",
    }
    return pack, chapter


class ContentQualityAuditTests(unittest.TestCase):

    def test_science_mixtures_chapter_has_original_lesson_and_independent_formats(self):
        root = Path(__file__).resolve().parents[1]
        pack = json.loads(
            (root / "assets/content/subjects/science.json").read_text(encoding="utf-8")
        )
        chapter = pack["chapters"][0]
        result = audit_chapter("science", pack["title"], pack, chapter, 1)

        self.assertEqual(chapter["title"], "مخلوط و جداسازی مواد")
        self.assertTrue(result["pedagogicalComplete"])
        self.assertFalse(result["sourceMapped"])
        self.assertEqual(result["status"], "نیازمند منبع")
        self.assertEqual(result["baseQuestionCount"], 5)
        self.assertEqual(result["advancedQuestionCount"], 3)
        self.assertEqual(
            result["independentQuestionFormats"],
            ["multiple_choice", "short_answer", "true_false"],
        )
        self.assertEqual(result["reusedBasePromptAdvancedQuestionCount"], 0)
        self.assertEqual(result["reusedPointRestatementCount"], 0)
        self.assertEqual(result["genericLearningGoalCount"], 0)
        self.assertEqual(result["genericPointExplanationCount"], 0)
        self.assertEqual(result["genericFinalCheckStepCount"], 0)
        self.assertTrue(result["hasChapterExam"])
        self.assertEqual(result["chapterExamQuestionCount"], 8)

    def test_complete_requires_all_pedagogical_and_source_gates(self):
        pack, chapter = complete_fixture()
        result = audit_chapter("sample", "نمونه", pack, chapter, 1)
        self.assertEqual(result["status"], "کامل")
        self.assertTrue(result["sourceMapped"])
        self.assertTrue(result["hasDedicatedLesson"])
        self.assertTrue(result["hasChapterExam"])
        self.assertEqual(result["questionFormats"], ["multiple_choice", "short_answer", "true_false"])
        self.assertEqual(result["gaps"], [])

    def test_four_base_practice_questions_are_not_enough_even_with_three_formats(self):
        pack, chapter = complete_fixture()
        chapter["questions"] = chapter["questions"][:2] + chapter["questions"][-2:]
        result = audit_chapter("sample", "نمونه", pack, chapter, 1)
        self.assertEqual(result["baseQuestionCount"], 4)
        self.assertEqual(result["questionFormats"], ["multiple_choice", "short_answer", "true_false"])
        self.assertEqual(result["status"], "ناقص")
        self.assertIn("کمتر از پنج پرسش پایه ثبت شده است", result["gaps"])

    def test_advanced_wrappers_reusing_base_prompts_and_points_do_not_count_as_independent_formats(self):
        pack, chapter = complete_fixture()
        chapter["questions"] = [valid_mcq(i) for i in range(5)]
        base = chapter["questions"]
        point = "تقسیم بر صفر تعریف نشده است."
        chapter["points"] = [point, "نکتهٔ دوم", "نکتهٔ سوم"]
        chapter["advancedQuestions"] = [
            {
                "question": "بدون دیدن گزینه‌ها، به این پرسش پاسخ کوتاه بده: " + base[0]["question"],
                "questionType": "short_answer",
                "answer": "پاسخ پایه",
                "explanation": "این پاسخ همان پرسش پایه را تکرار می‌کند.",
            },
            {
                "question": "پرسش «" + base[1]["question"] + "» را با بیان خودت پاسخ بده و یک دلیل کوتاه بنویس.",
                "questionType": "short_answer",
                "answer": "پاسخ بازنویسی‌شده",
                "explanation": "این صورت نیز همان پرسش پایه را بازنویسی می‌کند.",
            },
            {
                "question": "درست یا نادرست: " + point,
                "questionType": "true_false",
                "answer": "درست",
                "explanation": "این گزاره عین یکی از نکته‌های فهرست‌شده است.",
            },
        ]
        result = audit_chapter("sample", "نمونه", pack, chapter, 1)
        self.assertEqual(
            result["questionFormats"],
            ["multiple_choice", "short_answer", "true_false"],
        )
        self.assertEqual(result["independentQuestionFormats"], ["multiple_choice"])
        self.assertEqual(result["reusedBasePromptAdvancedQuestionCount"], 2)
        self.assertEqual(result["reusedPointRestatementCount"], 1)
        self.assertEqual(result["nonIndependentAdvancedQuestionCount"], 3)
        self.assertEqual(result["status"], "ناقص")
        self.assertTrue(
            any("قالب‌های مستقل تمرین‌ها" in gap for gap in result["gaps"])
        )

    def test_two_question_formats_are_not_enough_for_a_complete_chapter(self):
        pack, chapter = complete_fixture()
        chapter["questions"] = [
            question for question in chapter["questions"]
            if question.get("questionType") != "true_false"
        ]
        result = audit_chapter("sample", "نمونه", pack, chapter, 1)
        self.assertEqual(result["status"], "ناقص")
        self.assertEqual(result["questionFormats"], ["multiple_choice", "short_answer"])
        self.assertIn("قالب‌های مستقل تمرین‌ها متنوع نیست؛ حداقل سه قالب مستقل لازم است", result["gaps"])

    def test_missing_official_source_is_not_misreported_as_complete(self):
        pack, chapter = complete_fixture()
        pack.pop("textbookSourceFile")
        pack.pop("textbookEdition")
        result = audit_chapter("sample", "نمونه", pack, chapter, 1)
        self.assertEqual(result["status"], "نیازمند منبع")
        self.assertFalse(result["sourceMapped"])

    def test_printed_pages_and_pdf_url_do_not_prove_physical_pdf_mapping(self):
        pack, chapter = complete_fixture()
        chapter.pop("sourceMapping")
        result = audit_chapter("sample", "نمونه", pack, chapter, 1)
        self.assertEqual(result["status"], "نیازمند منبع")
        self.assertFalse(result["sourceMapped"])
        self.assertTrue(any("صفحات فیزیکی PDF" in gap for gap in result["gaps"]))

    def test_physical_pdf_mapping_requires_valid_range_and_review_metadata(self):
        pack, chapter = complete_fixture()
        chapter["sourceMapping"]["pdfPhysicalPageStart"] = 0
        result = audit_chapter("sample", "نمونه", pack, chapter, 1)
        self.assertEqual(result["status"], "نیازمند منبع")
        self.assertFalse(result["sourceMapped"])

    def test_pedagogical_gaps_remain_incomplete_even_when_source_is_unverified(self):
        pack, chapter = complete_fixture()
        chapter.pop("sourceMapping")
        chapter["lessonContent"] = "درسنامهٔ کوتاه"
        result = audit_chapter("sample", "نمونه", pack, chapter, 1)
        self.assertEqual(result["status"], "ناقص")
        self.assertFalse(result["sourceMapped"])
        self.assertIn("درسنامهٔ مستقل و کافی ثبت نشده (خلاصه جای درسنامه نیست)", result["gaps"])

    def test_repeated_learning_goal_and_point_templates_are_not_complete_content(self):
        pack, chapter = complete_fixture()
        chapter["lessonContent"] += (
            "\\nدر پایان این بخش باید بتوانی مفهوم اصلی را با زبان خودت توضیح بدهی، "
            "نکته‌های مهم را تشخیص بدهی و آن‌ها را در پرسش و مثال به کار ببری."
            "\\nبرای فهم این نکته، آن را به عبارت‌های کلیدی تقسیم کن و ارتباطش را با موضوع "
            "«فصل آزمایشی» توضیح بده. سپس یک نمونهٔ تازه از خودت بساز."
        )
        result = audit_chapter("sample", "نمونه", pack, chapter, 1)
        self.assertEqual(result["genericLearningGoalCount"], 1)
        self.assertEqual(result["genericPointExplanationCount"], 1)
        self.assertEqual(result["status"], "ناقص")

    def test_generic_final_check_step_is_not_counted_as_a_real_solution_step(self):
        pack, chapter = complete_fixture()
        chapter["solutionSteps"].append(
            "بررسی نهایی: پاسخ خود را با خواستهٔ پرسش و نکتهٔ «فصل آزمایشی» "
            "مقایسه کن و دلیل درستی یا نادرستی آن را با یک جمله توضیح بده."
        )
        result = audit_chapter("sample", "نمونه", pack, chapter, 1)
        self.assertEqual(result["genericFinalCheckStepCount"], 1)
        self.assertEqual(result["status"], "ناقص")

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
