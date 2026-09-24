// StyleMe - Servicio de segmentación de sujeto (recorte de fondo en el celular)
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:styleme/services/image_service.dart';

class SegmentacionService {
  static const _tag = '[Segmentacion]';
  static const _timeout = Duration(seconds: 10);

  // Recorta el fondo de la prenda usando ML Kit Subject Segmentation.
  //
  // Nunca lanza: ante cualquier fallo (modelo no disponible aún, sin sujeto
  // detectado, timeout o excepción) registra el motivo con dart:developer
  // (prefijo [Segmentacion]) y devuelve null, para que el llamador siga con
  // el flujo normal sin el recorte.
  static Future<File?> recortarFondo(File imagen) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await _recortar(imagen).timeout(_timeout);
    } on TimeoutException {
      developer.log(
        'Timeout (${_timeout.inSeconds}s) recortando fondo '
        '(${stopwatch.elapsedMilliseconds}ms)',
        name: _tag,
      );
      return null;
    } catch (e) {
      developer.log(
        'Fallo al recortar fondo (${stopwatch.elapsedMilliseconds}ms): $e',
        name: _tag,
      );
      return null;
    }
  }

  // Nota: si _recortar excede el timeout de arriba, esta función sigue
  // corriendo en segundo plano hasta terminar (Dart no cancela Futures) y
  // su bloque finally sigue garantizando que el segmentador se cierre y el
  // archivo temporal de entrada se borre, aunque el llamador ya haya
  // recibido null por el timeout.
  static Future<File?> _recortar(File imagen) async {
    final stopwatch = Stopwatch()..start();

    // Enderezar con el mismo corrector de orientación EXIF que usa el
    // try-on: el PNG resultante de ML Kit no lleva EXIF, así que si el
    // modelo recibiera la foto "acostada" la tarjeta saldría de lado.
    final bytesOrientados = await ImageService.corregirOrientacion(imagen);

    final tempEntrada = File(
      '${Directory.systemTemp.path}/styleme_seg_in_'
      '${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await tempEntrada.writeAsBytes(bytesOrientados);

    final segmentador = SubjectSegmenter(
      options: SubjectSegmenterOptions(
        enableForegroundBitmap: true,
        enableForegroundConfidenceMask: false,
        enableMultipleSubjects: SubjectResultOptions(
          enableConfidenceMask: false,
          enableSubjectBitmap: false,
        ),
      ),
    );

    try {
      final inputImage = InputImage.fromFilePath(tempEntrada.path);
      final resultado = await segmentador.processImage(inputImage);

      final bitmap = resultado.foregroundBitmap;
      if (bitmap == null || bitmap.isEmpty) {
        developer.log(
          'Sin sujeto detectado (${stopwatch.elapsedMilliseconds}ms)',
          name: _tag,
        );
        return null;
      }

      // El plugin ya entrega foregroundBitmap codificado como PNG con
      // transparencia (confirmado en el código nativo: comprime el Bitmap
      // con Bitmap.CompressFormat.PNG antes de cruzar el method channel),
      // así que no hace falta re-codificar con package:image.
      final tempSalida = File(
        '${Directory.systemTemp.path}/styleme_recorte_'
        '${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await tempSalida.writeAsBytes(bitmap);

      developer.log(
        'Recorte generado en ${stopwatch.elapsedMilliseconds}ms',
        name: _tag,
      );
      return tempSalida;
    } finally {
      await segmentador.close();
      await tempEntrada.delete().catchError((_) => tempEntrada);
    }
  }
}
