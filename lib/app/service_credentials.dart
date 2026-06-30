class AppServiceCredentials {
  const AppServiceCredentials({
    this.foodDataCentralApiKey = const String.fromEnvironment(
      'AI_NUTRITION_FOODDATA_CENTRAL_API_KEY',
    ),
  });

  final String foodDataCentralApiKey;

  String? get configuredFoodDataCentralApiKey {
    final trimmed = foodDataCentralApiKey.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool get hasFoodDataCentralApiKey => configuredFoodDataCentralApiKey != null;
}
