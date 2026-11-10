import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE_PATH = ROOT / "research" / "official-toc-audit-five-missing-books-1405-1406.json"
PERSIAN_PACK_PATH = ROOT / "assets" / "content" / "subjects" / "persian.json"


class PersianOfficialPdfCoverageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.evidence = json.loads(EVIDENCE_PATH.read_text(encoding="utf-8"))
        cls.persian_evidence = next(
            book for book in cls.evidence["books"] if book["subjectId"] == "persian"
        )
        cls.persian_pack = json.loads(PERSIAN_PACK_PATH.read_text(encoding="utf-8"))
        cls.source = cls.persian_pack["textbookSource"]

    def test_persian_pdf_page_extraction_count_matches_full_official_pdf(self):
        # The official C803 PDF was parsed successfully as 144/144 pages.
        self.assertEqual(self.persian_evidence["pdfTotalPages"], 144)
        self.assertEqual(self.persian_evidence["pdfPagesParsed"], 144)
        self.assertEqual(self.source["pdfTotalPages"], 144)
        self.assertEqual(self.source["pdfPagesParsed"], 144)

    def test_full_page_extraction_does_not_overstate_toc_or_chapter_mapping(self):
        self.assertEqual(self.persian_evidence["parserStatus"], "parsed")
        self.assertEqual(
            self.persian_evidence["tocStatus"], "partial_ocr_rows_missing"
        )
        self.assertEqual(self.persian_evidence["chapterMappingsVerified"], 0)
        self.assertEqual(
            self.source["tocExtractionStatus"], "partial_ocr_rows_missing"
        )
        self.assertEqual(
            self.source["physicalPdfPageMappingStatus"], "not_verified"
        )
        self.assertNotIn("officialTextbookMapping", self.persian_pack["chapters"][0])

    def test_persian_source_is_pinned_to_official_1405_1406_edition(self):
        self.assertEqual(self.evidence["schoolYear"], "1405-1406")
        self.assertEqual(self.source["bookCode"], "803")
        self.assertEqual(self.source["schoolYear"], "1405-1406")
        self.assertEqual(
            self.source["pdfUrl"],
            "http://chap.sch.ir/sites/default/files/lbooks/1405-1406/558/C803.pdf",
        )

    def test_no_textbook_body_or_images_are_added_to_the_repository(self):
        copyright_record = self.evidence["copyright"]
        self.assertFalse(copyright_record["lessonProseStored"])
        self.assertFalse(copyright_record["pageImagesStored"])
        self.assertFalse(copyright_record["officialPdfsBundled"])


if __name__ == "__main__":
    unittest.main()
