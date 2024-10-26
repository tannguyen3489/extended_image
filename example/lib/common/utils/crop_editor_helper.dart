//import 'dart:typed_data';
import 'dart:isolate';
import 'dart:ui';

// import 'package:isolate/load_balancer.dart';
// import 'package:isolate/isolate_runner.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
// ignore: implementation_imports
import 'package:http_client_helper/http_client_helper.dart';
import 'package:image/image.dart';
import 'package:image_editor/image_editor.dart';
import 'package:image/image.dart' as img;
import 'dart:math';
import '../../pages/complex/image_editor_demo.dart';

// final Future<LoadBalancer> loadBalancer =
//     LoadBalancer.create(1, IsolateRunner.spawn);

enum ImageType { gif, jpg }

class EditImageInfo {
  EditImageInfo(
    this.data,
    this.imageType,
  );
  final Uint8List? data;
  final ImageType imageType;
}

Future<EditImageInfo> cropImageDataWithDartLibrary(
    ImageEditorController imageEditorController) async {
  print('dart library start cropping');

  ///crop rect base on raw image
  Rect cropRect = imageEditorController.getCropRect()!;
  final ExtendedImageEditorState state = imageEditorController.state!;
  var editorCropLayerPainter = state.editorCropLayerPainter;


  print('getCropRect : $cropRect');

  // in web, we can't get rawImageData due to .
  // using following code to get imageCodec without download it.
  // final Uri resolved = Uri.base.resolve(key.url);
  // // This API only exists in the web engine implementation and is not
  // // contained in the analyzer summary for Flutter.
  // return ui.webOnlyInstantiateImageCodecFromUrl(
  //     resolved); //

  final Uint8List data = kIsWeb &&
          imageEditorController.state!.widget.extendedImageState.imageWidget
              .image is ExtendedNetworkImageProvider
      ? await _loadNetwork(imageEditorController.state!.widget
          .extendedImageState.imageWidget.image as ExtendedNetworkImageProvider)

      ///toByteData is not work on web
      ///https://github.com/flutter/flutter/issues/44908
      // (await state.image.toByteData(format: ui.ImageByteFormat.png))
      //     .buffer
      //     .asUint8List()
      : state.rawImageData;

  if (data == state.rawImageData &&
      state.widget.extendedImageState.imageProvider is ExtendedResizeImage) {
    final ImmutableBuffer buffer =
        await ImmutableBuffer.fromUint8List(state.rawImageData);
    final ImageDescriptor descriptor = await ImageDescriptor.encoded(buffer);
    final double widthRatio = descriptor.width / state.image!.width;
    final double heightRatio = descriptor.height / state.image!.height;
    cropRect = Rect.fromLTRB(
      cropRect.left * widthRatio,
      cropRect.top * heightRatio,
      cropRect.right * widthRatio,
      cropRect.bottom * heightRatio,
    );


  }


  // continue crop by circle


  final EditActionDetails editAction = state.editAction!;

  final DateTime time1 = DateTime.now();

  //Decode source to Animation. It can holds multi frame.
  Image? src;
  //LoadBalancer lb;
  if (kIsWeb) {
    src = decodeImage(data);
  } else {
    src = await compute(decodeImage, data);
  }
  if (src != null) {
    //handle every frame.
    src.frames = src.frames.map((Image image) {
      final DateTime time2 = DateTime.now();
      //clear orientation
      image = bakeOrientation(image);
      if (editAction.hasRotateDegrees) {
        image = copyRotate(image, angle: editAction.rotateDegrees);
      }

      if (editAction.flipY) {
        image = flip(image, direction: FlipDirection.horizontal);
      }

      if (editAction.needCrop) {
        // image = copyCrop(
        //   image,
        //   x: cropRect.left.toInt(),
        //   y: cropRect.top.toInt(),
        //   width: cropRect.width.toInt(),
        //   height: cropRect.height.toInt(),
        // );

        // clip to circle
        // image = copyCropCircle(image);
        // image = cropCircle(image, cropRect);

        if (editorCropLayerPainter is CircleEditorCropLayerPainter) {
          int size = min(cropRect.width.toInt(), cropRect.height.toInt());
          // image = copyCrop(
          //   image,
          //   x: cropRect.left.toInt(),
          //   y: cropRect.top.toInt(),
          //   width: cropRect.width.toInt(),
          //   height: cropRect.height.toInt(),
          // );

          image = copyCropCircle(image, radius: size ~/ 2, centerX: cropRect.left.toInt() + cropRect.width.toInt() ~/ 2, centerY: cropRect.top.toInt() + cropRect.height.toInt() ~/ 2);
        } else if (editorCropLayerPainter is TriangleCropLayerPainter) {
          image = cropByTriangle(image);
        } else {
          image = copyCrop(
            image,
            x: cropRect.left.toInt(),
            y: cropRect.top.toInt(),
            width: cropRect.width.toInt(),
            height: cropRect.height.toInt(),
          );
        }

      }

      final DateTime time3 = DateTime.now();
      print('${time3.difference(time2)} : crop/flip/rotate');
      return image;
    }).toList();
    if (src.frames.length == 1) {}
  }

  /// you can encode your image
  ///
  /// it costs much time and blocks ui.
  //var fileData = encodeJpg(src);

  /// it will not block ui with using isolate.
  //var fileData = await compute(encodeJpg, src);
  //var fileData = await isolateEncodeImage(src);
  assert(src != null);
  List<int>? fileData;
  print('start encode');
  final DateTime time4 = DateTime.now();
  final bool onlyOneFrame = src!.numFrames == 1;

  //If there's only one frame, encode it to jpg.
  if (kIsWeb) {
    fileData =
        onlyOneFrame ? encodeJpg(Image.from(src.frames.first)) : encodeGif(src);
  } else {
    //fileData = await lb.run<List<int>, Image>(encodeJpg, src);
    fileData = (onlyOneFrame
        ? await compute(encodePng, Image.from(src.frames.first))
        : await compute(encodeGif, src));
  }

  final DateTime time5 = DateTime.now();
  print('${time5.difference(time4)} : encode');
  print('${time5.difference(time1)} : total time');
  return EditImageInfo(
    Uint8List.fromList(fileData!),
    onlyOneFrame ? ImageType.jpg : ImageType.gif,
  );
}

Future<EditImageInfo> cropImageDataWithNativeLibrary(
    ImageEditorController imageEditorController) async {
  print('native library start cropping');

  final EditActionDetails action = imageEditorController.editActionDetails!;

  final Uint8List img = imageEditorController.state!.rawImageData;

  final ImageEditorOption option = ImageEditorOption();

  if (action.hasRotateDegrees) {
    final int rotateDegrees = action.rotateDegrees.toInt();
    option.addOption(RotateOption(rotateDegrees));
  }
  if (action.flipY) {
    option.addOption(const FlipOption(horizontal: true, vertical: false));
  }

  if (action.needCrop) {
    Rect cropRect = imageEditorController.getCropRect()!;
    if (imageEditorController.state!.widget.extendedImageState.imageProvider
        is ExtendedResizeImage) {
      final ImmutableBuffer buffer = await ImmutableBuffer.fromUint8List(img);
      final ImageDescriptor descriptor = await ImageDescriptor.encoded(buffer);

      final double widthRatio =
          descriptor.width / imageEditorController.state!.image!.width;
      final double heightRatio =
          descriptor.height / imageEditorController.state!.image!.height;
      cropRect = Rect.fromLTRB(
        cropRect.left * widthRatio,
        cropRect.top * heightRatio,
        cropRect.right * widthRatio,
        cropRect.bottom * heightRatio,
      );
    }
    option.addOption(ClipOption.fromRect(cropRect));
  }

  final DateTime start = DateTime.now();
  final Uint8List? result = await ImageEditor.editImage(
    image: img,
    imageEditorOption: option,
  );

  print('${DateTime.now().difference(start)} ：total time');
  return EditImageInfo(result, ImageType.jpg);
}

Future<dynamic> isolateDecodeImage(List<int> data) async {
  final ReceivePort response = ReceivePort();
  await Isolate.spawn(_isolateDecodeImage, response.sendPort);
  final dynamic sendPort = await response.first;
  final ReceivePort answer = ReceivePort();
  // ignore: always_specify_types
  sendPort.send([answer.sendPort, data]);
  return answer.first;
}

Future<dynamic> isolateEncodeImage(Image src) async {
  final ReceivePort response = ReceivePort();
  await Isolate.spawn(_isolateEncodeImage, response.sendPort);
  final dynamic sendPort = await response.first;
  final ReceivePort answer = ReceivePort();
  // ignore: always_specify_types
  sendPort.send([answer.sendPort, src]);
  return answer.first;
}

void _isolateDecodeImage(SendPort port) {
  final ReceivePort rPort = ReceivePort();
  port.send(rPort.sendPort);
  rPort.listen((dynamic message) {
    final SendPort send = message[0] as SendPort;
    final List<int> data = message[1] as List<int>;
    send.send(decodeImage(Uint8List.fromList(data)));
  });
}

void _isolateEncodeImage(SendPort port) {
  final ReceivePort rPort = ReceivePort();
  port.send(rPort.sendPort);
  rPort.listen((dynamic message) {
    final SendPort send = message[0] as SendPort;
    final Image src = message[1] as Image;
    send.send(encodeJpg(src));
  });
}

/// it may be failed, due to Cross-domain
Future<Uint8List> _loadNetwork(ExtendedNetworkImageProvider key) async {
  try {
    final Response? response = await HttpClientHelper.get(Uri.parse(key.url),
        headers: key.headers,
        timeLimit: key.timeLimit,
        timeRetry: key.timeRetry,
        retries: key.retries,
        cancelToken: key.cancelToken);
    return response!.bodyBytes;
  } on OperationCanceledError catch (_) {
    print('User cancel request ${key.url}.');
    return Future<Uint8List>.error(
        StateError('User cancel request ${key.url}.'));
  } catch (e) {
    return Future<Uint8List>.error(StateError('failed load ${key.url}. \n $e'));
  }
}


img.Image cropCircle(img.Image srcImage, Rect cropRect) {
  // Step 1: Determine square size for cropping
  int size = srcImage.width < srcImage.height ? srcImage.width : srcImage.height;
  int xOffset = (srcImage.width - size) ~/ 2;
  int yOffset = (srcImage.height - size) ~/ 2;


  // Step 2: Crop the square area from the center of the image
  img.Image squareImage = img.copyCrop(
    srcImage,
    x: xOffset,
    y: yOffset,
    width: size,
    height: size,
  );
  
  

  // Step 3: Create a circular mask with transparency
  img.Image circularImage = img.Image(width: size, height: size);
  int radius = size ~/ 2;

  // Fill the mask image with transparency
  circularImage = img.fill(color: img.ColorInt16.rgba(0, 0, 0, 0), circularImage, );

  // Draw the circle in the center of the square
  img.drawCircle(
    circularImage,
    x: radius,  // x center
    y: radius,  // y center
    radius: radius,  // radius
    color: circularImage.getColor(255, 255, 255, 255),  // White circle
    antialias: true,
  );


  // Step 4: Apply the circular mask to the square image
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      // If the pixel in the mask is transparent, set corresponding pixel in the squareImage to transparent
      if (circularImage.getPixel(x, y) == circularImage.getColor(0, 0, 0, 0)) {
        squareImage.setPixel(x, y, squareImage.getColor(255, 255, 255, 255));
      }
    }
  }

  return squareImage;

}


Image cropByTriangle(Image src, {int? sideLength, int? centerX, int? centerY, bool antialias = true}) {
  // Set center and side length (triangle height)
  centerX ??= src.width ~/ 2;
  centerY ??= src.height ~/ 2;
  sideLength ??= min(src.width, src.height) ~/ 2;

  // Triangle vertices based on center and side length
  final top = Point(centerX, centerY - sideLength ~/ 2);
  final left = Point(centerX - sideLength ~/ 2, centerY + sideLength ~/ 2);
  final right = Point(centerX + sideLength ~/ 2, centerY + sideLength ~/ 2);

  // Crop area bounding box
  final tlx = min(left.x, top.x);
  final tly = min(left.y, top.y);
  final wh = sideLength;

  // Convert palette if needed
  if (src.hasPalette) {
    src = src.convert(numChannels: 4);
  }

  // Initialize the first frame for multi-frame support
  Image? firstFrame;
  final numFrames = src.numFrames;
  for (var i = 0; i < numFrames; ++i) {
    final frame = src.frames[i];
    final dst = firstFrame?.addFrame() ?? Image.fromResized(frame, width: wh, height: wh, noAnimation: true);
    firstFrame ??= dst;

    final bg = frame.backgroundColor ?? src.backgroundColor;
    if (bg != null) {
      dst.clear(bg);
    }

    for (var yi = 0; yi < wh; ++yi) {
      for (var xi = 0; xi < wh; ++xi) {
        // Map dst pixel to src coordinates
        final sx = tlx + xi;
        final sy = tly + yi;

        // Check if pixel is within the triangle using barycentric coordinates
        if (isPointInTriangle(Point(sx, sy), top, left, right)) {
          dst.setPixel(xi, yi, frame.getPixel(sx.toInt(), sy.toInt()));
        } else {
          dst.setPixel(xi, yi, dst.getColor(0, 0, 0, 0));  // Transparent
        }
      }
    }
  }

  return firstFrame!;
}

// Function to check if a point is within a triangle using barycentric coordinates
bool isPointInTriangle(Point p, Point a, Point b, Point c) {
  final denominator = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y);
  final w1 = ((b.y - c.y) * (p.x - c.x) + (c.x - b.x) * (p.y - c.y)) / denominator;
  final w2 = ((c.y - a.y) * (p.x - c.x) + (a.x - c.x) * (p.y - c.y)) / denominator;
  final w3 = 1 - w1 - w2;
  return w1 >= 0 && w2 >= 0 && w3 >= 0;
}