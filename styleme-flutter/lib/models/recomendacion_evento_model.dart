// StyleMe - Modelos para Recomendación de Outfits para Eventos
// Respuesta de POST /api/v1/agente/recomendar-evento

class PrendaEnOutfit {
  final String id;
  final String tipo;
  final String color;
  final String? imagenUrl;

  PrendaEnOutfit({
    required this.id,
    required this.tipo,
    required this.color,
    this.imagenUrl,
  });

  factory PrendaEnOutfit.fromJson(Map<String, dynamic> json) {
    return PrendaEnOutfit(
      id: json['id'] as String,
      tipo: json['tipo'] as String,
      color: json['color'] as String,
      imagenUrl: json['imagen_url'] as String?,
    );
  }

  // URL completa de la imagen (mismo patrón que PrendaModel.imagenUrlCompleta)
  String? imagenUrlCompleta(String baseUrl) {
    final url = imagenUrl;
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '$baseUrl$url';
  }
}

class OutfitEvento {
  final String nombre;
  final List<PrendaEnOutfit> prendas;
  final String justificacion;
  final String? outfitGuardadoId;

  OutfitEvento({
    required this.nombre,
    required this.prendas,
    required this.justificacion,
    this.outfitGuardadoId,
  });

  factory OutfitEvento.fromJson(Map<String, dynamic> json) {
    return OutfitEvento(
      nombre: json['nombre'] as String,
      prendas: (json['prendas'] as List)
          .map((p) => PrendaEnOutfit.fromJson(p as Map<String, dynamic>))
          .toList(),
      justificacion: json['justificacion'] as String,
      outfitGuardadoId: json['outfit_guardado_id'] as String?,
    );
  }

  // El resto del archivo es inmutable (fromJson + final); copyWith mantiene
  // ese estilo en vez de volver mutable solo este campo. El controller
  // reemplaza la instancia en la lista de outfits tras el toggle, igual que
  // HistorialController hace con OutfitModel al registrar feedback.
  OutfitEvento copyWith({String? outfitGuardadoId}) {
    return OutfitEvento(
      nombre: nombre,
      prendas: prendas,
      justificacion: justificacion,
      outfitGuardadoId: outfitGuardadoId,
    );
  }
}

class ClimaEvento {
  final String lugar;
  final double lat;
  final double lon;
  final String fechaObjetivo;
  final String fuente;
  final String confianza;
  final double tempMax;
  final double tempMin;
  final double tempPromedio;
  final int humedad;
  final double precipitacionMm;
  final int diasConLluviaPct;
  final String descripcion;
  final String detalleFuente;

  ClimaEvento({
    required this.lugar,
    required this.lat,
    required this.lon,
    required this.fechaObjetivo,
    required this.fuente,
    required this.confianza,
    required this.tempMax,
    required this.tempMin,
    required this.tempPromedio,
    required this.humedad,
    required this.precipitacionMm,
    required this.diasConLluviaPct,
    required this.descripcion,
    required this.detalleFuente,
  });

  factory ClimaEvento.fromJson(Map<String, dynamic> json) {
    final coordenadas = json['coordenadas'] as Map<String, dynamic>;
    return ClimaEvento(
      lugar: json['lugar'] as String,
      lat: (coordenadas['lat'] as num).toDouble(),
      lon: (coordenadas['lon'] as num).toDouble(),
      fechaObjetivo: json['fecha_objetivo'] as String,
      fuente: json['fuente'] as String,
      confianza: json['confianza'] as String,
      tempMax: (json['temp_max'] as num).toDouble(),
      tempMin: (json['temp_min'] as num).toDouble(),
      tempPromedio: (json['temp_promedio'] as num).toDouble(),
      humedad: (json['humedad'] as num).toInt(),
      precipitacionMm: (json['precipitacion_mm'] as num).toDouble(),
      diasConLluviaPct: (json['dias_con_lluvia_pct'] as num).toInt(),
      descripcion: json['descripcion'] as String,
      detalleFuente: json['detalle_fuente'] as String,
    );
  }
}

class MetaRecomendacion {
  final int prendasConsideradas;
  final int prendasTotales;
  final int outfitsDescartados;
  final String modelo;
  final int tokensPrompt;
  final double latenciaMs;

  MetaRecomendacion({
    required this.prendasConsideradas,
    required this.prendasTotales,
    required this.outfitsDescartados,
    required this.modelo,
    required this.tokensPrompt,
    required this.latenciaMs,
  });

  factory MetaRecomendacion.fromJson(Map<String, dynamic> json) {
    return MetaRecomendacion(
      prendasConsideradas: (json['prendas_consideradas'] as num).toInt(),
      prendasTotales: (json['prendas_totales'] as num).toInt(),
      outfitsDescartados: (json['outfits_descartados'] as num).toInt(),
      modelo: json['modelo'] as String,
      tokensPrompt: (json['tokens_prompt'] as num).toInt(),
      latenciaMs: (json['latencia_ms'] as num).toDouble(),
    );
  }
}

class RecomendacionEvento {
  final String evento;
  final ClimaEvento clima;
  final List<OutfitEvento> outfits;
  final List<String> notas;
  final MetaRecomendacion meta;
  // Id del documento en recomendaciones_evento. Nullable: viene null si el
  // POST no pudo persistir la recomendación (no bloquea la respuesta) y
  // también en el GET de detalle, que no lo agrega (ya se conoce por la ruta).
  final String? id;

  RecomendacionEvento({
    required this.evento,
    required this.clima,
    required this.outfits,
    required this.notas,
    required this.meta,
    this.id,
  });

  factory RecomendacionEvento.fromJson(Map<String, dynamic> json) {
    return RecomendacionEvento(
      evento: json['evento'] as String,
      clima: ClimaEvento.fromJson(json['clima'] as Map<String, dynamic>),
      outfits: (json['outfits'] as List)
          .map((o) => OutfitEvento.fromJson(o as Map<String, dynamic>))
          .toList(),
      notas: (json['notas'] as List).map((n) => n as String).toList(),
      meta: MetaRecomendacion.fromJson(json['meta'] as Map<String, dynamic>),
      id: json['id'] as String?,
    );
  }
}

class RecomendacionResumen {
  final String id;
  final String descripcionEvento;
  final String lugar;
  final String fecha;
  final String creadoEn;
  final int totalOutfits;

  RecomendacionResumen({
    required this.id,
    required this.descripcionEvento,
    required this.lugar,
    required this.fecha,
    required this.creadoEn,
    required this.totalOutfits,
  });

  factory RecomendacionResumen.fromJson(Map<String, dynamic> json) {
    return RecomendacionResumen(
      id: json['id'] as String,
      descripcionEvento: json['descripcion_evento'] as String,
      lugar: json['lugar'] as String,
      fecha: json['fecha'] as String,
      creadoEn: json['creado_en'] as String,
      totalOutfits: (json['total_outfits'] as num).toInt(),
    );
  }
}

class ListaRecomendaciones {
  final int total;
  final int page;
  final List<RecomendacionResumen> recomendaciones;

  ListaRecomendaciones({
    required this.total,
    required this.page,
    required this.recomendaciones,
  });

  factory ListaRecomendaciones.fromJson(Map<String, dynamic> json) {
    return ListaRecomendaciones(
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      recomendaciones: (json['recomendaciones'] as List)
          .map((r) => RecomendacionResumen.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}
