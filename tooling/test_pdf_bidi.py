import unittest

from tooling.generate_learning_pdfs import rtl


class PdfBidiTests(unittest.TestCase):
    def test_fraction_subtraction_keeps_operand_order(self):
        rendered = rtl("حاصل ۳/۴ − ۱/۲ کدام است؟")
        self.assertIn("۳/۴ − ۱/۲", rendered)
        self.assertNotIn("۱/۲ − ۳/۴", rendered)

    def test_equation_keeps_left_to_right_order(self):
        rendered = rtl("معادلهٔ ۳x+۵=۲۰ را حل کن.")
        self.assertIn("۳x+۵=۲۰", rendered)


if __name__ == "__main__":
    unittest.main()
