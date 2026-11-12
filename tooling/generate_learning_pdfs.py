#!/usr/bin/env python3
"""Generate offline Persian study PDFs from Fahmino's current subject packs."""

from __future__ import annotations
import argparse
import json
import re
from pathlib import Path
from xml.sax.saxutils import escape

import arabic_reshaper
from bidi.algorithm import get_display
from reportlab.lib import colors
from reportlab.lib.enums import TA_RIGHT, TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, KeepTogether, HRFlowable

_MATH_SPAN = re.compile(
    r"(?<![A-Za-z0-9۰-۹])(?:"
    r"[(][۰-۹0-9A-Za-z]+(?: *[-+−×÷=<>≤≥] *[۰-۹0-9A-Za-z]+)+[)]"
    r"(?: *[×÷] *[۰-۹0-9A-Za-z]+)?"
    r"|[۰-۹0-9A-Za-z]+(?: */ *[۰-۹0-9A-Za-z]+)?"
    r"(?: *[-+−×÷=<>≤≥] *[۰-۹0-9A-Za-z]+(?: */ *[۰-۹0-9A-Za-z]+)?)+"
    r")(?![A-Za-z0-9۰-۹])"
)

def rtl(value: object) -> str:
    text = str(value or "")
    text = _MATH_SPAN.sub(lambda m: "\u202A" + m.group(0) + "\u202C", text)
    return escape(get_display(arabic_reshaper.reshape(text)))

def load_subjects(directory: Path) -> dict:
    subjects = {}
    for path in sorted(directory.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        sid = path.stem
        if not isinstance(data, dict) or data.get("subjectId") != sid:
            raise ValueError(f"Invalid subject pack identity: {path}")
        if not isinstance(data.get("title"), str) or not isinstance(data.get("chapters"), list):
            raise ValueError(f"Invalid subject pack structure: {path}")
        for chapter in data["chapters"]:
            for key in ("title", "summary", "points", "example", "solutionSteps", "questions"):
                if key not in chapter:
                    raise ValueError(f"Missing {key}: {sid}/{chapter.get('title')}")
            if not isinstance(chapter.get("lessonContent"), str) or len(chapter["lessonContent"].strip()) < 350:
                raise ValueError(f"Missing authored lesson content: {sid}/{chapter.get('title')}")
            if not isinstance(chapter.get("workedExamples"), list) or len(chapter["workedExamples"]) < 2:
                raise ValueError(f"Missing worked examples: {sid}/{chapter.get('title')}")
            if not isinstance(chapter.get("chapterExam"), list) or len(chapter["chapterExam"]) < 5:
                raise ValueError(f"Missing chapter exam: {sid}/{chapter.get('title')}")
            for q in [*chapter["questions"], *chapter.get("advancedQuestions", [])]:
                prompt = q.get("question")
                explanation = q.get("explanation")
                answer = q.get("answer")
                if not isinstance(prompt, str) or not prompt.strip() or not isinstance(explanation, str) or not explanation.strip():
                    raise ValueError(f"Invalid prompt/explanation: {sid}/{q.get('question')}")
                options = q.get("options")
                if isinstance(options, list):
                    if len(options) < 2 or not all(isinstance(option, str) and option.strip() for option in options) or not isinstance(answer, int) or isinstance(answer, bool) or not 0 <= answer < len(options):
                        raise ValueError(f"Invalid MCQ: {sid}/{q.get('question')}")
                elif q.get("questionType") == "short_answer":
                    if not isinstance(answer, str) or not answer.strip():
                        raise ValueError(f"Invalid short answer: {sid}/{q.get('question')}")
                elif q.get("questionType") == "true_false":
                    if answer not in ("درست", "نادرست"):
                        raise ValueError(f"Invalid true/false: {sid}/{q.get('question')}")
                else:
                    raise ValueError(f"Unsupported question type: {sid}/{q.get('question')}")
        subjects[sid] = data
    if len(subjects) != 13:
        raise ValueError(f"Expected 13 current subject packs, found {len(subjects)}")
    return subjects

def styles():
    base = getSampleStyleSheet()
    return {
        "title": ParagraphStyle("FTitle", parent=base["Title"], fontName="Vazirmatn-Bold",
            fontSize=21, leading=31, alignment=TA_CENTER, textColor=colors.HexColor("#312E81"), spaceAfter=7*mm),
        "subtitle": ParagraphStyle("FSub", parent=base["Normal"], fontName="Vazirmatn",
            fontSize=9, leading=16, alignment=TA_CENTER, textColor=colors.HexColor("#475569"), spaceAfter=5*mm),
        "subject": ParagraphStyle("FSubject", parent=base["Heading1"], fontName="Vazirmatn-Bold",
            fontSize=15, leading=23, alignment=TA_RIGHT, textColor=colors.HexColor("#3730A3"), spaceBefore=5*mm, spaceAfter=3*mm),
        "chapter": ParagraphStyle("FChapter", parent=base["Heading2"], fontName="Vazirmatn-SemiBold",
            fontSize=12, leading=20, alignment=TA_RIGHT, textColor=colors.HexColor("#0F766E"), spaceBefore=4*mm, spaceAfter=2*mm),
        "body": ParagraphStyle("FBody", parent=base["BodyText"], fontName="Vazirmatn",
            fontSize=9.5, leading=17, alignment=TA_RIGHT, spaceAfter=2*mm),
        "question": ParagraphStyle("FQuestion", parent=base["BodyText"], fontName="Vazirmatn-SemiBold",
            fontSize=9.5, leading=17, alignment=TA_RIGHT, spaceBefore=3*mm, spaceAfter=1*mm),
        "option": ParagraphStyle("FOption", parent=base["BodyText"], fontName="Vazirmatn",
            fontSize=9, leading=15, alignment=TA_RIGHT, rightIndent=4*mm),
        "note": ParagraphStyle("FNote", parent=base["BodyText"], fontName="Vazirmatn",
            fontSize=8, leading=14, alignment=TA_RIGHT, textColor=colors.HexColor("#64748B")),
    }

def footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(colors.HexColor("#CBD5E1"))
    canvas.setLineWidth(.4)
    canvas.line(18*mm, 14*mm, A4[0]-18*mm, 14*mm)
    canvas.setFont("Vazirmatn", 8)
    canvas.setFillColor(colors.HexColor("#64748B"))
    canvas.drawRightString(A4[0]-18*mm, 9*mm, get_display(arabic_reshaper.reshape("فهمینو | پایه هشتم")))
    canvas.drawString(18*mm, 9*mm, str(doc.page))
    canvas.restoreState()

def add_chapter_notes(story, chapter, st):
    story.append(Paragraph(rtl(chapter["title"]), st["chapter"]))
    story.append(Paragraph(rtl(chapter["summary"]), st["body"]))

    lesson = chapter.get("lessonContent", "")
    if lesson:
        story.append(Paragraph(rtl("درسنامهٔ کامل و اهداف یادگیری"), st["question"]))
        for line in lesson.splitlines():
            cleaned = line.strip()
            if not cleaned:
                story.append(Spacer(1, 1.2 * mm))
            elif len(cleaned) < 45 and not cleaned.endswith((".", "؟", "؛")):
                story.append(Paragraph(rtl(cleaned), st["question"]))
            else:
                story.append(Paragraph(rtl(cleaned), st["body"]))

    objectives = chapter.get("learningObjectives", [])
    if objectives:
        story.append(Paragraph(rtl("پس از مطالعه باید بتوانی"), st["question"]))
        for objective in objectives:
            story.append(Paragraph(rtl("• " + objective), st["body"]))

    if chapter["points"]:
        story.append(Paragraph(rtl("نکته‌های کلیدی"), st["question"]))
        for point in chapter["points"]:
            story.append(Paragraph(rtl("• " + point), st["body"]))

    examples = chapter.get("workedExamples", [])
    if examples:
        story.append(Paragraph(rtl("نمونه‌های حل‌شده"), st["question"]))
        for number, example in enumerate(examples, 1):
            block = [
                Paragraph(rtl(f"{number}. {example.get('title', 'نمونهٔ آموزشی')}"), st["question"]),
                Paragraph(rtl("پرسش: " + str(example.get("problem", ""))), st["body"]),
            ]
            for step_no, step in enumerate(example.get("steps", []), 1):
                block.append(Paragraph(rtl(f"{step_no}. {step}"), st["body"]))
            block.extend([
                Paragraph(rtl("پاسخ پیشنهادی: " + str(example.get("answer", ""))), st["body"]),
                Paragraph(rtl("دلیل: " + str(example.get("explanation", ""))), st["body"]),
                Spacer(1, 2 * mm),
            ])
            story.append(KeepTogether(block))
    elif chapter.get("example"):
        story.append(Paragraph(rtl("مثال آموزشی: " + chapter["example"]), st["question"]))

    if chapter["solutionSteps"]:
        story.append(Paragraph(rtl("مراحل حل یا انجام کار"), st["question"]))
        for i, step in enumerate(chapter["solutionSteps"], 1):
            story.append(Paragraph(rtl(f"{i}. {step}"), st["body"]))

    mistakes = chapter.get("commonMistakes", [])
    if mistakes:
        story.append(Paragraph(rtl("خطاهای رایج و راه پیشگیری"), st["question"]))
        for mistake in mistakes:
            story.append(Paragraph(rtl("• " + mistake), st["body"]))

def append_question_pdf(story, number, chapter_title, question, st):
    prompt = str(question.get("question", ""))
    kind = question.get("questionType", "multiple_choice")
    block = [
        Paragraph(rtl(f"{number}. {prompt}"), st["question"]),
        Paragraph(rtl("درس: " + chapter_title), st["note"]),
    ]
    options = question.get("options")
    if isinstance(options, list):
        labels = ["الف", "ب", "پ", "ت", "ث", "ج", "چ", "ح"]
        for index, option in enumerate(options):
            label = labels[index] if index < len(labels) else str(index + 1)
            block.append(Paragraph(rtl(f"{label}) {option}"), st["option"]))
    elif kind == "true_false":
        block.append(Paragraph(rtl("درست  □     نادرست  □"), st["option"]))
    elif kind == "short_answer":
        block.append(Paragraph(rtl("پاسخ کوتاه خود را در جای خالی بنویس:"), st["note"]))
        block.append(Spacer(1, 10 * mm))
        block.append(HRFlowable(width="100%", thickness=0.5, color=colors.HexColor("#CBD5E1")))
    story.append(KeepTogether(block))
    story.append(Spacer(1, 2 * mm))


def question_answer_text(question):
    options = question.get("options")
    answer = question.get("answer")
    if isinstance(options, list) and isinstance(answer, int) and 0 <= answer < len(options):
        return str(options[answer])
    if isinstance(answer, str):
        return answer
    return "پاسخ ثبت نشده است"


def append_answer_pdf(story, number, label, question, st):
    answer = question_answer_text(question)
    story.append(KeepTogether([
        Paragraph(rtl(f"{number}. {label}"), st["question"]),
        Paragraph(rtl("پاسخ: " + answer), st["body"]),
        Paragraph(rtl("توضیح: " + str(question.get("explanation", ""))), st["body"]),
        Spacer(1, 2 * mm),
    ]))

def build_subject_pdf(sid, subject, output, st):
    questions = [
        (chapter["title"], q)
        for chapter in subject["chapters"]
        for q in [*chapter["questions"], *chapter.get("advancedQuestions", [])]
    ]
    story = [
        Spacer(1, 18*mm),
        Paragraph(rtl(subject["title"]), st["title"]),
        Paragraph(rtl("درسنامه، مثال حل‌شده، تمرین و آزمون کوتاه | فهمینو | پایه هشتم"), st["subtitle"]),
        HRFlowable(width="100%", thickness=1, color=colors.HexColor("#C7D2FE")),
        Spacer(1, 5*mm),
        Paragraph(rtl("این فایل از محتوای آموزشی تألیفیِ فهمینو ساخته شده است؛ کتاب رسمی و همهٔ فعالیت‌های آن را جایگزین نمی‌کند. برای متن و فعالیت‌های رسمی، به کتاب درسی همان سال مراجعه کن."), st["note"]),
    ]
    for chapter in subject["chapters"]:
        add_chapter_notes(story, chapter, st)
    story.append(PageBreak())
    story.append(Paragraph(rtl("بانک تمرین و نمونه‌سؤال"), st["title"]))
    for i, (chapter_title, q) in enumerate(questions, 1):
        append_question_pdf(story, i, chapter_title, q, st)
    story.append(PageBreak())
    story.append(Paragraph(rtl("پاسخ‌نامه و توضیح‌ها"), st["title"]))
    for i, (chapter_title, q) in enumerate(questions, 1):
        append_answer_pdf(story, i, chapter_title, q, st)
    doc = SimpleDocTemplate(str(output), pagesize=A4, rightMargin=18*mm, leftMargin=18*mm,
        topMargin=17*mm, bottomMargin=20*mm, title=f"Fahmino {subject['title']}")
    doc.build(story, onFirstPage=footer, onLaterPages=footer)

def build_combined(subjects, output, st, questions_only=False):
    story = [
        Spacer(1, 18*mm),
        Paragraph(rtl("بانک درسنامه‌های پایه هشتم" if not questions_only else "بانک تمرین‌های پایه هشتم"), st["title"]),
        Paragraph(rtl("فهمینو | محتوای تألیفی آموزشی با پاسخ و توضیح"), st["subtitle"]),
        Paragraph(rtl("این فایل جایگزین کامل کتاب‌های درسی و همهٔ فعالیت‌های رسمی نیست."), st["note"]),
        PageBreak(),
    ]
    answer_rows = []
    number = 0
    for subject in subjects.values():
        story.append(Paragraph(rtl(subject["title"]), st["subject"]))
        for chapter in subject["chapters"]:
            if not questions_only:
                add_chapter_notes(story, chapter, st)
            else:
                story.append(Paragraph(rtl(chapter["title"]), st["chapter"]))
            for question in [*chapter["questions"], *chapter.get("advancedQuestions", [])]:
                number += 1
                if questions_only:
                    append_question_pdf(story, number, chapter["title"], question, st)
                answer_rows.append((number, subject["title"], chapter["title"], question))
    if questions_only:
        story.append(PageBreak())
        story.append(Paragraph(rtl("پاسخ‌نامه و توضیح‌ها"), st["title"]))
        for num, subj, chap, question in answer_rows:
            append_answer_pdf(story, num, f"{subj} — {chap}", question, st)
    doc = SimpleDocTemplate(str(output), pagesize=A4, rightMargin=18*mm, leftMargin=18*mm,
        topMargin=17*mm, bottomMargin=20*mm, title="Fahmino Grade 8")
    doc.build(story, onFirstPage=footer, onLaterPages=footer)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--subjects-dir", default="assets/content/subjects")
    parser.add_argument("--font-dir", default="assets/fonts/Vazirmatn")
    parser.add_argument("--output-dir", default="assets/generated_pdfs")
    args = parser.parse_args()
    subjects = load_subjects(Path(args.subjects_dir))
    font_dir = Path(args.font_dir)
    pdfmetrics.registerFont(TTFont("Vazirmatn", str(font_dir / "Vazirmatn-Regular.ttf")))
    pdfmetrics.registerFont(TTFont("Vazirmatn-SemiBold", str(font_dir / "Vazirmatn-SemiBold.ttf")))
    pdfmetrics.registerFont(TTFont("Vazirmatn-Bold", str(font_dir / "Vazirmatn-Bold.ttf")))
    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)
    st = styles()
    for sid, subject in subjects.items():
        build_subject_pdf(sid, subject, out / f"Fahmino-{sid}-FA.pdf", st)
    build_combined(subjects, out / "Fahmino-Grade8-Notes-FA.pdf", st, False)
    build_combined(subjects, out / "Fahmino-Grade8-Sample-Questions-FA.pdf", st, True)
    print(f"Generated {len(subjects)} subject PDFs and 2 combined PDFs.")

if __name__ == "__main__":
    main()
