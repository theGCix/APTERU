// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/eru_models.dart';
import '../services/storage_service.dart';
import 'nuevo_eru_screen.dart';
import 'session_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ERUSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);
    final sessions = await StorageService.instance.getSessions();
    setState(() {
      _sessions = sessions..sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
      _loading = false;
    });
  }


  Future<void> _confirmarEliminar(ERUSession session) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eliminar ERU',
          style: TextStyle(color: AppTheme.rojo, fontWeight: FontWeight.bold)),
      content: Text(
        '¿Eliminar el ERU de ${session.grupo} del '
        '${DateFormat('dd/MM/yyyy').format(session.fechaInicio)}?\n\nEsta acción no se puede deshacer.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rojo),
          child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  if (confirm == true) {
    await StorageService.instance.deleteSession(session.id);
    _loadSessions();
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grisClaro,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.rojo,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('ERU',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
            ),
            const SizedBox(width: 8),
            const Text('Warehouse Inventario'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSessions,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // Resumen general
                  SliverToBoxAdapter(
                    child: _buildSummaryCard(),
                  ),

                  // Título historial
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          const Text('Historial ERU',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.azulPrincipal)),
                          const Spacer(),
                          Text('${_sessions.length} sesiones',
                              style: const TextStyle(color: AppTheme.grisTexto, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),

                  // Lista de sesiones
                  _sessions.isEmpty
                      ? SliverToBoxAdapter(child: _buildEmptyState())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _buildSessionCard(_sessions[i]),
                            childCount: _sessions.length,
                          ),
                        ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _irANuevoERU,
        backgroundColor: AppTheme.azulPrincipal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo ERU',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (_sessions.isEmpty) return const SizedBox(height: 16);

    final hoy = DateTime.now();
    final sesionesHoy =
        _sessions.where((s) => _esMismaFecha(s.fechaInicio, hoy)).toList();
    final ultimaSesion = _sessions.first;
    final eruPromedio = _sessions.isNotEmpty
        ? _sessions.map((s) => s.eru).reduce((a, b) => a + b) / _sessions.length
        : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.azulPrincipal, AppTheme.azulOscuro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppTheme.azulPrincipal.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Resumen del día',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const Spacer(),
              Text(DateFormat('dd/MM/yyyy').format(hoy),
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _summaryItem('ERU Promedio', '${eruPromedio.toStringAsFixed(1)}%',
                  eruPromedio >= 98 ? AppTheme.verdeClaro : AppTheme.rojoClaro),
              const SizedBox(width: 16),
              _summaryItem('Sesiones Hoy', '${sesionesHoy.length}', Colors.white),
              const SizedBox(width: 16),
              _summaryItem(
                  'Último ERU',
                  '${ultimaSesion.eru.toStringAsFixed(1)}%',
                  ultimaSesion.eru >= 98 ? AppTheme.verdeClaro : AppTheme.rojoClaro),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color valueColor) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: valueColor, fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _buildSessionCard(ERUSession session) {
    final fmt = DateFormat('dd/MM/yy HH:mm');
    final eru = session.eru;
    final eruColor = eru >= 98 ? AppTheme.verde : (eru >= 95 ? AppTheme.amarillo : AppTheme.rojo);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _irADetalle(session),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ERU circle
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: eruColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: eruColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    '${eru.toStringAsFixed(0)}%',
                    style: TextStyle(
                        color: eruColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(session.grupo,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.azulPrincipal,
                                fontSize: 15)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.azulPrincipal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(session.usuario,
                              style: const TextStyle(
                                  color: AppTheme.azulPrincipal,
                                  fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Columnas: ${session.columnas.join(", ")}',
                      style: const TextStyle(color: AppTheme.grisTexto, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: AppTheme.grisTexto),
                        const SizedBox(width: 3),
                        Text(fmt.format(session.fechaInicio),
                            style: const TextStyle(color: AppTheme.grisTexto, fontSize: 12)),
                        const SizedBox(width: 8),
                        const Icon(Icons.qr_code, size: 12, color: AppTheme.grisTexto),
                        const SizedBox(width: 3),
                        Text('${session.totalPallets} pallets',
                            style: const TextStyle(color: AppTheme.grisTexto, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
             IconButton(
  icon: const Icon(Icons.delete_outline, color: AppTheme.rojo, size: 22),
  onPressed: () => _confirmarEliminar(session),
),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 72, color: AppTheme.azulPrincipal.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('No hay sesiones ERU',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.negro)),
            const SizedBox(height: 8),
            const Text('Presiona el botón + para iniciar un nuevo inventario',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.grisTexto)),
          ],
        ),
      );

  bool _esMismaFecha(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _irANuevoERU() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NuevoEruScreen()),
    );
    if (result == true) _loadSessions();
  }

  void _irADetalle(ERUSession session) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SessionDetailScreen(sessionId: session.id)),
    );
    _loadSessions();
  }
}