// StyleMe - Mixin de recarga inteligente
//
// Registra cuándo fue la última carga exitosa y si la última carga falló,
// para decidir si vale la pena volver a pedir datos al backend (ej. al
// cambiar de pestaña o al volver la app a primer plano) sin recargar de
// más ni quedarse con datos obsoletos por horas.
mixin RecargaInteligente {
  static const Duration umbralRecarga = Duration(seconds: 30);

  DateTime? _ultimaCargaExitosa;
  bool _ultimaCargaFallo = false;

  // Hace falta recargar si: nunca cargó, la última carga falló, o pasaron
  // más de [umbralRecarga] desde la última carga exitosa.
  bool get haceFaltaRecargar {
    final ultima = _ultimaCargaExitosa;
    if (ultima == null) return true;
    if (_ultimaCargaFallo) return true;
    return DateTime.now().difference(ultima) > umbralRecarga;
  }

  void registrarCargaExitosa() {
    _ultimaCargaExitosa = DateTime.now();
    _ultimaCargaFallo = false;
  }

  void registrarCargaFallida() {
    _ultimaCargaFallo = true;
  }
}
