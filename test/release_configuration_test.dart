import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String readFile(String path) => File(path).readAsStringSync();

void main() {
  group('release configuration', () {
    test('Android uses production-shaped identifiers and release signing', () {
      final gradle = readFile('android/app/build.gradle.kts');
      final manifest = readFile('android/app/src/main/AndroidManifest.xml');
      final strings = readFile('android/app/src/main/res/values/strings.xml');
      final mainActivity = readFile(
        'android/app/src/main/kotlin/app/ainutrition/companion/MainActivity.kt',
      );

      expect(gradle, contains('namespace = "app.ainutrition.companion"'));
      expect(gradle, contains('AI_NUTRITION_ANDROID_APPLICATION_ID'));
      expect(gradle, contains('applicationId = androidApplicationId'));
      expect(gradle, contains('create("release")'));
      expect(gradle, contains('signingConfigs.getByName("release")'));
      expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
      expect(gradle, isNot(contains('com.example.ai_nutrition_companion')));

      expect(manifest, contains('android:label="@string/app_name"'));
      expect(
        manifest,
        contains('android:name="app.ainutrition.companion.MainActivity"'),
      );
      expect(strings, contains('AI Nutrition Companion'));
      expect(mainActivity, contains('package app.ainutrition.companion'));
      expect(
        File(
          'android/app/src/main/kotlin/com/example/ai_nutrition_companion/MainActivity.kt',
        ).existsSync(),
        isFalse,
      );
    });

    test('iOS bundle id and display name are release-ready placeholders', () {
      final project = readFile('ios/Runner.xcodeproj/project.pbxproj');
      final debugConfig = readFile('ios/Flutter/Debug.xcconfig');
      final releaseConfig = readFile('ios/Flutter/Release.xcconfig');
      final infoPlist = readFile('ios/Runner/Info.plist');

      expect(
        project,
        contains(
          r'PRODUCT_BUNDLE_IDENTIFIER = "$(AI_NUTRITION_IOS_BUNDLE_ID)"',
        ),
      );
      expect(
        project,
        contains(
          r'PRODUCT_BUNDLE_IDENTIFIER = "$(AI_NUTRITION_IOS_BUNDLE_ID).RunnerTests"',
        ),
      );
      expect(
        project,
        contains(r'DEVELOPMENT_TEAM = "$(AI_NUTRITION_IOS_DEVELOPMENT_TEAM)"'),
      );
      expect(project, isNot(contains('com.example.aiNutritionCompanion')));

      for (final config in [debugConfig, releaseConfig]) {
        expect(
          config,
          contains('AI_NUTRITION_IOS_BUNDLE_ID=app.ainutrition.companion'),
        );
        expect(config, contains('AI_NUTRITION_IOS_DEVELOPMENT_TEAM='));
      }

      expect(infoPlist, contains('<string>AI Nutrition Companion</string>'));
      expect(infoPlist, contains('<string>AI Nutrition</string>'));
    });

    test('release documentation matches signing boundaries', () {
      final docs = readFile('docs/release-readiness.md');
      final gitignore = readFile('.gitignore');

      expect(docs, contains('app.ainutrition.companion'));
      expect(docs, contains('AI_NUTRITION_ANDROID_APPLICATION_ID'));
      expect(docs, contains('AI_NUTRITION_IOS_BUNDLE_ID'));
      expect(docs, contains('AI_NUTRITION_IOS_DEVELOPMENT_TEAM'));
      expect(docs, contains('android/key.properties'));
      expect(docs, contains('The release build must not'));
      expect(docs, contains('use debug signing.'));
      expect(gitignore, contains('/android/key.properties'));
      expect(gitignore, contains('/android/*.jks'));
      expect(gitignore, contains('/android/*.keystore'));
    });
  });
}
