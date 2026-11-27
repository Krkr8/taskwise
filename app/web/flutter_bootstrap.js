{{flutter_js}}
{{flutter_build_config}}
// Taskwise: CanvasKit from the app's own files instead of Google's CDN, so
// the app starts offline (sw.js keeps them) and no third party sees a visit.
_flutter.loader.load({
  config: { canvasKitBaseUrl: 'canvaskit/' },
});
