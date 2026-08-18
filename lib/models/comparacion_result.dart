// lib/models/comparacion_result.dart

enum EstadoComparacion { ok, otraUbicacion, noInventariado }

class ComparacionResult {
  final String lote;
  final String pallet;
  final String descripcion;
  final String columnaEscaneada;
  final String? columnaEnBaan;
  final EstadoComparacion estado;

  ComparacionResult({
    required this.lote,
    required this.pallet,
    required this.descripcion,
    required this.columnaEscaneada,
    this.columnaEnBaan,
    required this.estado,
  });

  String get estadoLabel {
    switch (estado) {
      case EstadoComparacion.ok:             return 'OK';
      case EstadoComparacion.otraUbicacion:  return 'Otra Ubicación';
      case EstadoComparacion.noInventariado: return 'No Inventariado';
    }
  }

  String get detalle {
    switch (estado) {
      case EstadoComparacion.ok:
        return 'Ubicación correcta en $columnaEscaneada';
      case EstadoComparacion.otraUbicacion:
        return 'Escaneado en $columnaEscaneada · Baan indica: $columnaEnBaan';
      case EstadoComparacion.noInventariado:
        return 'No encontrado en Baan · Registrar manualmente';
    }
  }
}
