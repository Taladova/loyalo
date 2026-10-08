import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

enum MerchantImageSlot { logo, cover, gallery }

class MerchantImageConfig {
  final double maxWidth;
  final double maxHeight;
  final int imageQuality;
  final int maxBytes;

  const MerchantImageConfig({
    required this.maxWidth,
    required this.maxHeight,
    required this.imageQuality,
    required this.maxBytes,
  });
}

class MerchantImageUpload {
  final String downloadUrl;
  final String storagePath;

  const MerchantImageUpload({
    required this.downloadUrl,
    required this.storagePath,
  });
}

class MerchantImageException implements Exception {
  final String message;

  const MerchantImageException(this.message);

  @override
  String toString() => message;
}

class MerchantImageService {
  static const galleryLimit = 8;
  static const _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  final FirebaseStorage _storage;
  final ImagePicker _picker;

  MerchantImageService({FirebaseStorage? storage, ImagePicker? picker})
    : _storage = storage ?? FirebaseStorage.instance,
      _picker = picker ?? ImagePicker();

  Future<MerchantImageUpload?> pickAndUpload({
    required String merchantId,
    required MerchantImageSlot slot,
  }) async {
    final config = _configFor(slot);
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: config.maxWidth,
      maxHeight: config.maxHeight,
      imageQuality: config.imageQuality,
    );
    if (picked == null) return null;
    return uploadPickedImage(
      merchantId: merchantId,
      slot: slot,
      picked: picked,
      config: config,
    );
  }

  Future<MerchantImageUpload> uploadPickedImage({
    required String merchantId,
    required MerchantImageSlot slot,
    required XFile picked,
    MerchantImageConfig? config,
  }) async {
    final resolvedConfig = config ?? _configFor(slot);
    final extension = _extensionFor(picked.name);
    if (!_allowedExtensions.contains(extension)) {
      throw const MerchantImageException(
        'Format non supporté. Utilisez une image JPG, PNG ou WebP.',
      );
    }

    final bytes = await picked.readAsBytes();
    if (bytes.length > resolvedConfig.maxBytes) {
      throw MerchantImageException(
        'Image trop lourde. Choisissez une image de moins de ${_mb(resolvedConfig.maxBytes)} Mo.',
      );
    }

    final contentType = _contentTypeFor(extension);
    final path = _storagePath(
      merchantId: merchantId,
      slot: slot,
      extension: extension,
    );
    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: {'merchantId': merchantId, 'slot': slot.name},
    );
    final ref = _storage.ref(path);
    try {
      final task = await ref.putData(Uint8List.fromList(bytes), metadata);
      return MerchantImageUpload(
        downloadUrl: await task.ref.getDownloadURL(),
        storagePath: path,
      );
    } on FirebaseException catch (e) {
      throw MerchantImageException(_storageMessage(e));
    }
  }

  Future<void> deleteByUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      await _storage.refFromURL(url).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      throw MerchantImageException(_storageMessage(e));
    }
  }

  MerchantImageConfig _configFor(MerchantImageSlot slot) {
    switch (slot) {
      case MerchantImageSlot.logo:
        return const MerchantImageConfig(
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 82,
          maxBytes: 2 * 1024 * 1024,
        );
      case MerchantImageSlot.cover:
        return const MerchantImageConfig(
          maxWidth: 1600,
          maxHeight: 1000,
          imageQuality: 84,
          maxBytes: 8 * 1024 * 1024,
        );
      case MerchantImageSlot.gallery:
        return const MerchantImageConfig(
          maxWidth: 1400,
          maxHeight: 1000,
          imageQuality: 82,
          maxBytes: 6 * 1024 * 1024,
        );
    }
  }

  String _storagePath({
    required String merchantId,
    required MerchantImageSlot slot,
    required String extension,
  }) {
    final folder = switch (slot) {
      MerchantImageSlot.logo => 'logo',
      MerchantImageSlot.cover => 'cover',
      MerchantImageSlot.gallery => 'gallery',
    };
    final fileName = switch (slot) {
      MerchantImageSlot.logo => 'logo.$extension',
      MerchantImageSlot.cover => 'cover.$extension',
      MerchantImageSlot.gallery =>
        '${DateTime.now().microsecondsSinceEpoch}.$extension',
    };
    return 'merchants/$merchantId/$folder/$fileName';
  }

  String _extensionFor(String name) {
    final lower = name.toLowerCase();
    final dot = lower.lastIndexOf('.');
    return dot == -1 ? '' : lower.substring(dot + 1);
  }

  String _contentTypeFor(String extension) {
    if (extension == 'png') return 'image/png';
    if (extension == 'webp') return 'image/webp';
    return 'image/jpeg';
  }

  String _storageMessage(FirebaseException e) {
    switch (e.code) {
      case 'unauthorized':
      case 'permission-denied':
        return 'Vous n’avez pas l’autorisation de modifier ces images.';
      case 'canceled':
        return 'Upload annulé.';
      case 'retry-limit-exceeded':
        return 'Le réseau semble instable. Réessayez dans un instant.';
      default:
        return 'Impossible d’envoyer l’image : ${e.message ?? e.code}';
    }
  }

  int _mb(int bytes) => (bytes / (1024 * 1024)).round();
}
