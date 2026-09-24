// StyleMe - Servicio de manejo de imágenes
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  // Lee un archivo de imagen, hornea la orientación EXIF en los píxeles
  // y re-codifica a JPG. Si la imagen no se puede decodificar, hace
  // fallback a los bytes originales sin romper el flujo.
  static Future<Uint8List> corregirOrientacion(File archivo) async {
    final bytesOriginales = await archivo.readAsBytes();

    final imagenDecodificada = img.decodeImage(bytesOriginales);
    if (imagenDecodificada == null) {
      developer.log(
        'No se pudo decodificar la imagen (${archivo.path}); '
        'se usan los bytes originales sin corregir orientación EXIF.',
        name: 'TryonService',
        level: 900,
      );
      return bytesOriginales;
    }

    final imagenOrientada = img.bakeOrientation(imagenDecodificada);
    return Uint8List.fromList(img.encodeJpg(imagenOrientada, quality: 90));
  }

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

  // Selecciona varias imágenes de galería para agregar prendas, con la misma
  // compresión que tomarFoto/seleccionarDeGaleria (lo que recibe YOLO no
  // cambia). `recortadas` es true si el picker devolvió más de `max`.
  static Future<({List<File> archivos, bool recortadas})> seleccionarVarias({
    int max = 10,
  }) async {
    if (max <= 0) return (archivos: <File>[], recortadas: false);

    if (max == 1) {
      final archivo = await seleccionarDeGaleria();
      return (
        archivos: archivo == null ? <File>[] : [archivo],
        recortadas: false,
      );
    }

    // image_picker exige limit >= 2
    final seleccion = await _picker.pickMultiImage(
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
      limit: max,
    );
    return (
      archivos: seleccion.take(max).map((x) => File(x.path)).toList(),
      recortadas: seleccion.length > max,
    );
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
