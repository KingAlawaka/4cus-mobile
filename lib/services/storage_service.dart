import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// Uploads images to Firebase Storage and returns download URLs.
/// Uses XFile bytes (putData) so it works on Android, iOS and web.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  Future<String> _uploadBytes({
    required Uint8List bytes,
    required String path,
    String contentType = 'image/jpeg',
  }) async {
    final ref = _storage.ref(path);
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return task.ref.getDownloadURL();
  }

  /// Check-in photo: checkins/{groupId}/{uid}_{dateKey}.jpg
  /// Overwrites if the user re-posts the same day.
  Future<String> uploadCheckInPhoto({
    required String groupId,
    required String uid,
    required String dateKey,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    return _uploadBytes(
      bytes: bytes,
      path: 'checkins/$groupId/${uid}_$dateKey.jpg',
    );
  }

  /// Chat image: chat/{groupId}/{uuid}.jpg
  Future<String> uploadChatImage({
    required String groupId,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    return _uploadBytes(
      bytes: bytes,
      path: 'chat/$groupId/${_uuid.v4()}.jpg',
    );
  }

  /// Profile avatar: profiles/{uid}/avatar.jpg
  Future<String> uploadAvatar({
    required String uid,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    return _uploadBytes(
      bytes: bytes,
      path: 'profiles/$uid/avatar.jpg',
    );
  }
}

/// Small helper around image_picker used by several screens.
class ImagePick {
  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> fromCamera() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        imageQuality: 80,
      );
    } catch (e) {
      debugPrint('4cus: camera pick failed: $e');
      return null;
    }
  }

  static Future<XFile?> fromGallery() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        imageQuality: 80,
      );
    } catch (e) {
      debugPrint('4cus: gallery pick failed: $e');
      return null;
    }
  }
}
