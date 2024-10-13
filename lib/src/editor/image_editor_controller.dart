part of 'editor.dart';

class ImageEditorController extends ChangeNotifier
    with ImageEditorControllerMixin {
  ExtendedImageEditorState? _state;
  ExtendedImageEditorState? get state => _state;

  double get rotateAngle => _state?._editActionDetails?.rotateAngle ?? 0;

  @override
  void flip({
    bool animation = false,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    _state?.flip(animation: animation, duration: duration);
  }

  @override
  void redo() {
    _state?.redo();
  }

  @override
  void reset() {
    _state?.reset();
  }

  @override
  void rotate({
    double angle = 90,
    bool animation = false,
    Duration? duration,
    bool rotateCropRect = false,
  }) {
    _state?.rotate(
      angle: angle,
      animation: animation,
      duration: duration,
      rotateCropRect: rotateCropRect,
    );
  }

  @override
  void undo() {
    _state?.undo();
  }

  @override
  bool get canRedo => _state?.canRedo ?? false;

  @override
  bool get canUndo => _state?.canUndo ?? false;

  /// notifyListeners
  void _notifyListeners() {
    notifyListeners();
  }
}

mixin ImageEditorControllerMixin {
  void rotate({
    double angle = 90,
    bool animation = false,
    Duration? duration,
    bool rotateCropRect = false,
  });

  void flip({
    bool animation = false,
    Duration duration = const Duration(milliseconds: 500),
  });

  void reset();

  void undo();

  void redo();

  bool get canUndo;

  bool get canRedo;
}
