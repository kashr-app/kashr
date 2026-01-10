import 'package:flutter/widgets.dart';
import 'package:kashr/turnover/widgets/purpose_renderer.dart';

/// Fallback renderer that renders purpose text as plain text.
///
/// This renderer always succeeds and should be placed last in the renderer
/// chain.
class PlainTextRenderer implements PurposeRenderer {
  const PlainTextRenderer();

  @override
  Widget tryRender(
    BuildContext context,
    String purposeText, {
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return Text(
      purposeText,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
