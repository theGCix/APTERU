// lib/models/eru_models.dart

import 'comparacion_result.dart';
import '../services/graph_service.dart';

// Fase de inventario: ERU I (conteo inicial) o ERU II (re-escaneo tras ajustes en Baan)
enum FaseInventario { eruI, eruII }

class ERUSession {
  final String id;
  final String grupo;
  final List<String> columnas;
  final String usuario;
  final DateTime fechaInicio;
  DateTime? fechaFin;
  DateTime? fechaFinEruII;
  List<PalletConteo> conteos;
  double? eruPorcentaje;
  double? eruIIPorcentaje;

  ERUSession({
    required this.id,
    required this.grupo,
    required this.columnas,
    required this.usuario,
    required this.fechaInicio,
    this.fechaFin,
    this.fechaFinEruII,
    List<PalletConteo>? conteos,
    this.eruPorcentaje,
    this.eruIIPorcentaje,
  }) : conteos = conteos ?? [];

  int get totalPallets => conteos.length;
  int get palletsOk => conteos.where((c) => c.estado == EstadoPallet.ok).length;
  double get eru => eruPorcentaje ?? 0;

  /// true si ya se registró al menos un pallet en la fase ERU II (re-escaneo)
  bool get eruIIIniciado => conteos.any((c) => c.fase == FaseInventario.eruII);
  bool get eruIIFinalizado => fechaFinEruII != null;

  List<PalletConteo> conteoPorColumna(String columna,
          {FaseInventario fase = FaseInventario.eruI}) =>
      conteos.where((c) => c.columna == columna && c.fase == fase).toList();

  int totalPorFase(FaseInventario fase) =>
      conteos.where((c) => c.fase == fase).length;

  // ── Comparación con Baan ──────────────────────────────────────

  List<ComparacionResult> compararConBaan(List<StockEntry> stockBaan,
      {FaseInventario fase = FaseInventario.eruI}) {
    final resultados = <ComparacionResult>[];
    final conteosFase = conteos.where((c) => c.fase == fase);

    for (final conteo in conteosFase) {
      final enBaan = stockBaan.where((s) =>
          s.lote == conteo.lote &&
          s.pallet == conteo.numeroPallet).toList();

      if (enBaan.isEmpty) {
        resultados.add(ComparacionResult(
          lote: conteo.lote,
          pallet: conteo.numeroPallet,
          descripcion: '',
          columnaEscaneada: conteo.columna,
          columnaEnBaan: null,
          estado: EstadoComparacion.noInventariado,
        ));
      } else {
        final entry = enBaan.first;
        final colBaan = entry.columna.trim().toUpperCase();
        final colEscaneada = conteo.columna.trim().toUpperCase();

        if (colBaan == colEscaneada) {
          resultados.add(ComparacionResult(
            lote: conteo.lote,
            pallet: conteo.numeroPallet,
            descripcion: entry.descripcion,
            columnaEscaneada: conteo.columna,
            columnaEnBaan: entry.columna,
            estado: EstadoComparacion.ok,
          ));
        } else {
          resultados.add(ComparacionResult(
            lote: conteo.lote,
            pallet: conteo.numeroPallet,
            descripcion: entry.descripcion,
            columnaEscaneada: conteo.columna,
            columnaEnBaan: entry.columna,
            estado: EstadoComparacion.otraUbicacion,
          ));
        }
      }
    }
    return resultados;
  }

  double calcularEruI(List<ComparacionResult> resultados) {
    if (resultados.isEmpty) return 0;
    final ok = resultados.where((r) => r.estado == EstadoComparacion.ok).length;
    return ok / resultados.length * 100;
  }

  double calcularEruII(List<ComparacionResult> resultados) =>
      calcularEruI(resultados);

  Map<String, dynamic> toMap() => {
        'id': id,
        'grupo': grupo,
        'columnas': columnas.join(','),
        'usuario': usuario,
        'fechaInicio': fechaInicio.toIso8601String(),
        'fechaFin': fechaFin?.toIso8601String(),
        'fechaFinEruII': fechaFinEruII?.toIso8601String(),
        'eruPorcentaje': eruPorcentaje,
        'eruIIPorcentaje': eruIIPorcentaje,
      };
}

class PalletConteo {
  final String id;
  final String sessionId;
  final String columna;
  final String lote;
  final String numeroPallet;
  final String ubicacionFisica;
  String? ubicacionSistema;
  EstadoPallet estado;
  final DateTime timestamp;
  final String metodo;
  final FaseInventario fase;

  PalletConteo({
    required this.id,
    required this.sessionId,
    required this.columna,
    required this.lote,
    required this.numeroPallet,
    required this.ubicacionFisica,
    this.ubicacionSistema,
    this.estado = EstadoPallet.pendiente,
    required this.timestamp,
    required this.metodo,
    this.fase = FaseInventario.eruI,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sessionId': sessionId,
        'columna': columna,
        'lote': lote,
        'numeroPallet': numeroPallet,
        'ubicacionFisica': ubicacionFisica,
        'ubicacionSistema': ubicacionSistema ?? '',
        'estado': estado.name,
        'timestamp': timestamp.toIso8601String(),
        'metodo': metodo,
        'fase': fase.name,
      };

  factory PalletConteo.fromMap(Map<String, dynamic> map) => PalletConteo(
        id: map['id'],
        sessionId: map['sessionId'],
        columna: map['columna'],
        lote: map['lote'],
        numeroPallet: map['numeroPallet'],
        ubicacionFisica: map['ubicacionFisica'],
        ubicacionSistema: map['ubicacionSistema'],
        estado: EstadoPallet.values.firstWhere(
          (e) => e.name == map['estado'],
          orElse: () => EstadoPallet.pendiente,
        ),
        timestamp: DateTime.parse(map['timestamp']),
        metodo: map['metodo'],
        // Registros antiguos (antes de ERU II) no tienen 'fase' guardada → eruI
        fase: FaseInventario.values.firstWhere(
          (f) => f.name == map['fase'],
          orElse: () => FaseInventario.eruI,
        ),
      );
}

enum EstadoPallet { ok, error, pendiente }

// Columnas reales del almacén Heinz (A01-A47, B01-B45, C01-C45, D01-D30, E01-E29)
class AlmacenConfig {
  static List<String> get todasLasColumnas {
    final cols = <String>[];
    // A: 01-47
    for (int i = 1; i <= 47; i++) cols.add('A${i.toString().padLeft(2, '0')}');
    // B: 01-45
    for (int i = 1; i <= 45; i++) cols.add('B${i.toString().padLeft(2, '0')}');
    // C: 01-45
    for (int i = 1; i <= 45; i++) cols.add('C${i.toString().padLeft(2, '0')}');
    // D: 01-30
    for (int i = 1; i <= 30; i++) cols.add('D${i.toString().padLeft(2, '0')}');
    // E: 01-29
    for (int i = 1; i <= 29; i++) cols.add('E${i.toString().padLeft(2, '0')}');
    return cols;
  }

  static const List<String> grupos = ['ALMACE', 'WIESSE', 'REVISI'];
}
