/// Runtime configuration.
///
/// The API base URL is injected at build time so the same source runs locally and on
/// Vercel without code changes:
///
///   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
///   flutter build web --release            # defaults to the relative /api path
library;

class AppConfig {
  const AppConfig._();

  /// Defaults to the same-origin `/api` path routed by `vercel.json`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '/api',
  );

  /// Budget for repository and chatbot calls, which answer from retrieved records.
  static const Duration requestTimeout = Duration(seconds: 25);

  /// Budget for `POST /api/proposal`. A full skeleton runs to a few thousand tokens on
  /// the provider, so the short query timeout would abort every draft mid-generation.
  static const Duration proposalTimeout = Duration(seconds: 120);
}
