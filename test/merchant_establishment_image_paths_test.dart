import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loyalo/services/merchant_image_service.dart';

class _StopUpload implements Exception {
  const _StopUpload();
}

class _PickedImage extends XFile {
  _PickedImage() : super.fromData(Uint8List.fromList([1, 2, 3]));
  @override
  String get name => 'image.png';
}

class _PathStorage implements FirebaseStorage {
  String? selectedPath;
  @override
  Reference ref([String? path]) {
    selectedPath = path;
    throw const _StopUpload();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final slot in [MerchantImageSlot.logo, MerchantImageSlot.cover]) {
    test(
      'Le chemin historique ${slot.name} reste inchangé par défaut',
      () async {
        final storage = _PathStorage();
        final service = MerchantImageService(storage: storage);
        final picked = _PickedImage();
        await expectLater(
          service.uploadPickedImage(
            merchantId: 'merchant-one',
            slot: slot,
            picked: picked,
          ),
          throwsA(isA<_StopUpload>()),
        );
        expect(
          storage.selectedPath,
          'merchants/merchant-one/${slot.name}/${slot.name}.png',
        );
      },
    );

    test(
      'Les nouvelles images ${slot.name} utilisent des fichiers distincts avant enregistrement',
      () async {
        final storage = _PathStorage();
        final service = MerchantImageService(storage: storage);
        final picked = _PickedImage();
        await expectLater(
          service.uploadPickedImage(
            merchantId: 'merchant-one',
            slot: slot,
            picked: picked,
            preserveCurrentImage: true,
          ),
          throwsA(isA<_StopUpload>()),
        );
        final first = storage.selectedPath!;
        expect(
          first,
          matches(
            RegExp(
              '^merchants/merchant-one/${slot.name}/${slot.name}_'
              r'[0-9]+[.]png$',
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 1));
        await expectLater(
          service.uploadPickedImage(
            merchantId: 'merchant-one',
            slot: slot,
            picked: picked,
            preserveCurrentImage: true,
          ),
          throwsA(isA<_StopUpload>()),
        );
        expect(storage.selectedPath, isNot(first));
      },
    );
  }
}
