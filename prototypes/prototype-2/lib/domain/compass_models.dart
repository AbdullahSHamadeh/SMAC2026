enum PrototypeIntent {
  draftFridayDinner,
  whereIsDad,
  explainStatusSource,
  markStatusOutdated,
  requestCheckIn,
  draftPlanChange,
  draftSeparateReminder,
}

class CompassAnswer {
  const CompassAnswer({
    required this.text,
    required this.sourceLabel,
    required this.freshnessLabel,
    required this.hasPermittedInformation,
    this.actionLabel,
  });

  final String text;
  final String sourceLabel;
  final String freshnessLabel;
  final bool hasPermittedInformation;
  final String? actionLabel;
}
