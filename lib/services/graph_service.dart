// lib/services/graph_service.dart

import 'dart:convert';
import 'package:flutter/services.dart';

class StockEntry {
  final String columna;
  final String lote;
  final String descripcion;
  final String pallet;
  final String grupo;

  StockEntry({
    required this.columna,
    required this.lote,
    required this.descripcion,
    required this.pallet,
    required this.grupo,
  });
}

class GraphService {
  static GraphService? _instance;
  static GraphService get instance => _instance ??= GraphService._();
  GraphService._();

  List<StockEntry>? _cache;
  DateTime? _cacheTime;

  Future<List<StockEntry>> descargarStock({bool forzar = false}) async {
    if (!forzar &&
        _cache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inMinutes < 5) {
      return _cache!;
    }

    final byteData = await rootBundle.load('assets/StockByLocations.txt');
    final rawBytes = byteData.buffer.asUint8List();

    String contenido;
    try {
      contenido = utf8.decode(rawBytes);
    } catch (_) {
      contenido = latin1.decode(rawBytes);
    }

    _cache     = _parsearTXT(contenido);
    _cacheTime = DateTime.now();
    return _cache!;
  }

  List<StockEntry> _parsearTXT(String contenido) {
    final lineas  = contenido.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final entries = <StockEntry>[];

    for (var i = 1; i < lineas.length; i++) {
      final linea = lineas[i].trim();
      if (linea.isEmpty) continue;

      final cols = linea.split('|');
      if (cols.length < 7) continue;

      final columna = cols[0].trim();
      if (columna.isEmpty || columna.length < 2) continue;
      if (!RegExp(r'^[A-Z]\d+$').hasMatch(columna)) continue;

      entries.add(StockEntry(
        columna:     columna,
        lote:        cols[3].trim(),
        descripcion: cols[5].trim(),
        pallet:      cols[6].trim(),
        grupo:       cols.length > 20 ? cols[20].trim() : '',
      ));
    }
    return entries;
  }

  StockEntry? buscarPallet(List<StockEntry> stock, String lote, String pallet) {
    try {
      return stock.firstWhere((s) => s.lote == lote && s.pallet == pallet);
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> obtenerColumnas() async {
    final stock = await descargarStock();
    return stock.map((e) => e.columna).toSet().toList()..sort();
  }

  void limpiarCache() {
    _cache     = null;
    _cacheTime = null;
  }
}