// lib/services/storage_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/eru_models.dart';

class StorageService {
  static const String _sessionsKey = 'eru_sessions';
  static const String _conteosKey = 'eru_conteos';

  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  StorageService._();

  // ─── SESSIONS ───────────────────────────────────────────────

  Future<List<ERUSession>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_sessionsKey) ?? [];
    final conteos = await getAllConteos();

    return raw.map((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      final session = ERUSession(
        id: map['id'],
        grupo: map['grupo'],
        columnas: (map['columnas'] as String).split(','),
        usuario: map['usuario'],
        fechaInicio: DateTime.parse(map['fechaInicio']),
        fechaFin: map['fechaFin'] != null ? DateTime.parse(map['fechaFin']) : null,
        eruPorcentaje: map['eruPorcentaje']?.toDouble(),
      );
      session.conteos = conteos.where((c) => c.sessionId == session.id).toList();
      return session;
    }).toList();
  }

  Future<ERUSession?> getSessionById(String id) async {
    final sessions = await getSessions();
    try {
      return sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(ERUSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_sessionsKey) ?? [];
    final idx = raw.indexWhere((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return map['id'] == session.id;
    });

    final encoded = jsonEncode(session.toMap());
    if (idx >= 0) {
      raw[idx] = encoded;
    } else {
      raw.add(encoded);
    }
    await prefs.setStringList(_sessionsKey, raw);
  }

  Future<void> deleteSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_sessionsKey) ?? [];
    raw.removeWhere((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return map['id'] == sessionId;
    });
    await prefs.setStringList(_sessionsKey, raw);
    // Also delete conteos
    await deleteConteosBySession(sessionId);
  }

  // ─── CONTEOS ────────────────────────────────────────────────

  Future<List<PalletConteo>> getAllConteos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_conteosKey) ?? [];
    return raw.map((s) => PalletConteo.fromMap(jsonDecode(s))).toList();
  }

  Future<List<PalletConteo>> getConteosBySession(String sessionId) async {
    final all = await getAllConteos();
    return all.where((c) => c.sessionId == sessionId).toList();
  }

  Future<void> saveConteo(PalletConteo conteo) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_conteosKey) ?? [];
    final idx = raw.indexWhere((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return map['id'] == conteo.id;
    });
    final encoded = jsonEncode(conteo.toMap());
    if (idx >= 0) {
      raw[idx] = encoded;
    } else {
      raw.add(encoded);
    }
    await prefs.setStringList(_conteosKey, raw);
  }

  Future<void> deleteConteo(String conteoId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_conteosKey) ?? [];
    raw.removeWhere((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return map['id'] == conteoId;
    });
    await prefs.setStringList(_conteosKey, raw);
  }

  Future<void> deleteConteosBySession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_conteosKey) ?? [];
    raw.removeWhere((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return map['sessionId'] == sessionId;
    });
    await prefs.setStringList(_conteosKey, raw);
  }

  Future<void> updateConteoEstado(String conteoId, EstadoPallet estado,
      {String? ubicacionSistema}) async {
    final all = await getAllConteos();
    final idx = all.indexWhere((c) => c.id == conteoId);
    if (idx < 0) return;
    final conteo = all[idx];
    conteo.estado = estado;
    if (ubicacionSistema != null) conteo.ubicacionSistema = ubicacionSistema;
    await saveConteo(conteo);
  }
}