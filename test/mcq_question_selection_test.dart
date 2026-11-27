import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/features/quiz/data/mcq_history_store.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/mcq_level.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/mcq_question.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/quiz_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('McqQuestion.tryParse', () {
    test('accepts a well-formed question', () {
      final question =
          McqQuestion.tryParse(fixtureQuestion(2), chapterTitle: 'فصل اول');
      expect(question, isNotNull);
      expect(question!.answerIndex, 2);
      expect(question.options, hasLength(4));
      expect(question.chapterTitle, 'فصل اول');
      expect(question.explanation, isNotEmpty);
    });

    test('missing explanation becomes an empty string', () {
      final question = McqQuestion.tryParse(
        {
          'question': 'q',
          'options': ['a', 'b'],
          'answer': 1,
        },
        chapterTitle: 'c',
      );
      expect(question, isNotNull);
      expect(question!.explanation, '');
    });

    test('rejects malformed questions', () {
      final bad = <Object?>[
        null,
        'text',
        {
          'question': '',
          'options': ['a', 'b'],
          'answer': 0
        },
        {
          'question': 'q',
          'options': ['a'],
          'answer': 0
        },
        {
          'question': 'q',
          'options': ['a', 'b'],
          'answer': 2
        },
        {
          'question': 'q',
          'options': ['a', 1],
          'answer': 0
        },
        {
          'question': 'q',
          'options': ['a', 'b']
        },
      ];
      for (final item in bad) {
        expect(McqQuestion.tryParse(item, chapterTitle: 'c'), isNull);
      }
    });
  });

  group('selectBalancedQuestions', () {
    final all = [
      for (var c = 0; c < 6; c++)
        for (var i = 0; i < 3; i++)
          McqQuestion(
            chapterTitle: 'ch$c',
            prompt: 'q$c-$i',
            options: const ['a', 'b'],
            answerIndex: 0,
            explanation: '',
          ),
    ];

    test('draws one question per chapter before repeating a chapter', () {
      final picked = selectBalancedQuestions(all, limit: 6, random: Random(1));
      expect(picked, hasLength(6));
      expect(picked.map((q) => q.chapterTitle).toSet(), hasLength(6));
    });

    test('never exceeds the limit or the available questions', () {
      expect(
        selectBalancedQuestions(all, limit: 4, random: Random(2)),
        hasLength(4),
      );
      final everything =
          selectBalancedQuestions(all, limit: 100, random: Random(2));
      expect(everything, hasLength(18));
      expect(everything.map((q) => q.prompt).toSet(), hasLength(18));
    });

    test('returns nothing for a non-positive limit or no questions', () {
      expect(selectBalancedQuestions(all, limit: 0), isEmpty);
      expect(selectBalancedQuestions(const [], limit: 5), isEmpty);
    });

    test('is deterministic for the same seed', () {
      final a = selectBalancedQuestions(all, limit: 5, random: Random(3));
      final b = selectBalancedQuestions(all, limit: 5, random: Random(3));
      expect(a.map((q) => q.prompt), b.map((q) => q.prompt));
    });
  });

  group('McqLevel and SubjectPack', () {
    test('levels resolve by id and expose their question source', () {
      expect(McqLevel.fromId('easy'), McqLevel.easy);
      expect(McqLevel.fromId('sampad'), McqLevel.sampad);
      expect(McqLevel.fromId('nope'), isNull);
      expect(McqLevel.easy.hasQuestionSource, isFalse);
      expect(McqLevel.sampad.hasQuestionSource, isFalse);
      expect(McqLevel.intermediate.sourceKey, 'questions');
      expect(McqLevel.advanced.sourceKey, 'advancedQuestions');
    });

    test('packs count real questions per level', () {
      final math = fixturePacks().first;
      expect(math.countFor(McqLevel.intermediate), 12);
      expect(math.countFor(McqLevel.advanced), 2);
      expect(math.countFor(McqLevel.easy), 0);
      expect(math.countFor(McqLevel.sampad), 0);
      expect(math.examQuestions, hasLength(14));
      expect(fixturePacks().last.examQuestions, isEmpty);
    });
  });

  group('McqHistoryStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('saves newest first and keeps only the last attempts', () async {
      const store = McqHistoryStore();
      for (var i = 0; i < 25; i++) {
        await store.save(
          McqLevel.intermediate,
          'math',
          McqAttempt(date: DateTime(2026, 1, 1 + (i % 28)), score: i % 11, total: 10),
        );
      }
      final attempts = await store.load(McqLevel.intermediate, 'math');
      expect(attempts, hasLength(McqHistoryStore.maxEntries));
      expect(attempts.first.score, 24 % 11);
    });

    test('keeps levels and subjects separate and survives bad data', () async {
      SharedPreferences.setMockInitialValues({
        McqHistoryStore.keyFor(McqLevel.advanced, 'math'): ['not json', '{}'],
      });
      const store = McqHistoryStore();
      expect(await store.load(McqLevel.advanced, 'math'), isEmpty);
      expect(await store.load(McqLevel.intermediate, 'math'), isEmpty);
      await store.save(
        McqLevel.intermediate,
        'math',
        McqAttempt(date: DateTime(2026, 2, 2), score: 7, total: 10),
      );
      final saved = await store.load(McqLevel.intermediate, 'math');
      expect(saved.single.percent, 70);
      expect(await store.load(McqLevel.intermediate, 'art'), isEmpty);
    });
  });
}
