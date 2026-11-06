// lib/core/services/storage_service.dart
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';

class StorageService {
  static final ImagePicker _picker = ImagePicker();

  /// Permite seleccionar una imagen desde cámara o galería
  static Future<File?> pickImage({required ImageSource source}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      log("Error al seleccionar imagen: $e");
    }
    return null;
  }

  /// Permite seleccionar un video corto
  static Future<File?> pickVideo({required ImageSource source}) async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 30),
      );
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      log("Error al seleccionar video: $e");
    }
    return null;
  }

  /// Sube un archivo directamente a Cloudinary sin requerir servidor backend.
  /// Si no está configurado un cloud_name real o falla la red, convierte a data URI / base64 seguro para no romper la app.
  static Future<String?> uploadFile(File file, {String resourceType = 'auto'}) async {
    final cloudName = AppConfig.getCloudinaryCloud();
    final uploadPreset = AppConfig.getCloudinaryPreset();

    // Si Cloudinary está configurado válidamente
    if (cloudName.isNotEmpty && cloudName != "demo" && uploadPreset.isNotEmpty) {
      try {
        final uri = Uri.parse(
          "https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload",
        );

        final request = http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = uploadPreset
          ..files.add(await http.MultipartFile.fromPath('file', file.path));

        final response = await request.send();
        if (response.statusCode == 200) {
          final resBody = await response.stream.bytesToString();
          final data = jsonDecode(resBody);
          return data['secure_url'] as String?;
        } else {
          log("Cloudinary error HTTP ${response.statusCode}");
        }
      } catch (e) {
        log("Excepción al subir a Cloudinary: $e");
      }
    }

    // Fallback: Codificación directa Base64 local (soporta imágenes y notas de audio)
    try {
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes < 6 * 1024 * 1024) { // Hasta 6MB
        final base64String = base64Encode(bytes);
        final extension = file.path.split('.').last.toLowerCase();
        String mimeType;
        if (extension == 'png') {
          mimeType = 'image/png';
        } else if (extension == 'mp4') {
          mimeType = 'video/mp4';
        } else if (extension == 'm4a' || extension == 'aac' || extension == 'mp3') {
          mimeType = 'audio/m4a';
        } else {
          mimeType = 'image/jpeg';
        }
        return "data:$mimeType;base64,$base64String";
      }
    } catch (e) {
      log("Error generando fallback base64: $e");
    }

    return null;
  }

  /// Guarda una foto o video en la memoria del dispositivo (solo permitido para administradores)
  static Future<String?> saveMediaToDevice({
    required String mediaUrl,
    required String fileName,
  }) async {
    try {
      Directory? targetDir;
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (downloadDir.existsSync()) {
          targetDir = downloadDir;
        } else {
          targetDir = await getExternalStorageDirectory();
        }
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      if (targetDir == null) return null;

      final savePath = '${targetDir.path}/$fileName';
      final file = File(savePath);

      if (mediaUrl.startsWith('data:')) {
        final commaIdx = mediaUrl.indexOf(',');
        final base64Data = mediaUrl.substring(commaIdx + 1);
        final bytes = base64Decode(base64Data);
        await file.writeAsBytes(bytes);
      } else {
        final response = await http.get(Uri.parse(mediaUrl));
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
        } else {
          return null;
        }
      }
      return savePath;
    } catch (e) {
      log("Error guardando archivo en dispositivo: $e");
      return null;
    }
  }
}
