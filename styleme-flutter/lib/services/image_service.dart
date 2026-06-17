// StyleMe - Servicio de manejo de imágenes
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  // Selecciona imagen desde la cámara
  static Future<File?> tomarFoto() async {
    final XFile? archivo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (archivo == null) return null;
    return File(archivo.path);
  }

  // Selecciona imagen desde la galería
  static Future<File?> seleccionarDeGaleria() async {
    final XFile? archivo = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (archivo == null) return null;
    return File(archivo.path);
  }

  // Selecciona múltiples imágenes (modo invitado)
  static Future<List<File>> seleccionarMultiples({int max = 10}) async {
    final List<XFile> archivos = await _picker.pickMultiImage(
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    return archivos.take(max).map((x) => File(x.path)).toList();
  }

  // Verifica que el archivo no exceda 5MB
  static Future<bool> esValidoTamanio(File archivo) async {
    final bytes = await archivo.length();
    return bytes <= 5 * 1024 * 1024;
  }

  // Retorna el nombre del archivo
  static String nombreArchivo(File archivo) {
    return archivo.path.split('/').last;
  }
}
