extension PersianDigitsString on String {
  String toPersianDigits() {
    const en = '0123456789';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    final buffer = StringBuffer();
    for (final rune in runes) {
      final ch = String.fromCharCode(rune);
      final index = en.indexOf(ch);
      buffer.write(index == -1 ? ch : fa[index]);
    }
    return buffer.toString();
  }
}

extension PersianDigitsInt on int {
  String toPersian() => toString().toPersianDigits();
}
