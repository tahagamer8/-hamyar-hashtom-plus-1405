#!/usr/bin/env python3
"""Generate a conservative, chapter-by-chapter structural coverage audit."""
from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import Counter
from pathlib import Path
from typing import Any

SUBJECT_IDS = (
    "arabic", "art", "english", "english_workbook", "math", "persian",
    "quran", "religion", "science", "social", "thinking", "work", "writing",
)
AUDIT_DATE = "2026-11-14"
AUDITED_REF = "audit/textbook-alignment-1405"

GAP_LABELS = {
    "missing_official_reference_fields": "ارجاع صفحه/درس کامل نیست",
    "summary_under_100_chars": "خلاصه کمتر از ۱۰۰ نویسه است",
    "fewer_than_3_concept_points": "کمتر از ۳ نکتهٔ مفهومی دارد",
    "example_missing_or_short": "مثال غایب یا بسیار کوتاه است",
    "fewer_than_3_solution_steps": "کمتر از ۳ گام راهنما دارد",
    "fewer_than_2_common_mistakes": "کمتر از ۲ اشتباه رایج دارد",
    "fewer_than_5_sample_questions": "کمتر از ۵ سؤال نمونه دارد",
    "question_types_not_diverse": "تنوع نوع سؤال ندارد",
    "invalid_or_missing_inline_answers": "کلید پاسخ بعضی سؤال‌ها معتبر نیست",
    "missing_question_explanations": "توضیح پاسخ بعضی سؤال‌ها خالی است",
    "chapter_test_missing": "آزمون مستقل فصل ثبت نشده",
    "chapter_test_answer_key_missing": "پاسخ‌نامهٔ مستقل آزمون فصل ثبت نشده",
    "solved_example_not_verified": "حل‌شده بودن مثال به‌صورت مستقل تأیید نشده",
    "official_mapping_not_verified": "نگاشت رسمی فصل/صفحه تأیید نشده",
    "human_review_not_approved": "بازبینی انسانی با وضعیت تأیید ثبت نشده",
}


def normalize_question(value: str) -> str:
    value = unicodedata.normalize("NFKC", value).casefold().replace("\u200c", "")
    return re.sub(r"[\W_]+", "", value, flags=re.UNICODE)


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _question_type(question: dict[str, Any]) -> str:
    declared = question.get("questionType") or question.get("type")
    if isinstance(declared, str) and declared.strip():
        return declared.strip().lower()
    if isinstance(question.get("options"), list):
        return "multiple_choice"
    return "unclassified"


def _answer_is_valid(question: dict[str, Any]) -> bool:
    options = question.get("options")
    answer = question.get("answer")
    if isinstance(options, list):
        return _is_int(answer) and 0 <= answer < len(options)
    return answer is not None and str(answer).strip() != ""


def audit_chapter(subject_id: str, index: int, chapter: dict[str, Any]) -> dict[str, Any]:
    questions = chapter.get("questions")
    if not isinstance(questions, list):
        questions = []
    points = chapter.get("points")
    if not isinstance(points, list):
        points = []
    steps = chapter.get("solutionSteps")
    if not isinstance(steps, list):
        steps = []
    mistakes = chapter.get("commonMistakes")
    if not isinstance(mistakes, list):
        mistakes = []

    summary = chapter.get("summary") if isinstance(chapter.get("summary"), str) else ""
    example = chapter.get("example") if isinstance(chapter.get("example"), str) else ""
    valid_answers = sum(_answer_is_valid(q) for q in questions if isinstance(q, dict))
    explained = sum(
        isinstance(q, dict)
        and isinstance(q.get("explanation"), str)
        and bool(q["explanation"].strip())
        for q in questions
    )
    substantial_explanations = sum(
        isinstance(q, dict)
        and isinstance(q.get("explanation"), str)
        and len(q["explanation"].strip()) >= 20
        for q in questions
    )
    question_type_counts = Counter(_question_type(q) for q in questions if isinstance(q, dict))
    question_types = sorted(question_type_counts)

    has_page_start = _is_int(chapter.get("pageStart"))
    has_page_end = _is_int(chapter.get("pageEnd"))
    source_lesson = chapter.get("sourceLesson")
    textbook_lessons = chapter.get("textbookLessons")
    has_lesson_reference = (
        isinstance(source_lesson, str) and bool(source_lesson.strip())
    ) or (
        isinstance(textbook_lessons, list)
        and any(
            isinstance(item, dict)
            and isinstance(item.get("title"), str)
            and item["title"].strip()
            for item in textbook_lessons
        )
    )
    reference_fields_complete = has_page_start and has_page_end and has_lesson_reference

    chapter_test = chapter.get("chapterTest")
    if not isinstance(chapter_test, list):
        chapter_test = chapter.get("testQuestions")
    has_chapter_test = isinstance(chapter_test, list) and bool(chapter_test)

    answer_key = chapter.get("answerKey")
    if not isinstance(answer_key, list):
        answer_key = chapter.get("chapterTestAnswerKey")
    has_answer_key = isinstance(answer_key, list) and bool(answer_key)

    solved_example_verified = chapter.get("solvedExampleVerified") is True
    official_mapping_verified = chapter.get("officialMappingVerified") is True
    human_review_approved = chapter.get("humanReviewStatus") == "approved"

    gaps: list[str] = []
    if not reference_fields_complete:
        gaps.append("missing_official_reference_fields")
    if len(summary.strip()) < 100:
        gaps.append("summary_under_100_chars")
    if len(points) < 3:
        gaps.append("fewer_than_3_concept_points")
    if len(example.strip()) < 25:
        gaps.append("example_missing_or_short")
    if len(steps) < 3:
        gaps.append("fewer_than_3_solution_steps")
    if len(mistakes) < 2:
        gaps.append("fewer_than_2_common_mistakes")
    if len(questions) < 5:
        gaps.append("fewer_than_5_sample_questions")
    if len(question_types) < 2:
        gaps.append("question_types_not_diverse")
    if valid_answers != len(questions):
        gaps.append("invalid_or_missing_inline_answers")
    if explained != len(questions):
        gaps.append("missing_question_explanations")
    if not has_chapter_test:
        gaps.append("chapter_test_missing")
    if not has_answer_key:
        gaps.append("chapter_test_answer_key_missing")
    if not solved_example_verified:
        gaps.append("solved_example_not_verified")
    if not official_mapping_verified:
        gaps.append("official_mapping_not_verified")
    if not human_review_approved:
        gaps.append("human_review_not_approved")

    if not reference_fields_complete:
        status = "needs_source"
    elif gaps:
        status = "incomplete"
    else:
        status = "complete"

    return {
        "subjectId": subject_id,
        "chapterIndex": index,
        "title": chapter.get("title", f"بخش {index}"),
        "status": status,
        "reference": {
            "pageStart": chapter.get("pageStart"),
            "pageEnd": chapter.get("pageEnd"),
            "lessonReferencePresent": has_lesson_reference,
            "referenceFieldsComplete": reference_fields_complete,
        },
        "metrics": {
            "summaryCharacters": len(summary.strip()),
            "conceptPointCount": len(points),
            "exampleCharacters": len(example.strip()),
            "solutionStepCount": len(steps),
            "commonMistakeCount": len(mistakes),
            "sampleQuestionCount": len(questions),
            "questionTypes": question_types,
            "questionTypeCounts": dict(sorted(question_type_counts.items())),
            "validInlineAnswerCount": valid_answers,
            "explainedQuestionCount": explained,
            "substantialExplanationCount": substantial_explanations,
            "chapterTestCount": len(chapter_test) if has_chapter_test else 0,
            "separateAnswerKeyPresent": has_answer_key,
        },
        "verification": {
            "solvedExampleVerified": solved_example_verified,
            "officialMappingVerified": official_mapping_verified,
            "humanReviewApproved": human_review_approved,
        },
        "gaps": gaps,
    }


def build_report(subjects_dir: Path) -> dict[str, Any]:
    subjects: list[dict[str, Any]] = []
    all_question_texts: list[str] = []
    total_questions = 0
    total_valid_answers = 0
    total_explained = 0
    total_substantial_explanations = 0
    total_question_types: Counter[str] = Counter()
    total_chapter_type_presence_counts: Counter[str] = Counter()
    missing_files: list[str] = []

    for subject_id in SUBJECT_IDS:
        path = subjects_dir / f"{subject_id}.json"
        if not path.is_file():
            missing_files.append(subject_id)
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        chapters_data = data.get("chapters")
        if not isinstance(chapters_data, list):
            chapters_data = []

        chapters: list[dict[str, Any]] = []
        question_count = 0
        valid_answers = 0
        explained = 0
        substantial = 0
        question_types: Counter[str] = Counter()
        chapter_type_presence_counts: Counter[str] = Counter()
        for index, chapter in enumerate(chapters_data, start=1):
            if not isinstance(chapter, dict):
                chapter = {}
            audited = audit_chapter(subject_id, index, chapter)
            chapters.append(audited)
            questions = chapter.get("questions")
            if not isinstance(questions, list):
                questions = []
            question_count += len(questions)
            valid_answers += audited["metrics"]["validInlineAnswerCount"]
            explained += audited["metrics"]["explainedQuestionCount"]
            substantial += audited["metrics"]["substantialExplanationCount"]
            question_types.update(audited["metrics"]["questionTypeCounts"])
            chapter_type_presence_counts.update(audited["metrics"]["questionTypes"])
            for question in questions:
                if isinstance(question, dict) and isinstance(question.get("question"), str):
                    all_question_texts.append(question["question"])

        counts = Counter(chapter["status"] for chapter in chapters)
        subjects.append({
            "id": subject_id,
            "title": data.get("title", subject_id),
            "contentVersion": data.get("contentVersion"),
            "chapterCount": len(chapters),
            "questionCount": question_count,
            "statusCounts": {
                "complete": counts.get("complete", 0),
                "incomplete": counts.get("incomplete", 0),
                "needs_source": counts.get("needs_source", 0),
            },
            "questionTypeCounts": dict(sorted(question_types.items())),
            "chapterTypePresenceCounts": dict(sorted(chapter_type_presence_counts.items())),
            "chapters": chapters,
        })
        total_questions += question_count
        total_valid_answers += valid_answers
        total_explained += explained
        total_substantial_explanations += substantial
        total_question_types.update(question_types)
        total_chapter_type_presence_counts.update(chapter_type_presence_counts)

    normalized = Counter(
        normalize_question(text)
        for text in all_question_texts
        if normalize_question(text)
    )
    duplicate_groups = sum(1 for count in normalized.values() if count > 1)
    duplicate_copies = sum(count - 1 for count in normalized.values() if count > 1)

    all_chapters = [chapter for subject in subjects for chapter in subject["chapters"]]
    status_counts = Counter(chapter["status"] for chapter in all_chapters)
    metrics = [chapter["metrics"] for chapter in all_chapters]

    return {
        "auditDate": AUDIT_DATE,
        "auditedRef": AUDITED_REF,
        "scope": "ساختار قابل مشاهدهٔ ۱۳ بستهٔ JSON؛ این ممیزی جایگزین تطبیق علمی و بازبینی انسانی نیست.",
        "method": {
            "summaryMinimumCharacters": 100,
            "minimumConceptPoints": 3,
            "minimumExampleCharacters": 25,
            "minimumSolutionSteps": 3,
            "minimumCommonMistakes": 2,
            "minimumSampleQuestions": 5,
            "minimumDistinctQuestionTypes": 2,
            "completeRequires": [
                "all structural minimums",
                "chapter test and its separate answer key",
                "solved example explicitly verified",
                "official chapter/page mapping explicitly verified",
                "human review status approved",
            ],
        },
        "totals": {
            "packageCount": len(subjects),
            "missingPackageIds": missing_files,
            "chapterCount": len(all_chapters),
            "questionCount": total_questions,
            "validInlineAnswers": total_valid_answers,
            "questionsWithExplanation": total_explained,
            "questionsWithExplanationAtLeast20Chars": total_substantial_explanations,
            "questionTypeCounts": dict(sorted(total_question_types.items())),
            "chapterTypePresenceCounts": dict(sorted(total_chapter_type_presence_counts.items())),
            "exactDuplicateQuestionGroups": duplicate_groups,
            "exactDuplicateQuestionCopies": duplicate_copies,
            "statusCounts": {
                "complete": status_counts.get("complete", 0),
                "incomplete": status_counts.get("incomplete", 0),
                "needs_source": status_counts.get("needs_source", 0),
            },
            "chaptersWithAtLeast5Questions": sum(
                1 for item in metrics if item["sampleQuestionCount"] >= 5
            ),
            "chaptersWithCompleteReferenceFields": sum(
                1 for chapter in all_chapters
                if chapter["reference"]["referenceFieldsComplete"]
            ),
            "chaptersWithChapterTest": sum(
                1 for item in metrics if item["chapterTestCount"] > 0
            ),
            "chaptersWithSeparateAnswerKey": sum(
                1 for item in metrics if item["separateAnswerKeyPresent"]
            ),
            "chaptersWithSolvedExampleVerified": sum(
                1 for chapter in all_chapters
                if chapter["verification"]["solvedExampleVerified"]
            ),
            "chaptersWithOfficialMappingVerified": sum(
                1 for chapter in all_chapters
                if chapter["verification"]["officialMappingVerified"]
            ),
            "chaptersWithHumanReviewApproved": sum(
                1 for chapter in all_chapters
                if chapter["verification"]["humanReviewApproved"]
            ),
        },
        "limitations": [
            "فیلد example همراه با solutionSteps به‌تنهایی اثبات نمی‌کند که مثال واقعاً حل‌شده و از نظر علمی درست است.",
            "وجود pageStart/pageEnd و عنوان درس، تطبیق صفحه‌به‌صفحه با PDF رسمی را ثابت نمی‌کند.",
            "سؤال‌های فعلی فقط از روی ساختار JSON شمارش شده‌اند؛ صحت علمی آن‌ها با داوری انسانی تأیید نشده است.",
            "تمام وضعیت‌های complete نیازمند ثبت صریح تأیید نگاشت رسمی و بازبینی انسانی هستند.",
        ],
        "subjects": subjects,
    }


def render_markdown(report: dict[str, Any]) -> str:
    totals = report["totals"]
    lines = [
        "# ممیزی فصل‌به‌فصل پوشش محتوای فهمینو",
        "",
        f"**تاریخ:** {report['auditDate']}  ",
        f"**شاخهٔ مبنا:** {report['auditedRef']}",
        "",
        "## جمع‌بندی",
        "",
        f"- بسته‌ها: **{totals['packageCount']}**",
        f"- بخش‌ها/فصل‌ها/درس‌ها: **{totals['chapterCount']}**",
        f"- سؤال‌ها: **{totals['questionCount']}**؛ پاسخ‌های درون‌سؤالی معتبر: **{totals['validInlineAnswers']}**",
        f"- سؤال دارای توضیح: **{totals['questionsWithExplanation']}**؛ توضیح با حداقل ۲۰ نویسه: **{totals['questionsWithExplanationAtLeast20Chars']}**",
        f"- توزیع نوع سؤال بر اساس تعداد واقعی سؤال‌ها: {totals['questionTypeCounts']}",
        f"- تعداد فصل‌های دارای هر نوع سؤال: {totals['chapterTypePresenceCounts']}",
        f"- تکرار دقیق متن سؤال پس از نرمال‌سازی: **{totals['exactDuplicateQuestionGroups']} گروه**",
        f"- وضعیت فصل‌ها: **کامل {totals['statusCounts']['complete']} / ناقص {totals['statusCounts']['incomplete']} / نیازمند منبع {totals['statusCounts']['needs_source']}**",
        f"- فصل دارای حداقل ۵ سؤال: **{totals['chaptersWithAtLeast5Questions']}**",
        f"- فصل دارای آزمون مستقل: **{totals['chaptersWithChapterTest']}**",
        f"- فصل دارای پاسخ‌نامهٔ مستقل آزمون: **{totals['chaptersWithSeparateAnswerKey']}**",
        f"- فصل دارای ارجاع ساختاری کامل صفحه/درس: **{totals['chaptersWithCompleteReferenceFields']}**",
        f"- فصل با نگاشت رسمی تأییدشده: **{totals['chaptersWithOfficialMappingVerified']}**",
        f"- فصل با بازبینی انسانی تأییدشده: **{totals['chaptersWithHumanReviewApproved']}**",
        "",
        "## وضعیت هر بسته",
        "",
        "| بسته | نسخهٔ داده | بخش | سؤال | کامل | ناقص | نیازمند منبع |",
        "|---|---|---:|---:|---:|---:|---:|",
    ]
    for subject in report["subjects"]:
        counts = subject["statusCounts"]
        lines.append(
            f"| {subject['title']} ({subject['id']}) | {subject.get('contentVersion') or '—'} | "
            f"{subject['chapterCount']} | {subject['questionCount']} | {counts['complete']} | "
            f"{counts['incomplete']} | {counts['needs_source']} |"
        )

    lines.extend([
        "",
        "## جزئیات هر درس/فصل/بخش",
        "",
        "«ناقص» یعنی فیلدهای ارجاع صفحه/درس وجود دارد اما معیارهای محتوا یا تأیید کامل نیست؛ «نیازمند منبع» یعنی یکی از صفحهٔ آغاز، صفحهٔ پایان یا عنوان مرجع درس وجود ندارد. هیچ بخش با وجود صرف عنوان، خلاصه یا چند تست کامل اعلام نمی‌شود.",
        "",
    ])
    for subject in report["subjects"]:
        lines.extend([
            f"### {subject['title']} ({subject['id']})",
            "",
            "| # | عنوان | وضعیت | صفحه آغاز–پایان | سؤال | کمبودهای اصلی |",
            "|---:|---|---|---|---:|---|",
        ])
        for chapter in subject["chapters"]:
            ref = chapter["reference"]
            start = ref["pageStart"] if ref["pageStart"] is not None else "؟"
            end = ref["pageEnd"] if ref["pageEnd"] is not None else "؟"
            gaps = "، ".join(GAP_LABELS.get(gap, gap) for gap in chapter["gaps"])
            lines.append(
                f"| {chapter['chapterIndex']} | {chapter['title']} | {chapter['status']} | "
                f"{start}–{end} | {chapter['metrics']['sampleQuestionCount']} | {gaps} |"
            )
        lines.append("")

    lines.extend([
        "## معیار و محدودیت",
        "",
        "این گزارش ممیزی ساختاری است، نه تأیید علمی. برای «کامل» شدن، علاوه بر حداقل‌های ساختاری، آزمون فصل و پاسخ‌نامهٔ مستقل، مثال حل‌شدهٔ تأییدشده، نگاشت رسمی صفحه/فصل و بازبینی انسانیِ ثبت‌شده لازم است. فیلدهای موجود به‌تنهایی اثبات نمی‌کنند که محتوای آموزشی کافی، درست یا منطبق با همهٔ فعالیت‌های کتاب است.",
        "",
        "متن و تصویر کتاب‌های درسی یا PDF رسمی در این گزارش کپی نشده است.",
        "",
    ])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output-dir", type=Path, default=None)
    args = parser.parse_args()

    root = args.root.resolve()
    subjects_dir = root / "assets" / "content" / "subjects"
    output_dir = args.output_dir or (root / "research" / "generated")
    output_dir.mkdir(parents=True, exist_ok=True)

    report = build_report(subjects_dir)
    if report["totals"]["missingPackageIds"]:
        raise SystemExit("Missing subject packs: " + ", ".join(report["totals"]["missingPackageIds"]))

    json_path = output_dir / "chapter-coverage-audit-2026-11-14.json"
    markdown_path = output_dir / "chapter-coverage-audit-2026-11-14.md"
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    markdown_path.write_text(render_markdown(report), encoding="utf-8")

    totals = report["totals"]
    print(
        "Chapter audit: "
        f"{totals['packageCount']} packs, {totals['chapterCount']} chapters, "
        f"{totals['questionCount']} questions; "
        f"complete={totals['statusCounts']['complete']}, "
        f"incomplete={totals['statusCounts']['incomplete']}, "
        f"needs_source={totals['statusCounts']['needs_source']}"
    )
    print(f"JSON: {json_path}")
    print(f"Markdown: {markdown_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
