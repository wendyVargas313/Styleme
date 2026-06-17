// StyleMe - Modelo de datos para Outfit
import 'package:styleme/models/prenda_model.dart';

class ComplementoOutfit {
  final PrendaModel prenda;
  final double score;
  final String porcentaje;
  final Map<String, dynamic> detalle;

  ComplementoOutfit({
    required this.prenda,
    required this.score,
    required this.porcentaje,
    required this.detalle,
  });

  factory ComplementoOutfit.fromJson(Map<String, dynamic> json) {
    return ComplementoOutfit(
      prenda: PrendaModel.fromJson(json['prenda'] ?? {}),
      score: (json['score'] ?? 0.0).toDouble(),
      porcentaje: json['porcentaje'] ?? '0%',
      detalle: Map<String, dynamic>.from(json['detalle'] ?? {}),
    );
  }
}

class OutfitModel {
  final String id;
  final PrendaModel? prendaBase;
  final List<ComplementoOutfit> complementos;
  final String feedback;
  final String temporada;
  final String tipoGeneracion;
  final String generadoEn;

  OutfitModel({
    required this.id,
    this.prendaBase,
    required this.complementos,
    this.feedback = 'none',
    required this.temporada,
    required this.tipoGeneracion,
    required this.generadoEn,
  });

  factory OutfitModel.fromJson(Map<String, dynamic> json) {
    final complementosJson = json['complementos'] as List? ?? [];
    final complementos = complementosJson
        .map((c) => ComplementoOutfit.fromJson(c as Map<String, dynamic>))
        .toList();

    return OutfitModel(
      id: json['id']?.toString() ?? json['outfit_id']?.toString() ?? '',
      prendaBase: json['prenda_base'] != null
          ? PrendaModel.fromJson(json['prenda_base'])
          : null,
      complementos: complementos,
      feedback: json['feedback'] ?? 'none',
      temporada: json['temporada'] ?? '',
      tipoGeneracion: json['tipo_generacion'] ?? 'manual',
      generadoEn: json['generado_en'] ?? '',
    );
  }

  // Retorna true si el usuario ya dio feedback positivo
  bool get esLiked => feedback == 'liked';
  bool get esSaved => feedback == 'saved';
  bool get esDisliked => feedback == 'disliked';
}
