{{flutter_js}}
{{flutter_build_config}}
// Taskwise: CanvasKit from the app's own files instead of Google's CDN, so
// the app starts offline (sw.js keeps them) and no third party sees a visit.
// The same for fonts: the engine always loads Roboto (its default font) from
// fontFallbackBaseUrl, which is fonts.gstatic.com unless set; it's in
// fallback-fonts/ (OFL-Roboto.txt). Every text of the app uses the bundled
// fonts, so the engine never needs another fallback font (one it looked
// for would be missing here, not fetched from Google).
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
    fontFallbackBaseUrl: 'fallback-fonts/',
  },
});
