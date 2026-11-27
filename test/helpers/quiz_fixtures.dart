import 'package:hamyar_hashtom_plus/features/quiz/domain/subject_pack.dart';

/// A well-formed raw question; the correct option is `n % 4`.
Map<String, dynamic> fixtureQuestion(int n) => {
      'question': 'پرسش شمارهٔ $n',
      'options': ['گزینهٔ الف', 'گزینهٔ ب', 'گزینهٔ ج', 'گزینهٔ د'],
      'answer': n % 4,
      'explanation': 'توضیح پرسش $n',
    };

/// Two subjects: math has 12 standard and 2 advanced questions, art has none.
List<SubjectPack> fixturePacks() => [
      SubjectPack(
        id: 'math',
        title: 'ریاضی',
        chapters: [
          {
            'title': 'فصل اول',
            'questions': [for (var i = 0; i < 6; i++) fixtureQuestion(i)],
            'advancedQuestions': [fixtureQuestion(10), fixtureQuestion(11)],
          },
          {
            'title': 'فصل دوم',
            'questions': [for (var i = 6; i < 12; i++) fixtureQuestion(i)],
          },
        ],
      ),
      const SubjectPack(
        id: 'art',
        title: 'هنر',
        chapters: [
          {'title': 'فصل هنر', 'questions': []},
        ],
      ),
    ];
