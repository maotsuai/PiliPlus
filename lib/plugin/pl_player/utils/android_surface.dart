/// The video controller is the only owner of mpv's Android output properties.
abstract interface class AndroidSurfaceTarget {
  bool attachExternalSurface(int surface, int width, int height);
  void detachExternalSurface();
}

typedef AndroidSurface = ({int id, int width, int height});

class AndroidSurfaceCoordinator implements AndroidSurfaceTarget {
  AndroidSurfaceCoordinator({required this.setProperty});

  final void Function(String name, String value) setProperty;
  AndroidSurface? _inline;
  AndroidSurface? _external;
  AndroidSurface? _applied;
  bool _suspended = false;

  void setInlineSurface(int id, int width, int height) {
    _inline = (id: id, width: width, height: height);
    _suspended = false;
    _apply();
  }

  void updateInlineSize(int width, int height) {
    if (_inline case final surface?) {
      _inline = (id: surface.id, width: width, height: height);
      _apply();
    }
  }

  @override
  bool attachExternalSurface(int surface, int width, int height) {
    if (surface == 0 || width <= 0 || height <= 0) return false;
    _external = (id: surface, width: width, height: height);
    _apply();
    return true;
  }

  @override
  void detachExternalSurface() {
    if (_external == null) return;
    _external = null;
    _apply();
  }

  /// Unload drops the old Surface; a reload keeps the selected destination.
  void suspend() {
    _suspended = true;
    _applied = null;
    setProperty('vo', 'null');
    setProperty('wid', '0');
  }

  void _apply() {
    final target = _external ?? _inline;
    if (_suspended ||
        target == null ||
        target.width <= 0 ||
        target.height <= 0 ||
        target == _applied) {
      return;
    }
    final switchingSurface = target.id != _applied?.id;
    if (switchingSurface) setProperty('vo', 'null');
    setProperty('android-surface-size', '${target.width}x${target.height}');
    if (switchingSurface) {
      setProperty('wid', target.id.toString());
      setProperty('vo', 'gpu');
    }
    _applied = target;
  }
}
