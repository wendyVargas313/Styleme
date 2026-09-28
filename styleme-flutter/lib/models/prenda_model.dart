// StyleMe - Modelo de datos para Prenda
import 'package:styleme/config/constants.dart';

class PrendaModel {
  final String id;
  final String tipo;
  final String color;
  final String momento;
  final double confianzaYolo;
  final String imagenUrl;
  final String notas;
  final int vecesUsado;
  final bool activa;
  final String creadoEn;
  // El usuario corrigió tipo, color o clima a mano.
  final bool editadoPorUsuario;

  PrendaModel({
    required this.id,
    required this.tipo,
    required this.color,
    required this.momento,
    required this.confianzaYolo,
    required this.imagenUrl,
    this.notas = '',
    this.vecesUsado = 0,
    this.activa = true,
    required this.creadoEn,
    this.editadoPorUsuario = false,
  });

  factory PrendaModel.fromJson(Map<String, dynamic> json) {
    return PrendaModel(
      id: json['id']?.toString() ?? '',
      tipo: json['tipo'] ?? '',
      color: json['color'] ?? '',
      momento: AppConstants.normalizarMomento(json['momento'] as String?) ??
          AppConstants.momentoDefault,
      confianzaYolo: (json['confianza_yolo'] ?? 0.0).toDouble(),
      imagenUrl: json['imagen_url'] ?? '',
      notas: json['notas'] ?? '',
      vecesUsado: json['veces_usado'] ?? 0,
      activa: json['activa'] ?? true,
      creadoEn: json['creado_en'] ?? '',
      editadoPorUsuario: json['editado_por_usuario'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo,
        'color': color,
        'momento': momento,
        'confianza_yolo': confianzaYolo,
        'imagen_url': imagenUrl,
        'notas': notas,
        'veces_usado': vecesUsado,
        'activa': activa,
        'creado_en': creadoEn,
        'editado_por_usuario': editadoPorUsuario,
      };

  // URL completa de la imagen
  String imagenUrlCompleta(String baseUrl) {
    if (imagenUrl.startsWith('http')) return imagenUrl;
    return '$baseUrl$imagenUrl';
  }

  // La IA no está segura (baja confianza o clase comodín) y el usuario aún
  // no la revisó.
  bool get requiereRevision =>
      !editadoPorUsuario &&
      (confianzaYolo < AppConstants.umbralRevision ||
          tipo == 'not sure' ||
          tipo == 'other');
}
