#!/usr/bin/env python3
"""Conservative chapter-level quality audit for Fahmino's grade-eight content packs.

This audit checks structure and traceability; it cannot certify factual correctness.
A chapter is never marked complete merely because it has a title or MCQs.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

EXPECTED_SUBJECTS = (
    "arabic", "art", "english", "english_workbook", "math", "persian",
    "quran", "religion", "science", "social", "thinking", "work", "writing",
)
GENERIC_REASONING = re.compile(
    r"^برای پرسش «.+» پاسخ «.+» انتخاب شده است\. "
    r"کدام استدلال، درستی این انتخاب را بهتر توضیح می‌دهد؟$"
)
NON_MCQ_TYPES = {
    "short_answer", "fill_blank", "true_false", "matching", "constructed_response",
}


def clean_text(value: Any) -> str:
    return value.strip() if isinstance(value, str) else ""


def question_format(question: dict[str, Any]) -> str:
    options = question.get("options")
    if isinstance(options, list) and len(options) >= 2:
        return "multiple_choice"
    kind = clean_text(question.get("questionType"))
    return kind or "untyped"


def question_is_valid(question: dict[str, Any]) -> bool:
    prompt = clean_text(question.get("question"))
    explanation = clean_text(question.get("explanation"))
    if not prompt or not explanation:
        return False
    options = question.get("options")
    answer = question.get("answer")
    if isinstance(options, list):
        return (
            len(options) >= 2
            and all(clean_text(option) for option in options)
            and isinstance(answer, int)
            and not isinstance(answer, bool)
            and 0 <= answer < len(options)
        )
    return (
        clean_text(question.get("questionType")) in NON_MCQ_TYPES
        and isinstance(answer, str)
        and bool(answer.strip())
    )


def source_is_mapped(pack: dict[str, Any], chapter: dict[str, Any]) -> bool:
    source = pack.get("textbookSource")
    source = source if isinstance(source, dict) else {}
    has_pdf_reference = bool(
        clean_text(source.get("pdfUrl")) or clean_text(pack.get("textbookSourceFile"))
    )
    has_edition = bool(
        clean_text(pack.get("textbookEdition")) or clean_text(source.get("schoolYear"))
    )
    has_page_range = (
        isinstance(chapter.get("pageStart"), int)
        and not isinstance(chapter.get("pageStart"), bool)
        and isinstance(chapter.get("pageEnd"), int)
        and not isinstance(chapter.get("pageEnd"), bool)
        and chapter["pageStart"] <= chapter["pageEnd"]
    )
    nested_lessons = chapter.get("textbookLessons")
    has_lesson_reference = bool(clean_text(chapter.get("sourceLesson"))) or (
        isinstance(nested_lessons, list) and len(nested_lessons) > 0
    )
    return has_pdf_reference and has_edition and has_page_range and has_lesson_reference


def exam_questions(chapter: dict[str, Any]) -> list[dict[str, Any]]:
    value = chapter.get("chapterExam", chapter.get("exam"))
    if isinstance(value, list):
        return [item for item in value if isinstance(item, dict)]
    if isinstance(value, dict) and isinstance(value.get("questions"), list):
        return [item for item in value["questions"] if isinstance(item, dict)]
    return []


def audit_chapter(
    subject_id: str, subject_title: str, pack: dict[str, Any], chapter: dict[str, Any], index: int
) -> dict[str, Any]:
    base_questions = chapter.get("questions")
    base_questions = base_questions if isinstance(base_questions, list) else []
    advanced_questions = chapter.get("advancedQuestions")
    advanced_questions = advanced_questions if isinstance(advanced_questions, list) else []
    questions = [
        item for item in [*base_questions, *advanced_questions] if isinstance(item, dict)
    ]
    formats = sorted({question_format(question) for question in questions})
    valid_count = sum(question_is_valid(question) for question in questions)
    explained_count = sum(bool(clean_text(question.get("explanation"))) for question in questions)

    lesson_text = next(
        (
            clean_text(chapter.get(key))
            for key in ("lessonContent", "lesson", "teachingNotes", "lessonText")
            if clean_text(chapter.get(key))
        ),
        "",
    )
    has_lesson = len(lesson_text) >= 350
    points = chapter.get("points")
    points = points if isinstance(points, list) else []
    mistakes = chapter.get("commonMistakes")
    mistakes = mistakes if isinstance(mistakes, list) else []
    example = clean_text(chapter.get("example"))
    steps = chapter.get("solutionSteps")
    steps = steps if isinstance(steps, list) else []
    step_text = " ".join(clean_text(step) for step in steps).strip()
    exam = exam_questions(chapter)
    has_exam = len(exam) >= 5 and all(question_is_valid(question) for question in exam)
    mapped_source = source_is_mapped(pack, chapter)
    generic_count = sum(
        bool(GENERIC_REASONING.fullmatch(clean_text(question.get("question"))))
        for question in advanced_questions
    )
    tautological_count = sum(
        bool(
            isinstance(question.get("options"), list)
            and isinstance(question.get("answer"), int)
            and 0 <= question["answer"] < len(question["options"])
            and clean_text(question.get("explanation"))
            == "استدلال درست: " + clean_text(question["options"][question["answer"]])
        )
        for question in advanced_questions
    )
    all_multiple_choice = bool(questions) and all(
        isinstance(question.get("options"), list) and len(question["options"]) >= 2
        for question in questions
    )
    all_valid = bool(questions) and valid_count == len(questions)
    all_explained = bool(questions) and explained_count == len(questions)

    gaps: list[str] = []
    if not has_lesson:
        gaps.append("درسنامهٔ مستقل و کافی ثبت نشده (خلاصه جای درسنامه نیست)")
    if len(points) < 3:
        gaps.append("توضیح مفاهیم/نکته‌ها کمتر از حداقل ممیزی است")
    if len(example) < 80:
        gaps.append("مثال کمتر از ۸۰ نویسه است؛ نیازمند بازبینی انسانی")
    if len(steps) < 3 or len(step_text) < 80:
        gaps.append("مثال حل‌شده یا مراحل گام‌به‌گام کافی ثبت نشده")
    if len(base_questions) < 5:
        gaps.append("تمرین‌های پایه کمتر از ۵ پرسش است")
    if all_multiple_choice:
        gaps.append("همهٔ پرسش‌ها چهارگزینه‌ای‌اند؛ تنوع قالب وجود ندارد")
    if not has_exam:
        gaps.append("آزمون مستقل فصل با حداقل ۵ پرسش و پاسخ معتبر ثبت نشده")
    if not all_valid:
        gaps.append("حداقل یک سؤال کلید پاسخ/ساختار معتبر ندارد")
    if not all_explained:
        gaps.append("حداقل یک سؤال پاسخ تشریحی ندارد")
    if generic_count:
        gaps.append("پرسش استدلالی از قالب بازنویسی سؤال پایه استفاده می‌کند")
    if tautological_count:
        gaps.append("توضیح پرسش استدلالی عین گزینهٔ درست را تکرار می‌کند")
    if len(mistakes) < 2:
        gaps.append("کمتر از دو نکتهٔ اشتباه رایج ثبت شده")
    if not mapped_source:
        gaps.append("منبع رسمی/نسخه یا نگاشت عنوان و بازهٔ صفحه کامل نیست")

    complete = (
        has_lesson
        and len(points) >= 3
        and len(example) >= 80
        and len(steps) >= 3
        and len(step_text) >= 80
        and len(base_questions) >= 5
        and len(formats) >= 2
        and has_exam
        and all_valid
        and all_explained
        and len(mistakes) >= 2
        and mapped_source
        and generic_count == 0
        and tautological_count == 0
    )
    status = "کامل" if complete else ("نیازمند منبع" if not mapped_source else "ناقص")

    return {
        "index": index,
        "subjectId": subject_id,
        "subjectTitle": subject_title,
        "title": clean_text(chapter.get("title")),
        "status": status,
        "baseQuestionCount": len(base_questions),
        "advancedQuestionCount": len(advanced_questions),
        "questionCount": len(questions),
        "validQuestionCount": valid_count,
        "explainedQuestionCount": explained_count,
        "questionFormats": formats,
        "allQuestionsMultipleChoice": all_multiple_choice,
        "hasDedicatedLesson": has_lesson,
        "summaryCharacters": len(clean_text(chapter.get("summary"))),
        "pointCount": len(points),
        "exampleCharacters": len(example),
        "solutionStepCount": len(steps),
        "solutionStepCharacters": len(step_text),
        "commonMistakeCount": len(mistakes),
        "hasChapterExam": has_exam,
        "sourceMapped": mapped_source,
        "pageStart": chapter.get("pageStart"),
        "pageEnd": chapter.get("pageEnd"),
        "sourceLesson": clean_text(chapter.get("sourceLesson")),
        "genericReasoningQuestionCount": generic_count,
        "tautologicalReasoningExplanationCount": tautological_count,
        "gaps": gaps,
    }


def audit_subjects(subjects_dir: Path) -> dict[str, Any]:
    packs: dict[str, dict[str, Any]] = {}
    for subject_id in EXPECTED_SUBJECTS:
        path = subjects_dir / f"{subject_id}.json"
        if not path.is_file():
            raise ValueError(f"Missing subject pack: {path}")
        pack = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(pack, dict) or pack.get("subjectId") != subject_id:
            raise ValueError(f"Invalid subject pack identity: {path}")
        if not isinstance(pack.get("chapters"), list):
            raise ValueError(f"Invalid chapters array: {path}")
        packs[subject_id] = pack

    unexpected = sorted(
        path.stem for path in subjects_dir.glob("*.json") if path.stem not in EXPECTED_SUBJECTS
    )
    if unexpected:
        raise ValueError(f"Unexpected subject packs: {', '.join(unexpected)}")

    subjects: list[dict[str, Any]] = []
    sections: list[dict[str, Any]] = []
    all_questions: list[dict[str, Any]] = []
    for subject_id in EXPECTED_SUBJECTS:
        pack = packs[subject_id]
        rows = [
            audit_chapter(subject_id, clean_text(pack.get("title")), pack, chapter, index)
            for index, chapter in enumerate(pack["chapters"], 1)
            if isinstance(chapter, dict)
        ]
        sections.extend(rows)
        for chapter in pack["chapters"]:
            if isinstance(chapter, dict):
                for key in ("questions", "advancedQuestions"):
                    values = chapter.get(key)
                    if isinstance(values, list):
                        all_questions.extend(item for item in values if isinstance(item, dict))

        source = pack.get("textbookSource")
        source = source if isinstance(source, dict) else {}
        source_status = clean_text(source.get("verificationStatus"))
        if not source_status:
            source_status = (
                "PDF metadata exists; source not reverified in this run"
                if clean_text(pack.get("textbookSourceFile"))
                else "official PDF source not recorded"
            )
        subjects.append(
            {
                "id": subject_id,
                "title": clean_text(pack.get("title")),
                "chapterCount": len(rows),
                "baseQuestionCount": sum(row["baseQuestionCount"] for row in rows),
                "advancedQuestionCount": sum(row["advancedQuestionCount"] for row in rows),
                "questionCount": sum(row["questionCount"] for row in rows),
                "sourceMappedCount": sum(row["sourceMapped"] for row in rows),
                "needsSourceCount": sum(row["status"] == "نیازمند منبع" for row in rows),
                "incompleteCount": sum(row["status"] == "ناقص" for row in rows),
                "completeCount": sum(row["status"] == "کامل" for row in rows),
                "dedicatedLessonCount": sum(row["hasDedicatedLesson"] for row in rows),
                "chapterExamCount": sum(row["hasChapterExam"] for row in rows),
                "genericReasoningCount": sum(row["genericReasoningQuestionCount"] > 0 for row in rows),
                "tautologicalReasoningCount": sum(
                    row["tautologicalReasoningExplanationCount"] > 0 for row in rows
                ),
                "shortExampleCount": sum(row["exampleCharacters"] < 80 for row in rows),
                "shortSolutionStepCount": sum(
                    row["solutionStepCharacters"] < 80 or row["solutionStepCount"] < 3
                    for row in rows
                ),
                "textbookEdition": clean_text(pack.get("textbookEdition")) or clean_text(source.get("schoolYear")),
                "textbookSourceUrl": clean_text(source.get("pdfUrl")),
                "textbookSourceStatus": source_status,
            }
        )

    question_texts = [
        re.sub(r"\s+", " ", clean_text(question.get("question"))).casefold()
        for question in all_questions
        if clean_text(question.get("question"))
    ]
    valid_questions = sum(question_is_valid(question) for question in all_questions)
    explained_questions = sum(bool(clean_text(question.get("explanation"))) for question in all_questions)
    multiple_choice_questions = sum(
        isinstance(question.get("options"), list) and len(question["options"]) >= 2
        for question in all_questions
    )
    totals = {
        "subjectCount": len(subjects),
        "sectionCount": len(sections),
        "baseQuestionCount": sum(row["baseQuestionCount"] for row in sections),
        "advancedQuestionCount": sum(row["advancedQuestionCount"] for row in sections),
        "questionCount": len(all_questions),
        "validQuestionCount": valid_questions,
        "explainedQuestionCount": explained_questions,
        "multipleChoiceQuestionCount": multiple_choice_questions,
        "nonMultipleChoiceQuestionCount": len(all_questions) - multiple_choice_questions,
        "duplicateQuestionPromptCount": len(question_texts) - len(set(question_texts)),
        "sourceMappedCount": sum(row["sourceMapped"] for row in sections),
        "needsSourceCount": sum(row["status"] == "نیازمند منبع" for row in sections),
        "incompleteCount": sum(row["status"] == "ناقص" for row in sections),
        "completeCount": sum(row["status"] == "کامل" for row in sections),
        "dedicatedLessonCount": sum(row["hasDedicatedLesson"] for row in sections),
        "chapterExamCount": sum(row["hasChapterExam"] for row in sections),
        "genericReasoningSectionCount": sum(row["genericReasoningQuestionCount"] > 0 for row in sections),
        "tautologicalReasoningSectionCount": sum(
            row["tautologicalReasoningExplanationCount"] > 0 for row in sections
        ),
        "shortExampleCount": sum(row["exampleCharacters"] < 80 for row in sections),
        "shortSolutionStepCount": sum(
            row["solutionStepCharacters"] < 80 or row["solutionStepCount"] < 3
            for row in sections
        ),
    }
    return {
        "auditDate": "2026-11-09",
        "method": "Conservative structural and traceability audit; not a certification of factual accuracy.",
        "thresholdNotes": {
            "dedicatedLessonCharacters": 350,
            "exampleCharacters": 80,
            "solutionStepCharacters": 80,
            "minimumBasePracticeQuestions": 5,
            "minimumChapterExamQuestions": 5,
            "minimumKeyPoints": 3,
            "minimumCommonMistakes": 2,
            "minimumSolutionSteps": 3,
        },
        "totals": totals,
        "subjects": subjects,
        "sections": sections,
    }


def render_markdown(report: dict[str, Any]) -> str:
    totals = report["totals"]
    lines = [
        "# ممیزی کیفیت واقعی محتوای فهمینو — ۱۴۰۵/۰۸/۱۸",
        "",
        "**تاریخ:** ۹ نوامبر ۲۰۲۶  ",
        "**روش:** ممیزی محافظه‌کارانهٔ ساختار، کفایت آموزشی و ردیابی منبع؛ این گزارش صحت علمی را تأیید نمی‌کند.",
        "",
        "## نتیجهٔ کلی",
        "",
        f"- بسته‌های درسی: **{totals['subjectCount']}**",
        f"- بخش‌ها/درس‌ها/پودمان‌ها: **{totals['sectionCount']}**",
        f"- پرسش‌های پایه: **{totals['baseQuestionCount']}**",
        f"- پرسش‌های افزودهٔ موسوم به استدلالی: **{totals['advancedQuestionCount']}**",
        f"- مجموع پرسش‌ها: **{totals['questionCount']}**",
        f"- پاسخ‌های دارای ساختار معتبر: **{totals['validQuestionCount']} از {totals['questionCount']}**",
        f"- پاسخ‌های دارای توضیح متنی: **{totals['explainedQuestionCount']} از {totals['questionCount']}**؛ وجود توضیح، صحت علمی آن را ثابت نمی‌کند.",
        f"- پرسش‌های چهارگزینه‌ای: **{totals['multipleChoiceQuestionCount']}**؛ غیرچهارگزینه‌ای: **{totals['nonMultipleChoiceQuestionCount']}**",
        f"- بخش دارای درسنامهٔ مستقل حداقل ۳۵۰ نویسه‌ای: **{totals['dedicatedLessonCount']} از {totals['sectionCount']}**",
        f"- بخش دارای آزمون مستقل فصل با حداقل ۵ سؤال معتبر: **{totals['chapterExamCount']} از {totals['sectionCount']}**",
        f"- بخش‌هایی که سؤال استدلالی آن‌ها از قالب بازنویسی سؤال پایه استفاده می‌کند: **{totals['genericReasoningSectionCount']}**",
        f"- بخش‌هایی که توضیح سؤال استدلالی عین گزینهٔ درست را تکرار می‌کند: **{totals['tautologicalReasoningSectionCount']}**",
        f"- مثال‌های کوتاه‌تر از ۸۰ نویسه (علامت بازبینی انسانی): **{totals['shortExampleCount']}**",
        f"- مراحل حل کوتاه‌تر از ۸۰ نویسه یا کمتر از ۳ گام: **{totals['shortSolutionStepCount']}**",
        "",
        "### وضعیت فصل‌به‌فصل",
        "",
        f"- **کامل: {totals['completeCount']}**",
        f"- **ناقص: {totals['incompleteCount']}**",
        f"- **نیازمند منبع/نگاشت: {totals['needsSourceCount']}**",
        "",
        "هیچ بخشی صرفاً به‌دلیل داشتن عنوان، خلاصه، سؤال یا پاسخ‌نامه کامل محسوب نشده است. وضعیت «نیازمند منبع» یعنی نسخه/فایل منبع و نگاشت دقیق صفحه و عنوان برای همان بخش هنوز در داده‌ها قابل ردیابی نیست.",
        "",
        "## خلاصهٔ درس‌به‌درس",
        "",
        "| بسته | بخش | سؤال پایه | سؤال افزوده | منبع‌نگاشت‌شده | ناقص | نیازمند منبع | درسنامه | آزمون فصل |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for subject in report["subjects"]:
        lines.append(
            f"| {subject['title']} ({subject['id']}) | {subject['chapterCount']} | "
            f"{subject['baseQuestionCount']} | {subject['advancedQuestionCount']} | "
            f"{subject['sourceMappedCount']} | {subject['incompleteCount']} | "
            f"{subject['needsSourceCount']} | {subject['dedicatedLessonCount']} | "
            f"{subject['chapterExamCount']} |"
        )
    lines.extend(
        [
            "",
            "## فهرست کامل فصل‌به‌فصل",
            "",
            "| درس | بخش | وضعیت | صفحه | سؤال پایه/افزوده | شکاف‌های شناسایی‌شده |",
            "|---|---|---|---:|---:|---|",
        ]
    )
    for row in report["sections"]:
        page = (
            f"{row['pageStart']}–{row['pageEnd']}"
            if isinstance(row.get("pageStart"), int) and isinstance(row.get("pageEnd"), int)
            else "—"
        )
        gaps = "؛ ".join(row["gaps"]) or "—"
        safe_title = row["title"].replace("|", "\\|")
        safe_subject = row["subjectTitle"].replace("|", "\\|")
        lines.append(
            f"| {safe_subject} | {safe_title} | **{row['status']}** | {page} | "
            f"{row['baseQuestionCount']}/{row['advancedQuestionCount']} | {gaps} |"
        )
    lines.extend(
        [
            "",
            "## تفسیر و محدودیت‌ها",
            "",
            "1. شمارش سؤال‌ها فقط ساختار داده را می‌سنجد؛ کیفیت علمی، تناسب دشواری، یکتایی گزینه‌ها از نظر معنا و هم‌خوانی با کتاب باید با بازبینی آموزشی انسانی بررسی شود.",
            "2. برچسب «استدلالی» به‌تنهایی نوع سؤال را تغییر نمی‌دهد. اگر سؤال همچنان چهار گزینه و یک اندیس پاسخ داشته باشد، از نظر قالب چهارگزینه‌ای است.",
            "3. آستانهٔ ۸۰ نویسه برای مثال و مراحل حل صرفاً علامت غربالگری است و جای داوری دبیر را نمی‌گیرد.",
            "4. برای کامل شدن هر بخش، درسنامهٔ مستقل، مثال واقعاً حل‌شده، تمرین متنوع، پاسخ تشریحی، آزمون فصل و نگاشت صفحه/نسخه باید جداگانه بازبینی شوند.",
            "5. لینک رسمی PDF به معنی دانلود، استخراج فهرست، بررسی همهٔ صفحات یا مجوز بازنشر نیست.",
            "",
            "## وضعیت منابع رسمیِ پنج کتابی که قبلاً غایب بودند",
            "",
            "برای هر پنج کتاب، صفحهٔ رسمی پایگاه کتاب‌های درسی و پیوند مستقیم PDF سال ۱۴۰۵–۱۴۰۶ پیدا شد. پیوند و مشخصات در بستهٔ JSON همان درس ثبت شده است؛ خود PDF در این اجرا دانلود یا صفحه‌به‌صفحه تحلیل نشده و هیچ محتوای دارای حق نشر کپی نشده است.",
            "",
            "- قرآن، کد ۸۰۱: [صفحهٔ رسمی](http://chap.sch.ir/books/14210) — [PDF رسمی](http://chap.sch.ir/sites/default/files/lbooks/1405-1406/558/C801.pdf) — ۱۲٫۴ مگابایت",
            "- پیام‌های آسمان، کد ۸۰۲: [صفحهٔ رسمی](http://chap.sch.ir/books/14217) — [PDF رسمی](http://chap.sch.ir/sites/default/files/lbooks/1405-1406/558/C802.pdf) — ۱۴٫۲۸ مگابایت",
            "- فارسی، کد ۸۰۳: [صفحهٔ رسمی](http://chap.sch.ir/books/14218) — [PDF رسمی](http://chap.sch.ir/sites/default/files/lbooks/1405-1406/558/C803.pdf) — ۱۰٫۷۳ مگابایت",
            "- نگارش، کد ۸۰۴: [صفحهٔ رسمی](http://chap.sch.ir/books/14219) — [PDF رسمی](http://chap.sch.ir/sites/default/files/lbooks/1405-1406/558/C804.pdf) — ۳۱٫۲۷ مگابایت",
            "- ریاضی، کد ۸۰۵: [صفحهٔ رسمی](http://chap.sch.ir/books/14220) — [PDF رسمی](http://chap.sch.ir/sites/default/files/lbooks/1405-1406/558/C805.pdf) — ۷٫۶۷ مگابایت",
            "",
            "فهرست کامل ۱۳ عنوان، کدها و پیوندهای رسمی در research/official-textbook-links-1405-1406.md ثبت شده است.",
            "صفحهٔ رسمی پایه هشتم سال تحصیلی ۱۴۰۵–۱۴۰۶: http://chap.sch.ir/category/دوره/دوره-اول-متوسطه-جدید/پایه-هشتم",
            "",
            "## گام بعدی",
            "",
            "ابتدا PDFهای رسمیِ دارای لینک را در محیط مجاز دریافت و از نظر نسخه، تعداد صفحات و فهرست مطالب بررسی کن؛ سپس برای ۵ کتاب تازه‌یافته، نگاشت فصل/درس/صفحه را تکمیل کن. بعد از آن باید درسنامه و نمونه‌های تألیفیِ هر فصل بازنویسی شوند و قالب‌های غیرچهارگزینه‌ای و آزمون فصل با پاسخ تشریحی اضافه شوند.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--subjects-dir", default="assets/content/subjects")
    parser.add_argument("--output-json")
    parser.add_argument("--output-markdown")
    args = parser.parse_args()

    report = audit_subjects(Path(args.subjects_dir))
    if args.output_json:
        path = Path(args.output_json)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    markdown = render_markdown(report)
    if args.output_markdown:
        path = Path(args.output_markdown)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(markdown, encoding="utf-8")
    print(json.dumps(report["totals"], ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
