/// Helpers for recovering readable content out of protocol blocks that the XML renderer could not
/// classify.
///
/// Why this exists: a chat part is rendered through an XML block renderer, and that renderer used to
/// fall back to "show the raw text" whenever the tag name was unknown. When the block is really
/// protocol markup (a stream boundary cut the opening tag in half, or the tag name is malformed),
/// that fallback printed `<tool …>`, `<param …>`, `</tool_result>` straight into the transcript.
/// Users reported it as a leak; on device it looked like pages of raw XML in the chat.
///
/// The rule these helpers implement: never show the markup itself. Show the `<content>` payload if
/// there is one, otherwise show nothing.
library;

/// Tag names that only ever appear in protocol markup, never in prose the user should read.
const List<String> _protocolTags = <String>[
  'tool',
  'tool_call',
  'tool_calls',
  'tool_result',
  'param',
  'parameter',
  'content',
  'invoke',
  'result',
  'status',
];

final RegExp _protocolMarkupPattern = RegExp(
  '</?(?:${_protocolTags.join('|')})\\b',
  caseSensitive: false,
);

final RegExp _contentPattern = RegExp(
  r'<content>([\s\S]*?)</content>',
  caseSensitive: false,
);

/// True when [value] is protocol markup rather than ordinary text.
bool looksLikeProtocolMarkup(String value) => _protocolMarkupPattern.hasMatch(value);

/// Returns the readable payload of a protocol block, or null when it has none.
///
/// The payload is entity-decoded because protocol payloads are XML-escaped.
String? protocolMarkupPayload(String value) {
  if (!looksLikeProtocolMarkup(value)) {
    return null;
  }
  final match = _contentPattern.firstMatch(value);
  final raw = match?.group(1)?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return unescapeProtocolEntities(raw);
}

/// Minimal XML entity decoding for recovered payloads.
String unescapeProtocolEntities(String value) {
  return value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}
