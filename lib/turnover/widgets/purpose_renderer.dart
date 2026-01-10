import 'package:flutter/widgets.dart';

/// Abstract interface for rendering transaction purpose text.
///
/// This allows plugging in different rendering strategies for various
/// use cases (e.g., detecting and linking order IDs from e-commerce platforms).
///
/// Renderers are tried in order, and the first one that can handle the text
/// will be used.
abstract class PurposeRenderer {
  /// Attempts to render the given purpose text.
  ///
  /// Returns a [Widget] if this renderer can handle the text, or `null` if
  /// it should be skipped and the next renderer in the chain should be tried.
  Widget? tryRender(
    BuildContext context,
    String purposeText, {
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
  });
}
