import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Offers [text] to the browser as a download named [name].
void downloadTextFile({
  required String name,
  required String text,
  required String mimeType,
}) {
  final blob = web.Blob(
    [text.toJS].toJS,
    web.BlobPropertyBag(type: '$mimeType;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = name
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  // Not right away: Safari may not have started the download yet.
  Timer(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
}
