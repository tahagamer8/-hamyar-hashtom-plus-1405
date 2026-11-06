import 'package:hamyar_hashtom_plus/features/subjects/domain/entities/subject.dart';
import 'package:hamyar_hashtom_plus/features/subjects/domain/repositories/subjects_repository.dart';

/// پیاده‌سازی موقت با داده ثابت.
/// در مرحله ۲ جایگزین خواندن از دیتابیس محلی (SQLite) می‌شود.
class SubjectsRepositoryImpl implements SubjectsRepository {
  const SubjectsRepositoryImpl();

  static const List<Subject> _subjects = [
    Subject(id: 'math', title: 'ریاضی', description: 'عدد، جبر و هندسه'),
    Subject(id: 'science', title: 'علوم تجربی', description: 'زیست، فیزیک و شیمی'),
    Subject(id: 'persian', title: 'فارسی', description: 'ادبیات و درک مطلب'),
    Subject(id: 'writing', title: 'نگارش', description: 'نوشتن و ویرایش'),
    Subject(id: 'arabic', title: 'عربی', description: 'واژگان و قواعد'),
    Subject(id: 'social', title: 'مطالعات اجتماعی', description: 'تاریخ، جغرافیا و مدنی'),
    Subject(id: 'english', title: 'زبان انگلیسی', description: 'گرامر و واژگان'),
    Subject(id: 'english_workbook', title: 'کتاب کار زبان انگلیسی', description: 'تمرین‌های هفت درس Prospect 2'),
    Subject(id: 'religion', title: 'پیام‌های آسمان', description: 'تعلیمات دینی'),
    Subject(id: 'quran', title: 'قرآن', description: 'روخوانی و مفاهیم'),
    Subject(id: 'thinking', title: 'تفکر و سبک زندگی', description: 'مهارت‌های زندگی'),
    Subject(id: 'work', title: 'کار و فناوری', description: 'مهارت و فناوری'),
    Subject(id: 'culture_art', title: 'فرهنگ و هنر', description: 'هنرهای تجسمی، سنتی، آوایی و نمایشی'),
  ];

  @override
  Future<List<Subject>> getSubjects() async => _subjects;

  @override
  Future<Subject?> getSubjectById(String id) async {
    for (final subject in _subjects) {
      if (subject.id == id) return subject;
    }
    return null;
  }
}
