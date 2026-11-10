import json
import unittest
from pathlib import Path

from tooling.audit_content_quality import (
    audit_chapter,
    official_source_link_verified,
    pdf_parse_level,
)


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE_PATH = ROOT / "research" / "official-toc-audit-five-missing-books-1405-1406.json"


class OfficialTocEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = json.loads(EVIDENCE_PATH.read_text(encoding="utf-8"))
        cls.books = {book["subjectId"]: book for book in cls.report["books"]}

    def test_all_five_previously_missing_books_are_accounted_for(self):
        self.assertEqual(set(self.books), {"math", "persian", "writing", "quran", "religion"})
        self.assertEqual(self.report["schoolYear"], "1405-1406")

    def test_math_toc_has_nine_chapters_and_thirty_four_lessons(self):
        math = self.books["math"]
        self.assertEqual(math["tocStatus"], "complete_toc_extracted")
        self.assertEqual(math["chapterCount"], 9)
        self.assertEqual(math["lessonCount"], 34)
        self.assertEqual(len(math["chapters"]), 9)
        self.assertEqual(sum(len(chapter["lessons"]) for chapter in math["chapters"]), 34)

    def test_math_printed_page_ranges_are_ordered_and_lessons_fall_inside(self):
        chapters = self.books["math"]["chapters"]
        for index, chapter in enumerate(chapters):
            self.assertGreater(chapter["printedPageStart"], 0)
            self.assertGreaterEqual(chapter["printedPageEnd"], chapter["printedPageStart"])
            for lesson in chapter["lessons"]:
                self.assertGreaterEqual(lesson["printedPage"], chapter["printedPageStart"])
                self.assertLessEqual(lesson["printedPage"], chapter["printedPageEnd"])
            if index:
                self.assertEqual(chapters[index - 1]["printedPageEnd"] + 1, chapter["printedPageStart"])

    def test_no_physical_pdf_page_mapping_is_fabricated(self):
        for book in self.books.values():
            self.assertEqual(book["chapterMappingsVerified"], 0)
        for chapter in self.books["math"]["chapters"]:
            self.assertIsNone(chapter.get("physicalPdfPageStart"))
            self.assertIsNone(chapter.get("physicalPdfPageEnd"))

    def test_partial_and_failed_extractions_are_not_called_complete(self):
        self.assertEqual(self.books["persian"]["tocStatus"], "partial_ocr_rows_missing")
        self.assertEqual(self.books["quran"]["tocStatus"], "partial_ocr_missing_rows")
        self.assertEqual(self.books["religion"]["tocStatus"], "partial_table_layout_ocr_incomplete")
        self.assertEqual(self.books["writing"]["tocStatus"], "not_parsed")
        self.assertEqual(self.books["writing"]["pdfPagesParsed"], 0)

    def test_official_link_verification_is_separate_from_pdf_parse_depth(self):
        statuses = {
            "official_portal_record_and_pdf_link_verified_not_downloaded_or_parsed": "none",
            "official_pdf_toc_parsed_printed_pages_only": "toc_complete",
            "official_pdf_partially_parsed_toc_ocr_incomplete": "partial",
            "official_pdf_content_parsed": "full",
        }
        for status, expected_level in statuses.items():
            with self.subTest(status=status):
                source = {
                    "portalUrl": "https://chap.sch.ir/books/14220",
                    "pdfUrl": "https://chap.sch.ir/sites/default/files/lbooks/1405-1406/558/C805.pdf",
                    "bookCode": "805",
                    "schoolYear": "1405-1406",
                    "verificationStatus": status,
                }
                self.assertTrue(official_source_link_verified(source))
                self.assertEqual(pdf_parse_level(source), expected_level)

    def test_unofficial_or_incomplete_source_metadata_does_not_count_as_verified_link(self):
        source = {
            "portalUrl": "https://example.com/books/14220",
            "pdfUrl": "https://chap.sch.ir/sites/default/files/lbooks/1405-1406/558/C805.pdf",
            "bookCode": "805",
            "schoolYear": "1405-1406",
            "verificationStatus": "official_pdf_toc_parsed_printed_pages_only",
        }
        self.assertFalse(official_source_link_verified(source))

    def test_toc_only_parse_does_not_satisfy_strict_source_gate(self):
        statuses = (
            "official_pdf_toc_parsed_printed_pages_only",
            "official_pdf_partially_parsed_toc_ocr_incomplete",
        )
        for status in statuses:
            with self.subTest(status=status):
                pack = {
                    "textbookEdition": "چاپ سیزدهم ۱۴۰۵",
                    "textbookSourceFile": "C805.pdf",
                    "textbookSource": {
                        "pdfUrl": "https://chap.sch.ir/sites/default/files/lbooks/1405-1406/558/C805.pdf",
                        "schoolYear": "1405-1406",
                        "bookCode": "805",
                        "verificationStatus": status,
                    },
                }
                chapter = {
                    "title": "فصل آزمایشی",
                    "summary": "خلاصه",
                    "points": [],
                    "example": "مثال آموزشی",
                    "solutionSteps": [],
                    "commonMistakes": [],
                    "questions": [],
                }
                result = audit_chapter("sample", "نمونه", pack, chapter, 1)
                self.assertFalse(result["sourceMapped"])
                self.assertEqual(result["status"], "نیازمند منبع")

    def test_no_copyrighted_lesson_text_or_images_are_stored(self):
        copyright_record = self.report["copyright"]
        self.assertFalse(copyright_record["lessonProseStored"])
        self.assertFalse(copyright_record["pageImagesStored"])
        self.assertFalse(copyright_record["officialPdfsBundled"])


if __name__ == "__main__":
    unittest.main()
