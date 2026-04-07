/// Centralized type coercion for SDUI prop values.
///
/// JSON deserialization and template resolution can produce values whose
/// runtime type doesn't match what widget builders expect (e.g. a number
/// arriving as a `String`, or an `int` where a `double` is needed).
///
/// Instead of scattering `as int?` / `num.tryParse` across every builder,
/// use `PropConverter.to<T>(value)` which returns `T?` after best-effort
/// coercion, or `null` if the value can't be converted.
///
/// Supported target types: `String`, `int`, `double`, `num`, `bool`,
/// `Map<String, dynamic>`.
abstract final class PropConverter {
  /// Convert [value] to target type [T], returning `null` on failure.
  ///
  /// ```dart
  /// PropConverter.to<double>(node.props['fontSize']) ?? 14.0
  /// PropConverter.to<int>(node.props['columns']) ?? 2
  /// PropConverter.to<String>(node.props['label']) ?? ''
  /// ```
  static T? to<T>(dynamic value) {
    if (value == null) return null;
    if (value is T) return value;

    // Dispatch to specialized converters
    if (T == int) return _toInt(value) as T?;
    if (T == double) return _toDouble(value) as T?;
    if (T == num) return _toNum(value) as T?;
    if (T == String) return _toString(value) as T?;
    if (T == bool) return _toBool(value) as T?;

    return null;
  }

  // -- Specialized converters --

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    if (value is bool) return value ? 1 : 0;
    return null;
  }

  static double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static num? _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  static String? _toString(dynamic value) {
    return value?.toString();
  }

  static bool? _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      if (value == 'true') return true;
      if (value == 'false') return false;
    }
    if (value is num) return value != 0;
    return null;
  }
}
