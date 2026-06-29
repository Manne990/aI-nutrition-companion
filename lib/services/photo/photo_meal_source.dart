import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum PhotoMealCaptureMode { camera, gallery }

enum PhotoMealCaptureFailureKind { permissionDenied, unavailable, unknown }

class PhotoMealCapture {
  const PhotoMealCapture({required this.path, required this.mode});

  final String path;
  final PhotoMealCaptureMode mode;
}

class PhotoMealCaptureException implements Exception {
  const PhotoMealCaptureException(this.kind, this.message);

  final PhotoMealCaptureFailureKind kind;
  final String message;

  @override
  String toString() => message;
}

abstract interface class PhotoMealSource {
  Future<PhotoMealCapture?> pickPhoto(PhotoMealCaptureMode mode);
}

class ImagePickerPhotoMealSource implements PhotoMealSource {
  ImagePickerPhotoMealSource({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PhotoMealCapture?> pickPhoto(PhotoMealCaptureMode mode) async {
    try {
      final picked = await _picker.pickImage(
        source: mode == PhotoMealCaptureMode.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (picked == null) {
        return null;
      }
      return PhotoMealCapture(path: picked.path, mode: mode);
    } on PlatformException catch (error) {
      throw PhotoMealCaptureException(
        _failureKindFor(error.code),
        _failureMessageFor(mode, error.code),
      );
    }
  }
}

PhotoMealCaptureFailureKind _failureKindFor(String code) {
  final normalized = code.toLowerCase();
  if (normalized.contains('denied') || normalized.contains('permission')) {
    return PhotoMealCaptureFailureKind.permissionDenied;
  }
  if (normalized.contains('unavailable')) {
    return PhotoMealCaptureFailureKind.unavailable;
  }
  return PhotoMealCaptureFailureKind.unknown;
}

String _failureMessageFor(PhotoMealCaptureMode mode, String code) {
  final sourceLabel = mode == PhotoMealCaptureMode.camera
      ? 'Camera'
      : 'Photo library';
  final kind = _failureKindFor(code);
  return switch (kind) {
    PhotoMealCaptureFailureKind.permissionDenied =>
      '$sourceLabel permission is denied. You can choose another source or keep logging manually.',
    PhotoMealCaptureFailureKind.unavailable =>
      '$sourceLabel is unavailable on this device. Try the other photo source.',
    PhotoMealCaptureFailureKind.unknown =>
      '$sourceLabel could not be opened. Try again or keep logging manually.',
  };
}
