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
            for q in [*chapter["questions"], *chapter.get("advancedQuestions", [])]:
                opts, answer = q.get("options"), q.get("answer")
                if not isinstance(opts, list) or len(opts) < 2 or not isinstance(answer, int) or not 0 <= answer < len(opts):
                    raise ValueError(f"Invalid question: {sid}/{q.get('question')}")
                if not q.get("explanation"):
                    raise ValueError(f"Missing explanation: {sid}/{q.get('question')}")
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
    if chapter["points"]:
        story.append(Paragraph(rtl("نکته‌های کلیدی"), st["question"]))
        for point in chapter["points"]:
            story.append(Paragraph(rtl("• " + point), st["body"]))
    if chapter.get("example"):
        story.append(Paragraph(rtl("مثال آموزشی: " + chapter["example"]), st["question"]))
    if chapter["solutionSteps"]:
        story.append(Paragraph(rtl("مراحل حل یا انجام کار"), st["question"]))
        for i, step in enumerate(chapter["solutionSteps"], 1):
            story.append(Paragraph(rtl(f"{i}. {step}"), st["body"]))

def build_subject_pdf(sid, subject, output, st):
    questions = [(chapter["title"], q) for chapter in subject["chapters"] for q in [*chapter["questions"], *chapter.get("advancedQuestions", [])]]
    story = [
        Spacer(1, 18*mm),
        Paragraph(rtl(subject["title"]), st["title"]),
        Paragraph(rtl("جزوهٔ آموزشی، نکته‌ها، مثال‌ها و نمونه‌سؤال‌های تألیفی | فهمینو | پایه هشتم"), st["subtitle"]),
        HRFlowable(width="100%", thickness=1, color=colors.HexColor("#C7D2FE")),
        Spacer(1, 5*mm),
        Paragraph(rtl("این فایل از محتوای آموزشی تألیفیِ فعلی فهمینو ساخته شده است؛ کتاب رسمی و همهٔ فعالیت‌های آن را جایگزین نمی‌کند. برای متن کامل و فعالیت‌های رسمی، به کتاب درسی همان سال مراجعه کن."), st["note"]),
    ]
    for chapter in subject["chapters"]:
        add_chapter_notes(story, chapter, st)
    story.append(PageBreak())
    story.append(Paragraph(rtl("نمونه‌سؤال‌ها"), st["title"]))
    letters = ["الف", "ب", "پ", "ت", "ث", "ج"]
    for i, (chapter_title, q) in enumerate(questions, 1):
        block = [Paragraph(rtl(f"{i}. {q['question']}"), st["question"]),
                 Paragraph(rtl("درس: " + chapter_title), st["note"])]
        for oi, option in enumerate(q["options"]):
            block.append(Paragraph(rtl(f"{letters[oi] if oi < len(letters) else oi+1}) {option}"), st["option"]))
        story.append(KeepTogether(block))
    story.append(PageBreak())
    story.append(Paragraph(rtl("پاسخ‌نامه و توضیح‌ها"), st["title"]))
    for i, (chapter_title, q) in enumerate(questions, 1):
        story.append(KeepTogether([
            Paragraph(rtl(f"{i}. {chapter_title}"), st["question"]),
            Paragraph(rtl("پاسخ درست: " + q["options"][q["answer"]]), st["body"]),
            Paragraph(rtl("توضیح: " + q["explanation"]), st["body"]),
            Spacer(1, 2*mm),
        ]))
    doc = SimpleDocTemplate(str(output), pagesize=A4, rightMargin=18*mm, leftMargin=18*mm,
        topMargin=17*mm, bottomMargin=20*mm, title=f"Fahmino {subject['title']}")
    doc.build(story, onFirstPage=footer, onLaterPages=footer)

def build_combined(subjects, output, st, questions_only=False):
    story = [Spacer(1, 18*mm),
        Paragraph(rtl("بانک جزوه‌های پایه هشتم" if not questions_only else "بانک نمونه‌سؤال‌های پایه هشتم"), st["title"]),
        Paragraph(rtl("فهمینو | محتوای تألیفی و آموزشیِ فعلی برنامه"), st["subtitle"]),
        Paragraph(rtl("این فایل جایگزین کامل کتاب‌های درسی و همهٔ فعالیت‌های رسمی نیست."), st["note"]),
        PageBreak()]
    answer_rows = []
    letters = ["الف", "ب", "پ", "ت", "ث", "ج"]
    number = 0
    for subject in subjects.values():
        story.append(Paragraph(rtl(subject["title"]), st["subject"]))
        for chapter in subject["chapters"]:
            if not questions_only:
                add_chapter_notes(story, chapter, st)
            else:
                story.append(Paragraph(rtl(chapter["title"]), st["chapter"]))
            for q in [*chapter["questions"], *chapter.get("advancedQuestions", [])]:
                number += 1
                if questions_only:
                    story.append(Paragraph(rtl(f"{number}. {q['question']}"), st["question"]))
                    for oi, option in enumerate(q["options"]):
                        story.append(Paragraph(rtl(f"{letters[oi] if oi < len(letters) else oi+1}) {option}"), st["option"]))
                answer_rows.append((number, subject["title"], chapter["title"], q))
    if questions_only:
        story.append(PageBreak())
        story.append(Paragraph(rtl("پاسخ‌نامه و توضیح‌ها"), st["title"]))
        for num, subj, chap, q in answer_rows:
            story.append(KeepTogether([
                Paragraph(rtl(f"{num}. {subj} — {chap}"), st["question"]),
                Paragraph(rtl("پاسخ درست: " + q["options"][q["answer"]]), st["body"]),
                Paragraph(rtl("توضیح: " + q["explanation"]), st["body"]),
                Spacer(1, 2*mm)]))
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
