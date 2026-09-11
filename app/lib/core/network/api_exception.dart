/// User-facing error surfaced from the local data layer (validation,
/// conflicts, not-found). Every repository throws these; screens catch
/// them generically and display `e.toString()`.
class ApiException implements Exception {
  ApiException(this.message, {this.fieldErrors = const {}});

  final String message;
  final Map<String, String> fieldErrors;

  @override
  String toString() => message;
}
