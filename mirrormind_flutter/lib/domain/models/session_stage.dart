/// Represents the sequential stages of a MirrorMind session.
enum SessionStage {
  welcome,
  mirror,
  shift,
  arrive,
  complete;

  /// Creates a [SessionStage] from its string name.
  ///
  /// Falls back to [SessionStage.welcome] if the value is not recognized.
  factory SessionStage.fromString(String value) {
    return SessionStage.values.firstWhere(
      (stage) => stage.name == value,
      orElse: () => SessionStage.welcome,
    );
  }
}
