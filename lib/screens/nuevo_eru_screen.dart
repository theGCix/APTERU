// lib/screens/nuevo_eru_screen.dart

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_theme.dart';
import '../models/eru_models.dart';
import '../services/storage_service.dart';
import 'inventario_screen.dart';

class NuevoEruScreen extends StatefulWidget {
  const NuevoEruScreen({super.key});

  @override
  State<NuevoEruScreen> createState() => _NuevoEruScreenState();
}

class _NuevoEruScreenState extends State<NuevoEruScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _usuarioCtrl = TextEditingController();
  String _grupoSeleccionado = AlmacenConfig.grupos.first;
  final Set<String> _columnasSeleccionadas = {};
  bool _loading = false;

  // Letras disponibles en el almacén
  final List<String> _letras = ['A', 'B', 'C', 'D', 'E'];
  String _letraActiva = 'A';

  @override
  void dispose() { _usuarioCtrl.dispose(); super.dispose(); }

  // Columnas disponibles por letra según el TXT real
  List<String> _columnasDeLLetra(String letra) {
    final todas = AlmacenConfig.todasLasColumnas;
    return todas.where((c) => c.startsWith(letra)).toList();
  }

  void _toggleColumna(String col) {
    setState(() {
      if (_columnasSeleccionadas.contains(col)) {
        _columnasSeleccionadas.remove(col);
      } else {
        _columnasSeleccionadas.add(col);
      }
    });
  }

  void _seleccionarAleatorias() {
    final todas = AlmacenConfig.todasLasColumnas..shuffle();
    setState(() {
      _columnasSeleccionadas.clear();
      _columnasSeleccionadas.addAll(todas.take(10));
    });
  }

  void _limpiar() => setState(() => _columnasSeleccionadas.clear());

  Future<void> _iniciarERU() async {
    if (!_formKey.currentState!.validate()) return;
    if (_columnasSeleccionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecciona al menos una columna'),
        backgroundColor: AppTheme.rojo,
      ));
      return;
    }

    setState(() => _loading = true);
    try {
      final session = ERUSession(
        id:          const Uuid().v4(),
        grupo:       _grupoSeleccionado,
        columnas:    _columnasSeleccionadas.toList()..sort(),
        usuario:     _usuarioCtrl.text.trim(),
        fechaInicio: DateTime.now(),
      );
      await StorageService.instance.saveSession(session);
      if (!mounted) return;
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => InventarioScreen(sessionId: session.id)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final columnasDeLLetra = _columnasDeLLetra(_letraActiva);
    final seleccionadas    = _columnasSeleccionadas.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo ERU'), leading: const BackButton()),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Usuario ──────────────────────────────────────
            const _Label(icon: Icons.person, text: 'Usuario'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _usuarioCtrl,
              decoration: const InputDecoration(
                hintText: 'Nombre y apellido',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
            ),
            const SizedBox(height: 20),

            // ── Grupo ─────────────────────────────────────────
            const _Label(icon: Icons.warehouse, text: 'Grupo / Almacén'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _grupoSeleccionado,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.warehouse_outlined)),
              items: AlmacenConfig.grupos
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _grupoSeleccionado = v!),
            ),
            const SizedBox(height: 20),

            // ── Columnas ──────────────────────────────────────
            Row(children: [
              const _Label(icon: Icons.grid_view, text: 'Columnas a auditar'),
              const Spacer(),
              TextButton.icon(
                onPressed: _seleccionarAleatorias,
                icon: const Icon(Icons.shuffle, size: 16),
                label: const Text('10 aleatorias'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.azulPrincipal),
              ),
              if (_columnasSeleccionadas.isNotEmpty)
                TextButton(
                  onPressed: _limpiar,
                  child: const Text('Limpiar', style: TextStyle(color: AppTheme.rojo)),
                ),
            ]),

            // Resumen seleccionadas
            if (seleccionadas.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.azulPrincipal.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Text('${seleccionadas.length} seleccionadas: ',
                      style: const TextStyle(color: AppTheme.azulPrincipal,
                          fontWeight: FontWeight.bold, fontSize: 12)),
                  Expanded(
                    child: Text(seleccionadas.join(', '),
                        style: const TextStyle(color: AppTheme.azulPrincipal, fontSize: 12),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 12),

            // Selector por letra (A, B, C, D, E)
            Row(children: _letras.map((letra) {
              final activa = _letraActiva == letra;
              final countLetra = _columnasSeleccionadas
                  .where((c) => c.startsWith(letra)).length;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _letraActiva = letra),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: activa ? AppTheme.azulPrincipal : AppTheme.grisClaro,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: activa
                          ? AppTheme.azulPrincipal : AppTheme.grisMedio),
                    ),
                    child: Column(children: [
                      Text(letra,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16,
                              color: activa ? Colors.white : AppTheme.negro)),
                      if (countLetra > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: activa ? Colors.white.withOpacity(0.3) : AppTheme.azulPrincipal,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$countLetra',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold,
                                  color: activa ? Colors.white : Colors.white)),
                        ),
                    ]),
                  ),
                ),
              );
            }).toList()),
            const SizedBox(height: 10),

            // Grid de números de la letra activa
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.blanco,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.grisMedio),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: columnasDeLLetra.map((col) {
                  final sel = _columnasSeleccionadas.contains(col);
                  return GestureDetector(
                    onTap: () => _toggleColumna(col),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 52,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.azulPrincipal : AppTheme.grisClaro,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel ? AppTheme.azulPrincipal : AppTheme.grisMedio,
                        ),
                      ),
                      child: Text(
                        col,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: sel ? Colors.white : AppTheme.negro,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 32),

            // Botón iniciar
            _loading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _iniciarERU,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Iniciar ERU'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.azulPrincipal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Label({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: AppTheme.azulPrincipal),
    const SizedBox(width: 6),
    Text(text, style: const TextStyle(fontWeight: FontWeight.bold,
        color: AppTheme.negro, fontSize: 14)),
  ]);
}
