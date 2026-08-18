// lib/services/storage_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/eru_models.dart';

class StorageService {
  static const String _sessionsKey = 'eru_sessions';
  static const String _conteosKey  = 'eru_conteos';

  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  StorageService._();

  Future<List<ERUSession>> getSessions() async {
    final prefs   = await SharedPreferences.getInstance();
    final raw     = prefs.getStringList(_sessionsKey) ?? [];
    final conteos = await getAllConteos();

    return raw.map((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      final session = ERUSession(
        id:          map['id'],
        grupo:       map['grupo'],
        columnas:    (map['columnas'] as String).split(','),
        usuario:     map['usuario'],
        fechaInicio: DateTime.parse(map['fechaInicio']),
        fechaFin:    map['fechaFin'] != null ? DateTime.parse(map['fechaFin']) : null,
        fechaFinEruII: map['fechaFinEruII'] != null ? DateTime.parse(map['fechaFinEruII']) : null,
        eruPorcentaje: (map['eruPorcentaje'] as num?)?.toDouble(),
        eruIIPorcentaje: (map['eruIIPorcentaje'] as num?)?.toDouble(),
      );
      session.conteos = conteos.where((c) => c.sessionId == session.id).toList();
      return session;
    }).toList();
  }

  Future<ERUSession?> getSessionById(String id) async {
    final sessions = await getSessions();
    try { return sessions.firstWhere((s) => s.id == id); } catch (_) { return null; }
  }

  Future<void> saveSession(ERUSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_sessionsKey) ?? [];
    final idx   = raw.indexWhere((s) => (jsonDecode(s) as Map)['id'] == session.id);
    final enc   = jsonEncode(session.toMap());
    if (idx >= 0) raw[idx] = enc; else raw.add(enc);
    await prefs.setStringList(_sessionsKey, raw);
  }

  Future<void> deleteSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_sessionsKey) ?? [];
    raw.removeWhere((s) => (jsonDecode(s) as Map)['id'] == sessionId);
    await prefs.setStringList(_sessionsKey, raw);
    await deleteConteosBySession(sessionId);
  }

  Future<List<PalletConteo>> getAllConteos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_conteosKey) ?? [];
    return raw.map((s) => PalletConteo.fromMap(jsonDecode(s))).toList();
  }

  Future<void> saveConteo(PalletConteo conteo) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_conteosKey) ?? [];
    final idx   = raw.indexWhere((s) => (jsonDecode(s) as Map)['id'] == conteo.id);
    final enc   = jsonEncode(conteo.toMap());
    if (idx >= 0) raw[idx] = enc; else raw.add(enc);
    await prefs.setStringList(_conteosKey, raw);
  }

  Future<void> deleteConteo(String conteoId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_conteosKey) ?? [];
    raw.removeWhere((s) => (jsonDecode(s) as Map)['id'] == conteoId);
    await prefs.setStringList(_conteosKey, raw);
  }

  Future<void> deleteConteosBySession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_conteosKey) ?? [];
    raw.removeWhere((s) => (jsonDecode(s) as Map)['sessionId'] == sessionId);
    await prefs.setStringList(_conteosKey, raw);
  }
}
