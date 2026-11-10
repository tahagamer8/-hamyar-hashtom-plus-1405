import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/core/constants/app_constants.dart';
import 'package:hamyar_hashtom_plus/core/constants/app_feature.dart';

void main() {
  test('visible app version matches the 2.4.0 release', () {
    expect(AppConstants.appName, 'فهمینو');
    expect(AppConstants.appVersion, '2.4.0');
    expect(AppConstants.version, AppConstants.appVersion);
  });

  test('all subject features have unique routes and readable descriptions', () {
    final subjectFeatures =
        AppFeature.values.where((feature) => feature.isSubjectSection).toList();

    expect(subjectFeatures.map((feature) => feature.name).toSet(),
        hasLength(subjectFeatures.length));
    expect(subjectFeatures, contains(AppFeature.lessonQuestions));
    expect(subjectFeatures, contains(AppFeature.notes));
    expect(subjectFeatures, contains(AppFeature.sampleExams));
    expect(subjectFeatures.every((feature) =>
        feature.title.trim().isNotEmpty &&
        feature.description.trim().isNotEmpty), isTrue);
    expect(AppFeature.favorites.isSubjectSection, isFalse);
    expect(AppFeature.studyPlanner.isSubjectSection, isFalse);
    expect(AppFeature.mistakes.isSubjectSection, isFalse);
    expect(AppFeature.values.every((feature) =>
        feature.title.trim().isNotEmpty && feature.description.trim().isNotEmpty),
        isTrue);
  });
}
