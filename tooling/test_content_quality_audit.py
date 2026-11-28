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


def normalize_toc_title(value):
    return "".join(
        character for character in value
        if not character.isspace() and ord(character) not in (0x200c, 0x200f)
    ).replace("ي", "ی").replace("ك", "ک")


class ContentQualityAuditTests(unittest.TestCase):


    def test_science_official_toc_is_recorded_without_claiming_physical_pdf_mapping(self):
        root = Path(__file__).resolve().parents[1]
        pack = json.loads(
            (root / "assets/content/subjects/science.json").read_text(encoding="utf-8")
        )
        source = pack["textbookSource"]
        parser = source["pdfParserVerification"]
        self.assertEqual(source["bookCode"], "806")
        self.assertEqual(source["schoolYear"], "1405-1406")
        self.assertEqual(parser["httpStatus"], 200)
        self.assertEqual(parser["contentType"], "application/pdf")
        self.assertEqual(parser["parsedPhysicalPages"], 24)
        self.assertEqual(parser["totalPhysicalPages"], 152)
        self.assertEqual(parser["tocEntryCount"], 15)
        self.assertEqual(parser["exactTitleMatchCount"], 11)
        self.assertEqual(parser["ocrAmbiguousTitleCount"], 4)
        self.assertEqual(parser["physicalPageMappingStatus"], "not_verified")

        expected = [
            ("مخلوط و جداسازی مواد", 1, "مخلوط و جداسازی مواد", "verified"),
            ("تغییرهای شیمیایی در خدمت زندگی", 9, "تغییرهای شیمایی در خدمت‌زندگی", "ocr_ambiguous"),
            ("از درون اتم چه خبر", 21, "از درون آنم چه خبر", "ocr_ambiguous"),
            ("تنظیم عصبی", 28, "تنظیم عصبی", "verified"),
            ("حس و حرکت", 35, "حس و حرکت", "verified"),
            ("تنظیم هورمونی", 47, "تنظیم هورمونی", "verified"),
            ("الفبای زیست‌فناوری", 55, "الفای زیست فناوری", "ocr_ambiguous"),
            ("تولیدمثل در جانداران", 65, "تولیدمثل در جانداران", "verified"),
            ("الکتریسیته", 76, "الکتریسییته", "ocr_ambiguous"),
            ("مغناطیس", 89, "مغناطیس", "verified"),
            ("کانی‌ها", 97, "کانی ها", "verified"),
            ("سنگ‌ها", 104, "سنگ ها", "verified"),
            ("هوازدگی", 114, "هوازدگی", "verified"),
            ("نور و ویژگی‌های آن", 122, "نور و ویژگی‌های آن", "verified"),
            ("شکست نور", 136, "شکست نور", "verified"),
        ]
        self.assertEqual(len(pack["chapters"]), len(expected))
        for index, (title, printed_page, toc_entry, title_status) in enumerate(expected, 1):
            chapter = pack["chapters"][index - 1]
            mapping = chapter["sourceMapping"]
            self.assertEqual(chapter["title"], title)
            self.assertEqual(chapter["pageStart"], printed_page)
            self.assertEqual(mapping["officialTocEntry"], toc_entry)
            self.assertEqual(mapping["printedPageStart"], printed_page)
            self.assertEqual(mapping["titleMatchStatus"], title_status)
            self.assertEqual(mapping["physicalPdfPageMappingStatus"], "not_verified")
            if title_status == "verified":
                self.assertEqual(normalize_toc_title(title), normalize_toc_title(toc_entry))
            else:
                self.assertEqual(
                    mapping["status"],
                    "printed_toc_entry_found_title_ocr_ambiguous_physical_pdf_unverified",
                )
            result = audit_chapter("science", pack["title"], pack, chapter, index)
            self.assertTrue(result["printedTocEntryFound"])
            self.assertFalse(result["sourceMapped"])
            self.assertIsNone(result["pdfPhysicalPageStart"])

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

    def test_science_chemical_change_chapter_has_original_lesson_and_independent_practice(self):
        root = Path(__file__).resolve().parents[1]
        pack = json.loads(
            (root / "assets/content/subjects/science.json").read_text(encoding="utf-8")
        )
        chapter = pack["chapters"][1]
        result = audit_chapter("science", pack["title"], pack, chapter, 2)

        self.assertEqual(chapter["title"], "تغییرهای شیمیایی در خدمت زندگی")
        self.assertGreaterEqual(len(chapter["lessonContent"]), 350)
        self.assertEqual(len(chapter["questions"]), 5)
        self.assertEqual(len(chapter["advancedQuestions"]), 3)
        self.assertEqual(len(chapter["workedExamples"]), 2)
        self.assertEqual(len(chapter["chapterExam"]), 8)
        self.assertEqual(
            result["independentQuestionFormats"],
            ["multiple_choice", "short_answer", "true_false"],
        )
        self.assertEqual(result["reusedBasePromptAdvancedQuestionCount"], 0)
        self.assertEqual(result["reusedPointRestatementCount"], 0)
        self.assertEqual(result["genericLearningGoalCount"], 0)
        self.assertEqual(result["genericPointExplanationCount"], 0)
        self.assertEqual(result["genericFinalCheckStepCount"], 0)
        self.assertTrue(result["pedagogicalComplete"])
        self.assertFalse(result["sourceMapped"])
        self.assertEqual(result["status"], "نیازمند منبع")
        self.assertTrue(all(len(step) >= 80 for step in chapter["solutionSteps"]))

    def test_science_atomic_structure_chapter_has_independent_original_learning_pack(self):
        root = Path(__file__).resolve().parents[1]
        pack = json.loads(
            (root / "assets/content/subjects/science.json").read_text(encoding="utf-8")
        )
        chapter = pack["chapters"][2]
        result = audit_chapter("science", pack["title"], pack, chapter, 3)

        self.assertEqual(chapter["title"], "از درون اتم چه خبر")
        self.assertGreaterEqual(len(chapter["lessonContent"]), 350)
        self.assertEqual(len(chapter["questions"]), 5)
        self.assertEqual(len(chapter["advancedQuestions"]), 3)
        self.assertEqual(len(chapter["workedExamples"]), 2)
        self.assertEqual(len(chapter["chapterExam"]), 8)
        self.assertTrue(result["pedagogicalComplete"])
        self.assertFalse(result["sourceMapped"])
        self.assertEqual(result["status"], "نیازمند منبع")
        self.assertEqual(
            result["independentQuestionFormats"],
            ["fill_blank", "multiple_choice", "short_answer", "true_false"],
        )
        self.assertEqual(result["reusedBasePromptAdvancedQuestionCount"], 0)
        self.assertEqual(result["reusedPointRestatementCount"], 0)
        self.assertEqual(result["genericLearningGoalCount"], 0)
        self.assertEqual(result["genericPointExplanationCount"], 0)
        self.assertEqual(result["genericFinalCheckStepCount"], 0)
        self.assertTrue(all(len(step) >= 80 for step in chapter["solutionSteps"]))

        verification = chapter["sourceMapping"]["chapterContentVerification"]
        self.assertEqual(verification["httpStatus"], 200)
        self.assertEqual(verification["parsedPhysicalPages"], 60)
        self.assertEqual(verification["totalPhysicalPages"], 152)
        self.assertEqual(verification["reportedPrintedPageStart"], 21)
        self.assertEqual(verification["reportedPrintedPageEnd"], 27)
        self.assertEqual(
            verification["physicalPdfPageMappingStatus"], "not_verified"
        )
        self.assertEqual(
            verification["evidenceStatus"],
            "parser_query_extracted_not_manually_visually_confirmed",
        )

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
