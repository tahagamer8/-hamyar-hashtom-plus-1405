#!/usr/bin/env python3
"""Generate Persian study notes and sample-question PDFs from Fahmino's authored catalog."""

from __future__ import annotations

import argparse
import json
import os
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
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak, KeepTogether,
    HRFlowable
)

# Keep arithmetic spans in left-to-right embedding so bidi shaping cannot
# silently swap operands such as ۳/۴ − ۱/۲ in generated PDFs.
_MATH_SPAN = re.compile(
    r"(?<![A-Za-z0-9۰-۹])(?:[۰-۹0-9A-Za-z]+(?:[ ]*/[ \\t]*[۰-۹0-9A-Za-z]+)?"
    r"(?:[ \\t]*[-+−×÷=<>≤≥][ \\t]*[۰-۹0-9A-Za-z]+(?:[ \\t]*/[ \\t]*[۰-۹0-9A-Za-z]+)?)+)(?![A-Za-z0-9۰-۹])"
)

def rtl(value: object) -> str:
    text = str(value or "")
    text = _MATH_SPAN.sub(lambda match: "\\u202A" + match.group(0) + "\\u202C", text)
    shaped = arabic_reshaper.reshape(text)
    return escape(get_display(shaped))

def load_catalog(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or not data:
        raise ValueError("Catalog must be a non-empty JSON object.")
    for subject_id, subject in data.items():
        if not isinstance(subject, dict) or not isinstance(subject.get("title"), str):
            raise ValueError(f"Invalid subject metadata: {subject_id}")
        chapters = subject.get("chapters")
        if not isinstance(chapters, list) or not chapters:
            raise ValueError(f"Subject has no chapters: {subject_id}")
        for chapter in chapters:
            if not isinstance(chapter, dict):
                raise ValueError(f"Invalid chapter in {subject_id}")
            for key in ("title", "summary", "points", "solutionSteps", "questions"):
                if key not in chapter:
                    raise ValueError(f"Missing {key} in {subject_id}/{chapter.get('title')}")
            for question in chapter["questions"]:
                options = question.get("options")
                answer = question.get("answer")
                if not isinstance(options, list) or not options:
                    raise ValueError(f"Question has no options: {question.get('question')}")
                if not isinstance(answer, int) or answer < 0 or answer >= len(options):
                    raise ValueError(f"Invalid answer index: {question.get('question')}")
                if not question.get("explanation"):
                    raise ValueError(f"Missing explanation: {question.get('question')}")
    return data

def styles():
    base = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "FahminoTitle", parent=base["Title"], fontName="Vazirmatn-Bold",
            fontSize=22, leading=32, alignment=TA_CENTER, textColor=colors.HexColor("#312E81"),
            spaceAfter=8*mm
        ),
        "subtitle": ParagraphStyle(
            "FahminoSubtitle", parent=base["Normal"], fontName="Vazirmatn",
            fontSize=10, leading=17, alignment=TA_CENTER, textColor=colors.HexColor("#475569"),
            spaceAfter=5*mm
        ),
        "subject": ParagraphStyle(
            "FahminoSubject", parent=base["Heading1"], fontName="Vazirmatn-Bold",
            fontSize=16, leading=24, alignment=TA_RIGHT, textColor=colors.HexColor("#3730A3"),
            spaceBefore=7*mm, spaceAfter=3*mm
        ),
        "chapter": ParagraphStyle(
            "FahminoChapter", parent=base["Heading2"], fontName="Vazirmatn-SemiBold",
            fontSize=13, leading=21, alignment=TA_RIGHT, textColor=colors.HexColor("#0F766E"),
            spaceBefore=4*mm, spaceAfter=2*mm
        ),
        "body": ParagraphStyle(
            "FahminoBody", parent=base["BodyText"], fontName="Vazirmatn",
            fontSize=10, leading=18, alignment=TA_RIGHT, spaceAfter=2*mm
        ),
        "small": ParagraphStyle(
            "FahminoSmall", parent=base["BodyText"], fontName="Vazirmatn",
            fontSize=8, leading=14, alignment=TA_RIGHT, textColor=colors.HexColor("#64748B")
        ),
        "question": ParagraphStyle(
            "FahminoQuestion", parent=base["BodyText"], fontName="Vazirmatn-SemiBold",
            fontSize=10, leading=18, alignment=TA_RIGHT, spaceBefore=3*mm, spaceAfter=1*mm
        ),
        "option": ParagraphStyle(
            "FahminoOption", parent=base["BodyText"], fontName="Vazirmatn",
            fontSize=9, leading=16, alignment=TA_RIGHT, rightIndent=4*mm
        ),
    }

def page_footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(colors.HexColor("#CBD5E1"))
    canvas.setLineWidth(0.4)
    canvas.line(18*mm, 14*mm, A4[0]-18*mm, 14*mm)
    canvas.setFont("Vazirmatn", 8)
    canvas.setFillColor(colors.HexColor("#64748B"))
    canvas.drawRightString(A4[0]-18*mm, 9*mm, get_display(arabic_reshaper.reshape("فهمینو | پایه هشتم")))
    canvas.drawString(18*mm, 9*mm, str(doc.page))
    canvas.restoreState()

def build_notes(catalog, output: Path, styles_map):
    topic_count = sum(len(subject['chapters']) for subject in catalog.values())
    question_count = sum(len(chapter['questions']) for subject in catalog.values() for chapter in subject['chapters'])
    story = [
        Spacer(1, 28*mm),
        Paragraph(rtl("جزوه‌های خلاصه و نکته‌ای"), styles_map["title"]),
        Paragraph(rtl("فهمینو | پایه هشتم | نسخهٔ تولیدشده از محتوای ثبت‌شده در برنامه"), styles_map["subtitle"]),
        HRFlowable(width="100%", thickness=1, color=colors.HexColor("#C7D2FE")),
        Spacer(1, 8*mm),
        Paragraph(rtl("توضیح دربارهٔ پوشش محتوا"), styles_map["chapter"]),
        Paragraph(rtl(f"این نسخه شامل {topic_count} موضوع آموزشی از {len(catalog)} درس است. با این حال، عنوان و ترتیب برخی موضوع‌ها و پوشش تمام صفحات کتاب‌های رسمی هنوز تطبیق نهایی نشده است؛ بنابراین این فایل را جزوهٔ منتخب و تألیفی بدان، نه جایگزین کامل کتاب درسی."), styles_map["body"]),
        Paragraph(rtl("مطالب این فایل تألیفی و آموزشی‌اند؛ برای تطبیق نهایی سرفصل‌ها باید نسخهٔ رسمی کتاب همان سال بررسی شود."), styles_map["body"]),
        PageBreak(),
    ]
    for subject in catalog.values():
        story.append(Paragraph(rtl(subject["title"]), styles_map["subject"]))
        for chapter in subject["chapters"]:
            story.append(Paragraph(rtl(chapter["title"]), styles_map["chapter"]))
            story.append(Paragraph(rtl(chapter["summary"]), styles_map["body"]))
            if chapter["points"]:
                story.append(Paragraph(rtl("نکته‌های کلیدی"), styles_map["question"]))
                for point in chapter["points"]:
                    story.append(Paragraph(rtl("• " + point), styles_map["body"]))
            if chapter.get("example"):
                story.append(Paragraph(rtl("مثال آموزشی: " + chapter["example"]), styles_map["question"]))
            if chapter["solutionSteps"]:
                story.append(Paragraph(rtl("حل مرحله‌به‌مرحله"), styles_map["question"]))
                for i, step in enumerate(chapter["solutionSteps"], 1):
                    story.append(Paragraph(rtl(f"{i}. {step}"), styles_map["body"]))
        story.append(Spacer(1, 4*mm))
    doc = SimpleDocTemplate(str(output), pagesize=A4, rightMargin=18*mm, leftMargin=18*mm,
                            topMargin=18*mm, bottomMargin=20*mm, title="Fahmino Grade 8 Notes")
    doc.build(story, onFirstPage=page_footer, onLaterPages=page_footer)

def build_questions(catalog, output: Path, styles_map):
    topic_count = sum(len(subject['chapters']) for subject in catalog.values())
    question_count = sum(len(chapter['questions']) for subject in catalog.values() for chapter in subject['chapters'])
    story = [
        Spacer(1, 28*mm),
        Paragraph(rtl("نمونه‌سؤال و آزمونک‌های آموزشی"), styles_map["title"]),
        Paragraph(rtl("فهمینو | پایه هشتم | پرسش‌های تألیفی بر اساس محتوای فعلی برنامه"), styles_map["subtitle"]),
        HRFlowable(width="100%", thickness=1, color=colors.HexColor("#C7D2FE")),
        Spacer(1, 8*mm),
        Paragraph(rtl("راهنما: ابتدا سؤال‌ها را بدون نگاه کردن به پاسخ‌نامه حل کن. پاسخ‌نامه و توضیح‌ها در بخش پایانی آمده‌اند."), styles_map["body"]),
        Paragraph(rtl(f"این نسخه شامل {question_count} پرسش تألیفی در {topic_count} موضوع است. پرسش‌ها نمونه‌های تمرینی‌اند و جایگزین همهٔ تمرین‌ها و آزمون‌های کتاب رسمی نیستند."), styles_map["body"]),
        PageBreak(),
    ]
    answer_rows = []
    letters = ["الف", "ب", "پ", "ت", "ث", "ج"]
    number = 0
    for subject in catalog.values():
        story.append(Paragraph(rtl(subject["title"]), styles_map["subject"]))
        for chapter in subject["chapters"]:
            story.append(Paragraph(rtl(chapter["title"]), styles_map["chapter"]))
            for question in chapter["questions"]:
                number += 1
                story.append(Paragraph(rtl(f"{number}. {question['question']}"), styles_map["question"]))
                for idx, option in enumerate(question["options"]):
                    label = letters[idx] if idx < len(letters) else str(idx+1)
                    story.append(Paragraph(rtl(f"{label}) {option}"), styles_map["option"]))
                story.append(Spacer(1, 2*mm))
                answer_rows.append((number, subject["title"], chapter["title"], question))
    story.append(PageBreak())
    story.append(Paragraph(rtl("پاسخ‌نامه و توضیح"), styles_map["title"]))
    for num, subject_title, chapter_title, question in answer_rows:
        answer = question["answer"]
        answer_text = question["options"][answer]
        story.append(KeepTogether([
            Paragraph(rtl(f"{num}. {subject_title} — {chapter_title}"), styles_map["question"]),
            Paragraph(rtl("پاسخ درست: " + answer_text), styles_map["body"]),
            Paragraph(rtl("توضیح: " + question["explanation"]), styles_map["body"]),
            Spacer(1, 2*mm),
        ]))
    doc = SimpleDocTemplate(str(output), pagesize=A4, rightMargin=18*mm, leftMargin=18*mm,
                            topMargin=18*mm, bottomMargin=20*mm, title="Fahmino Grade 8 Sample Questions")
    doc.build(story, onFirstPage=page_footer, onLaterPages=page_footer)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="assets/content/catalog_fa.json")
    parser.add_argument("--font-dir", default="assets/fonts/Vazirmatn")
    parser.add_argument("--output-dir", default="build/learning-pdfs")
    args = parser.parse_args()
    catalog = load_catalog(Path(args.catalog))
    font_dir = Path(args.font_dir)
    pdfmetrics.registerFont(TTFont("Vazirmatn", str(font_dir / "Vazirmatn-Regular.ttf")))
    pdfmetrics.registerFont(TTFont("Vazirmatn-SemiBold", str(font_dir / "Vazirmatn-SemiBold.ttf")))
    pdfmetrics.registerFont(TTFont("Vazirmatn-Bold", str(font_dir / "Vazirmatn-Bold.ttf")))
    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)
    style_map = styles()
    build_notes(catalog, out / "Fahmino-Grade8-Notes-FA.pdf", style_map)
    build_questions(catalog, out / "Fahmino-Grade8-Sample-Questions-FA.pdf", style_map)
    print(f"Generated 2 PDFs for {len(catalog)} subjects.")

if __name__ == "__main__":
    main()
