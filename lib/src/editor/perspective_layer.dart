import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'edit_action_details.dart';
import 'editor_config.dart';

class PerspectiveLayer extends StatefulWidget {
  const PerspectiveLayer({
    super.key,
    required this.editActionDetails,
    required this.editorConfig,
    required this.layoutRect,
  });
  final EditActionDetails editActionDetails;
  final EditorConfig editorConfig;
  final Rect layoutRect;
  @override
  State<PerspectiveLayer> createState() => _PerspectiveLayerState();
}

class _PerspectiveLayerState extends State<PerspectiveLayer> {
  Rect get layoutRect => widget.layoutRect;

  Rect? get cropRect => widget.editActionDetails.cropRect;
  set cropRect(Rect? value) {
    widget.editActionDetails.cropRect = value;
    widget.editorConfig.editActionDetailsIsChanged
        ?.call(widget.editActionDetails);
  }

  List<Offset> get _points => widget.editActionDetails.perspectivePoints;
  bool _pointerDown = false;
  @override
  void initState() {
    super.initState();
    widget.editActionDetails.perspectivePoints = [
      cropRect!.topLeft,
      cropRect!.topRight,
      cropRect!.bottomRight,
      cropRect!.bottomLeft,
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (cropRect == null) {
      return Container();
    }
    final EditorConfig editConfig = widget.editorConfig;
    final Color primaryColor = Theme.of(context).primaryColor;

    final Color cornerColor = editConfig.cornerColor ?? primaryColor;

    final Color maskColor = widget.editorConfig.editorMaskColorHandler
            ?.call(context, _pointerDown) ??
        defaultEditorMaskColorHandler(context, _pointerDown);
    final double gWidth = widget.editorConfig.hitTestSize;

    return Stack(
      children: <Widget>[
        // top left
        Positioned(
          top: _points[0].dy - gWidth,
          left: _points[0].dx - gWidth,
          child: Container(
            height: gWidth * 2,
            width: gWidth * 2,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (DragUpdateDetails details) {
                setState(() {
                  _points[0] = _points[0] + details.delta;
                });
              },
              onPanEnd: (_) {},
            ),
          ),
        ),
        Positioned(
          top: _points[0].dy - gWidth,
          left: (_points[0].dx + _points[1].dx) / 2 - gWidth,
          child: Container(
            height: gWidth * 2,
            width: gWidth * 2,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (DragUpdateDetails details) {
                setState(() {
                  _points[0] =
                      Offset(_points[0].dx, _points[0].dy + details.delta.dy);

                  _points[1] =
                      Offset(_points[1].dx, _points[1].dy + details.delta.dy);
                });
              },
              onPanEnd: (_) {},
            ),
          ),
        ),
        //top right
        Positioned(
          top: _points[1].dy - gWidth,
          left: _points[1].dx - gWidth,
          child: Container(
            height: gWidth * 2,
            width: gWidth * 2,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (DragUpdateDetails details) {
                setState(() {
                  _points[1] = _points[1] + details.delta;
                });
              },
              onPanEnd: (_) {},
            ),
          ),
        ),
        //bottom right
        Positioned(
          top: _points[2].dy - gWidth,
          left: _points[2].dx - gWidth,
          child: Container(
            height: gWidth * 2,
            width: gWidth * 2,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (DragUpdateDetails details) {
                setState(() {
                  _points[2] = _points[2] + details.delta;
                });
              },
              onPanEnd: (_) {},
            ),
          ),
        ),
        // bottom left
        Positioned(
          top: _points[3].dy - gWidth,
          left: _points[3].dx - gWidth,
          child: Container(
            height: gWidth * 2,
            width: gWidth * 2,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (DragUpdateDetails details) {
                setState(() {
                  _points[3] = _points[3] + details.delta;
                });
              },
              onPanEnd: (_) {},
            ),
          ),
        ),
      ],
    );
  }
}
