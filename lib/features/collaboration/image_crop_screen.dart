import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Profil fotoğrafı kırpma/düzenleme ekranı.
/// Kullanıcı görüntüyü ölçekleyip konumlandırabilir, sonra kaydeder.
class ImageCropScreen extends StatefulWidget {
  const ImageCropScreen({
    super.key,
    required this.imageBytes,
    required this.onCropComplete,
  });

  final List<int> imageBytes;
  final Future<void> Function(List<int> croppedBytes) onCropComplete;

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final TransformationController _transformCtrl = TransformationController();

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final bytes = Uint8List.fromList(widget.imageBytes);
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;
      final size = 256;
      final w = decoded.width;
      final h = decoded.height;
      final cropSize = w < h ? w : h;
      final x = (w - cropSize) ~/ 2;
      final y = (h - cropSize) ~/ 2;
      final cropped = img.copyCrop(decoded, x: x, y: y, width: cropSize, height: cropSize);
      final resized = img.copyResize(cropped!, width: size, height: size);
      final encoded = img.encodeJpg(resized, quality: 90);
      if (encoded != null && mounted) {
        await widget.onCropComplete(encoded);
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kırpma hatası: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: const Text('Profil Fotoğrafını Düzenle'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Kaydet'),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(
            transformationController: _transformCtrl,
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.memory(
              Uint8List.fromList(widget.imageBytes),
              fit: BoxFit.contain,
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Görüntüyü yakınlaştırıp konumlandırın. Daire içindeki alan kaydedilecektir.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
