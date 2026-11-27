/// Never reached outside the browser.
void downloadTextFile({
  required String name,
  required String text,
  required String mimeType,
}) => throw UnsupportedError('Downloads need a browser');
