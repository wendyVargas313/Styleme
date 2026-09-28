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
      };

  // URL completa de la imagen
  String imagenUrlCompleta(String baseUrl) {
    if (imagenUrl.startsWith('http')) return imagenUrl;
    return '$baseUrl$imagenUrl';
  }

  // Porcentaje de confianza formateado
  String get confianzaTexto => '${(confianzaYolo * 100).toStringAsFixed(0)}%';
}
