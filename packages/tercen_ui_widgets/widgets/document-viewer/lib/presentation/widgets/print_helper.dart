import 'package:markdown/markdown.dart' as md;
import 'package:web/web.dart' as web;

/// Prints document content via the browser's native print dialog.
///
/// For markdown files, converts to styled HTML first.
/// For plain text, wraps in a <pre> block.
class PrintHelper {
  PrintHelper._();

  static void printMarkdown(String markdownContent, String title) {
    final htmlBody = md.markdownToHtml(
      markdownContent,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );
    _printHtml(htmlBody, title);
  }

  static void printPlainText(String textContent, String title) {
    final escaped = textContent
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    final htmlBody = '<pre style="white-space:pre-wrap;font-family:monospace;font-size:13px;">$escaped</pre>';
    _printHtml(htmlBody, title);
  }

  static void _printHtml(String bodyHtml, String title) {
    final html = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>$title</title>
<style>
  body {
    font-family: 'Fira Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    font-size: 14px;
    line-height: 1.6;
    color: #111827;
    max-width: 800px;
    margin: 0 auto;
    padding: 24px;
  }
  h1 { font-size: 24px; font-weight: 700; margin: 24px 0 12px; }
  h2 { font-size: 20px; font-weight: 600; margin: 20px 0 10px; }
  h3 { font-size: 16px; font-weight: 600; margin: 16px 0 8px; }
  p { margin: 8px 0; }
  code {
    font-family: monospace;
    font-size: 13px;
    background: #f1f5f9;
    padding: 2px 4px;
    border-radius: 3px;
  }
  pre {
    background: #f1f5f9;
    padding: 12px;
    border-radius: 6px;
    overflow-x: auto;
  }
  pre code { background: none; padding: 0; }
  blockquote {
    border-left: 3px solid #1e40af;
    margin: 8px 0;
    padding: 4px 0 4px 16px;
    color: #374151;
  }
  table { border-collapse: collapse; margin: 8px 0; }
  th, td { border: 1px solid #d1d5db; padding: 6px 12px; }
  th { font-weight: 600; }
  hr { border: none; border-top: 1px solid #d1d5db; margin: 16px 0; }
  a { color: #1e40af; }
  img { max-width: 100%; }
  ul, ol { padding-left: 24px; }
  @media print {
    body { padding: 0; }
  }
</style>
</head>
<body>$bodyHtml</body>
</html>
''';

    final printWindow = web.window.open('', '_blank');
    if (printWindow != null) {
      printWindow.document.write(html);
      printWindow.document.close();
      printWindow.print();
    }
  }
}
