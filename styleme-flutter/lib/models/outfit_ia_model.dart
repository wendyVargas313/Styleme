// StyleMe - Modelo de datos para Outfit generado con IA (CatVTON)
class OutfitIAModel {
  final String outfitId;
  final String imagenGeneradaBase64;
  final Map<String, dynamic> prendaBase;
  final List<Map<String, dynamic>> complementos;
  final double tiempoGeneracion;

  const OutfitIAModel({
    required this.outfitId,
    required this.imagenGeneradaBase64,
    required this.prendaBase,
    required this.complementos,
    required this.tiempoGeneracion,
  });

  factory OutfitIAModel.fromJson(Map<String, dynamic> json) {
    return OutfitIAModel(
      outfitId: json['outfit_id']?.toString() ?? '',
      imagenGeneradaBase64: json['imagen_generada']?.toString() ?? '',
      prendaBase: json['prenda_base'] as Map<String, dynamic>? ?? {},
      complementos: (json['complementos'] as List? ?? [])
          .map((c) => c as Map<String, dynamic>)
          .toList(),
      tiempoGeneracion:
          (json['tiempo_generacion'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // Tipo de la prenda base (para mostrar en UI)
  String get tipoPrendaBase => prendaBase['tipo']?.toString() ?? '';

  // Color de la prenda base
  String get colorPrendaBase => prendaBase['color']?.toString() ?? '';

  // Número de complementos del outfit
  int get totalComplementos => complementos.length;
}
