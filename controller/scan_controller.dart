import 'dart:developer';
import 'package:camera/camera.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class ScanController extends GetxController {
  late CameraController cameraController;
  late List<CameraDescription> cameras;

  var isCameraInitialized = false.obs;
  var isModelLoaded = false.obs;
  var cameraCount = 0;
  var label = "";
  var isModelProcessing = false;

  @override
  void onInit() {
    super.onInit();
    initCamera();
  }

  @override
  void dispose() {
    super.dispose();
    cameraController.dispose();
    if (isModelLoaded.value) {
      Tflite.close();
    }
  }

  initCamera() async {
    if (await Permission.camera.request().isGranted) {
      cameras = await availableCameras();
      cameraController = CameraController(cameras[0], ResolutionPreset.max,
          imageFormatGroup: ImageFormatGroup.bgra8888);
      await cameraController.initialize().then((value) {
        cameraController.startImageStream((image) {
          cameraCount++;
          if (cameraCount % 10 == 0) {
            cameraCount = 0;
            if (isModelLoaded.value && !isModelProcessing) {
              objectDetector(image);
            }
          }
          update();
        });
      });
      isCameraInitialized(true);
      initTFLite();
      update();
    } else {
      log("Permission denied!");
    }
  }

  initTFLite() async {
    if (!isModelLoaded.value) {
      await Tflite.loadModel(
        model: "assets/model.tflite",
        labels: "assets/labels.txt",
        isAsset: true,
        numThreads: 1,
        useGpuDelegate: false,
      );
      isModelLoaded(true);
    }
  }

  objectDetector(CameraImage image) async {
    // Set the flag to indicate that the model is processing an image
    isModelProcessing = true;

    var detector = await Tflite.runModelOnFrame(
      bytesList: image.planes.map((e) => e.bytes).toList(),
      asynch: true,
      imageHeight: image.height,
      imageWidth: image.width,
      imageMean: 127.5,
      imageStd: 127.5,
      numResults: 1,
      rotation: 90,
      threshold: 0.8,
    );

    if (detector != null && detector.isNotEmpty) {
      var ourDetectedObject = detector.first;
      label = ourDetectedObject['label'] ?? "";
    }

    // Reset the flag after processing is complete
    isModelProcessing = false;

    update();
  }
}
