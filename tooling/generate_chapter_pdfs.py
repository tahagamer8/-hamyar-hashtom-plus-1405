#!/usr/bin/env python3
"""Build separate offline PDFs for every grade-eight lesson/chapter.

The generated material is authored from Fahmino's checked subject packs. It is
not a reproduction of Hamyar/Paadars PDFs; those remain separately linked as
external sources in the app's PDF library.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak, KeepTogether, HRFlowable,
)

from generate_learning_pdfs import load_subjects, rtl, styles, footer, add_chapter_notes

LETTERS = ["الف", "ب", "پ", "ت", "ث", "ج", "چ", "ح"]


def register_fonts(font_dir: Path) -> None:
    pdfmetrics.registerFont(TTFont("Vazirmatn", str(font_dir / "Vazirmatn-Regular.ttf")))
    pdfmetrics.registerFont(TTFont("Vazirmatn-SemiBold", str(font_dir / "Vazirmatn-SemiBold.ttf")))
    pdfmetrics.registerFont(TTFont("Vazirmatn-Bold", str(font_dir / "Vazirmatn-Bold.ttf")))


def build_notes_pdf(subject: dict, chapter: dict, output: Path, st: dict) -> None:
    story = [
        Spacer(1, 12 * mm),
        Paragraph(rtl(subject["title"]), st["title"]),
        Paragraph(rtl("جزوهٔ آموزشی فصل | فهمینو | پایه هشتم"), st["subtitle"]),
        HRFlowable(width="100%", thickness=1, color=colors.HexColor("#C7D2FE")),
        Spacer(1, 5 * mm),
        Paragraph(
            rtl("این جزوهٔ آفلاین از محتوای آموزشی فعلی فهمینو تهیه شده و جایگزین متن کامل کتاب درسی یا فعالیت‌های رسمی آن نیست."),
            st["note"],
        ),
    ]
    add_chapter_notes(story, chapter, st)
    doc = SimpleDocTemplate(
        str(output), pagesize=A4, rightMargin=18 * mm, leftMargin=18 * mm,
        topMargin=17 * mm, bottomMargin=20 * mm,
        title=f"Fahmino {subject['title']} - {chapter['title']} - Notes",
    )
    doc.build(story, onFirstPage=footer, onLaterPages=footer)


def build_questions_pdf(subject: dict, chapter: dict, output: Path, st: dict) -> None:
    questions = [
        (q, "سؤال تمرینی")
        for q in chapter.get("questions", [])
    ] + [
        (q, "سؤال چالشی")
        for q in chapter.get("advancedQuestions", [])
    ]
    story = [
        Spacer(1, 10 * mm),
        Paragraph(rtl(subject["title"]), st["title"]),
        Paragraph(rtl("نمونه‌سؤال‌های فصل | فهمینو | پایه هشتم"), st["subtitle"]),
        Paragraph(rtl(chapter["title"]), st["chapter"]),
        Paragraph(rtl(f"{len(questions)} سؤال چهارگزینه‌ای؛ پاسخ‌نامه در انتهای فایل قرار دارد."), st["note"]),
        HRFlowable(width="100%", thickness=1, color=colors.HexColor("#C7D2FE")),
        Spacer(1, 4 * mm),
    ]
    for number, (question, kind) in enumerate(questions, 1):
        block = [
            Paragraph(rtl(f"{number}. {question['question']}"), st["question"]),
            Paragraph(rtl(kind), st["note"]),
        ]
        for index, option in enumerate(question["options"]):
            letter = LETTERS[index] if index < len(LETTERS) else str(index + 1)
            block.append(Paragraph(rtl(f"{letter}) {option}"), st["option"]))
        story.append(KeepTogether(block))
        story.append(Spacer(1, 2 * mm))

    story.extend([
        PageBreak(),
        Paragraph(rtl("پاسخ‌نامه و توضیح‌ها"), st["title"]),
        Paragraph(rtl(chapter["title"]), st["subtitle"]),
    ])
    for number, (question, kind) in enumerate(questions, 1):
        answer = question["options"][question["answer"]]
        story.append(KeepTogether([
            Paragraph(rtl(f"{number}. {kind}"), st["question"]),
            Paragraph(rtl("پاسخ درست: " + answer), st["body"]),
            Paragraph(rtl("توضیح: " + question["explanation"]), st["body"]),
            Spacer(1, 3 * mm),
        ]))
    doc = SimpleDocTemplate(
        str(output), pagesize=A4, rightMargin=18 * mm, leftMargin=18 * mm,
        topMargin=17 * mm, bottomMargin=20 * mm,
        title=f"Fahmino {subject['title']} - {chapter['title']} - Questions",
    )
    doc.build(story, onFirstPage=footer, onLaterPages=footer)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--subjects-dir", default="assets/content/subjects")
    parser.add_argument("--font-dir", default="assets/fonts/Vazirmatn")
    parser.add_argument("--output-dir", default="assets/generated_pdfs")
    args = parser.parse_args()

    subjects = load_subjects(Path(args.subjects_dir))
    register_fonts(Path(args.font_dir))
    st = styles()
    output_root = Path(args.output_dir) / "chapters"
    generated = 0
    chapter_count = 0

    for subject_id, subject in subjects.items():
        subject_dir = output_root / subject_id
        subject_dir.mkdir(parents=True, exist_ok=True)
        for index, chapter in enumerate(subject["chapters"], start=1):
            if not chapter.get("questions"):
                raise ValueError(f"No standard questions: {subject_id}/chapter {index}")
            if not chapter.get("advancedQuestions"):
                raise ValueError(f"No advanced questions: {subject_id}/chapter {index}")
            stem = f"Fahmino-{subject_id}-Chapter-{index}"
            build_notes_pdf(subject, chapter, subject_dir / f"{stem}-Notes-FA.pdf", st)
            build_questions_pdf(subject, chapter, subject_dir / f"{stem}-Questions-FA.pdf", st)
            generated += 2
            chapter_count += 1

    expected = sum(len(subject["chapters"]) for subject in subjects.values()) * 2
    if generated != expected:
        raise RuntimeError(f"Expected {expected} chapter PDFs, generated {generated}")
    print(f"Generated {generated} chapter PDFs for {chapter_count} chapters across {len(subjects)} subjects.")


if __name__ == "__main__":
    main()
