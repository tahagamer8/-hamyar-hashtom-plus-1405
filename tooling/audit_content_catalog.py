#!/usr/bin/env python3
"""Structural quality audit for Fahmino's authored grade-eight content catalog.

This tool validates data shape and consistency. It deliberately does not claim
that educational statements or answer keys are correct unless they are reviewed
against the matching official textbook edition by a human reviewer.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def audit(path: Path) -> tuple[list[str], dict[str, int]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    errors: list[str] = []
    subjects = chapters = questions = 0
    sourced_chapters = verified_chapters = learning_sections = book_solutions = 0
    seen_questions: dict[str, str] = {}

    if not isinstance(data, dict) or not data:
        return ["catalog must be a non-empty JSON object"], {}

    subjects = len(data)
    for subject_id, subject in data.items():
        if not isinstance(subject, dict):
            errors.append(f"{subject_id}: subject must be an object")
            continue
        if not isinstance(subject.get("title"), str) or not subject["title"].strip():
            errors.append(f"{subject_id}: missing subject title")
        items = subject.get("chapters")
        if not isinstance(items, list) or not items:
            errors.append(f"{subject_id}: chapters must be a non-empty list")
            continue
        local_titles: set[str] = set()
        for index, chapter in enumerate(items):
            label = f"{subject_id}/chapter-{index + 1}"
            chapters += 1
            if not isinstance(chapter, dict):
                errors.append(f"{label}: chapter must be an object")
                continue
            title = chapter.get("title")
            if not isinstance(title, str) or not title.strip():
                errors.append(f"{label}: missing title")
            elif title.strip() in local_titles:
                errors.append(f"{label}: duplicate chapter title {title!r}")
            else:
                local_titles.add(title.strip())

            for key in ("summary", "example"):
                if not isinstance(chapter.get(key), str) or not chapter[key].strip():
                    errors.append(f"{label}: {key} must be non-empty text")
            for key in ("points", "solutionSteps", "questions"):
                if not isinstance(chapter.get(key), list):
                    errors.append(f"{label}: {key} must be a list")

            for key in ("points", "solutionSteps"):
                values = chapter.get(key, [])
                if isinstance(values, list):
                    for item_index, value in enumerate(values):
                        if not isinstance(value, str) or not value.strip():
                            errors.append(f"{label}: {key}[{item_index}] is empty or not text")

            raw_sections = chapter.get("learningSections", [])
            if not isinstance(raw_sections, list):
                errors.append(f"{label}: learningSections must be a list")
                raw_sections = []
            learning_sections += len(raw_sections)
            for section_index, section in enumerate(raw_sections):
                section_label = f"{label}/section-{section_index + 1}"
                if not isinstance(section, dict):
                    errors.append(f"{section_label}: section must be an object")
                    continue
                if not isinstance(section.get("title"), str) or not section["title"].strip():
                    errors.append(f"{section_label}: title is missing")
                if not isinstance(section.get("content"), str) or not section["content"].strip():
                    errors.append(f"{section_label}: content is missing")
                for list_key in ("keyPoints", "examples"):
                    values = section.get(list_key, [])
                    if not isinstance(values, list) or any(
                        not isinstance(value, str) or not value.strip() for value in values
                    ):
                        errors.append(f"{section_label}: {list_key} must contain non-empty text items")
            raw_solutions = chapter.get("bookSolutions", [])
            if not isinstance(raw_solutions, list):
                errors.append(f"{label}: bookSolutions must be a list")
                raw_solutions = []
            book_solutions += len(raw_solutions)
            source = chapter.get("source")
            if isinstance(source, dict) and source.get("url"):
                sourced_chapters += 1
                if source.get("verified") is True and source.get("edition"):
                    verified_chapters += 1

            chapter_questions = chapter.get("questions", [])
            if not isinstance(chapter_questions, list):
                continue
            for q_index, question in enumerate(chapter_questions):
                questions += 1
                qlabel = f"{label}/question-{q_index + 1}"
                if not isinstance(question, dict):
                    errors.append(f"{qlabel}: question must be an object")
                    continue
                prompt = question.get("question")
                if not isinstance(prompt, str) or not prompt.strip():
                    errors.append(f"{qlabel}: question text is empty")
                else:
                    normalized = " ".join(prompt.split())
                    if normalized in seen_questions:
                        errors.append(f"{qlabel}: duplicate question also appears at {seen_questions[normalized]}")
                    else:
                        seen_questions[normalized] = qlabel

                options = question.get("options")
                if not isinstance(options, list) or len(options) < 2:
                    errors.append(f"{qlabel}: at least two options are required")
                    continue
                if any(not isinstance(option, str) or not option.strip() for option in options):
                    errors.append(f"{qlabel}: every option must be non-empty text")
                if len(set(options)) != len(options):
                    errors.append(f"{qlabel}: duplicate options")
                answer = question.get("answer")
                if type(answer) is not int or answer < 0 or answer >= len(options):
                    errors.append(f"{qlabel}: answer index is outside the options")
                if not isinstance(question.get("explanation"), str) or not question["explanation"].strip():
                    errors.append(f"{qlabel}: explanation is missing")

    stats = {
        "subjects": subjects,
        "chapters": chapters,
        "questions": questions,
        "chapters_with_source": sourced_chapters,
        "chapters_verified_against_edition": verified_chapters,
        "learning_sections": learning_sections,
        "book_solutions": book_solutions,
    }
    return errors, stats


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="assets/content/catalog_fa.json")
    parser.add_argument(
        "--require-verified-sources",
        action="store_true",
        help="fail unless every chapter has a verified source and edition",
    )
    args = parser.parse_args()

    errors, stats = audit(Path(args.catalog))
    for key, value in stats.items():
        print(f"{key}: {value}")
    if stats and stats["chapters"]:
        print(
            "source_coverage: "
            f"{stats['chapters_with_source']}/{stats['chapters']} "
            f"(verified: {stats['chapters_verified_against_edition']})"
        )
    if args.require_verified_sources and stats.get("chapters_verified_against_edition", 0) != stats.get("chapters", 0):
        errors.append("not every chapter is verified against a named textbook edition")

    if errors:
        print("\nCONTENT CATALOG ERRORS:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("\nStructural content audit passed. Educational accuracy still requires textbook review.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
