import 'package:ai_nutrition_companion/app/service_credentials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FoodData Central service key is app configuration only', () {
    const missing = AppServiceCredentials(foodDataCentralApiKey: '   ');
    const configured = AppServiceCredentials(
      foodDataCentralApiKey: ' configured-build-key ',
    );

    expect(missing.configuredFoodDataCentralApiKey, isNull);
    expect(missing.hasFoodDataCentralApiKey, isFalse);
    expect(configured.configuredFoodDataCentralApiKey, 'configured-build-key');
    expect(configured.hasFoodDataCentralApiKey, isTrue);
  });
}
