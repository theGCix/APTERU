// lib/screens/session_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/eru_models.dart';
import '../models/comparacion_result.dart';
import '../services/storage_service.dart';
import '../services/graph_service.dart';
import '../services/excel_service.dart';

class SessionDetailScreen extends StatefulWidget {
  final String sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen>
    with SingleTickerProviderStateMixin {
  ERUSession? _session;
  List<ComparacionResult>? _resultados;
  bool _loading    = true;
  bool _comparando = false;
  bool _exportando = false;
  String? _errorMsg;
  double? _eru;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSession();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    setState(() => _loading = true);
    final session = await StorageService.instance.getSessionById(widget.sessionId);
    setState(() { _session = session; _loading = false; });
    if (session != null) _compararConBaan();
  }

  Future<void> _compararConBaan({bool soloNoOk = false}) async {
    if (_session == null) return;
    setState(() { _comparando = true; _errorMsg = null; });
    try {
      final stock = await GraphService.instance.descargarStock(forzar: true);

      List<ComparacionResult> resultados;

      if (soloNoOk && _resultados != null) {
        // Recalcular: mantener los OK anteriores, re-comparar solo los no-OK
        final anterioresOk = _resultados!
            .where((r) => r.estado == EstadoComparacion.ok)
            .toList();

        // Conteos que NO estaban OK
        final conteosNoOk = _session!.conteos.where((c) {
          final yaOk = anterioresOk.any(
            (r) => r.lote == c.lote && r.pallet == c.numeroPallet,
          );
          return !yaOk;
        }).toList();

        // Comparar solo los no-OK con el TXT actualizado
        final sessionTemp = ERUSession(
          id: _session!.id,
          grupo: _session!.grupo,
          columnas: _session!.columnas,
          usuario: _session!.usuario,
          fechaInicio: _session!.fechaInicio,
          conteos: conteosNoOk,
        );
        final nuevosResultados = sessionTemp.compararConBaan(stock);

        // Unir: OK anteriores + nuevos resultados de los no-OK
        resultados = [...anterioresOk, ...nuevosResultados];
      } else {
        // Primera comparación: todos los pallets
        resultados = _session!.compararConBaan(stock);
      }

      final eru = _session!.calcularEruI(resultados);
      setState(() {
        _resultados = resultados;
        _eru = eru;
        _comparando = false;
      });

      _session!.eruPorcentaje = eru;
      await StorageService.instance.saveSession(_session!);
    } catch (e) {
      setState(() { _comparando = false; _errorMsg = e.toString(); });
    }
  }

  Future<void> _exportarExcel() async {
    if (_session == null) return;
    setState(() => _exportando = true);
    try {
      final path = await ExcelService.instance.exportERU(_session!, _resultados);
      await ExcelService.instance.shareExcel(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.rojo),
      );
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_session == null) return Scaffold(
      appBar: AppBar(title: const Text('Detalle')),
      body: const Center(child: Text('Sesión no encontrada')),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('ERU - ${_session!.grupo}'),
        actions: [
          _exportando
              ? const Padding(padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Exportar Excel',
                  onPressed: _exportarExcel),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.rojo,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Pallets'),
            Tab(text: 'Por Columna'),
          ],
        ),
      ),
      body: _comparando
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Comparando con Baan...'),
            ]))
          : _errorMsg != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 56, color: AppTheme.rojo),
                    const SizedBox(height: 16),
                    const Text('Error al leer archivo Baan',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 16, color: AppTheme.rojo)),
                    const SizedBox(height: 8),
                    Text(_errorMsg!, textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.grisTexto, fontSize: 12)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _compararConBaan,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.azulPrincipal,
                          foregroundColor: Colors.white),
                    ),
                  ]),
                ))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildResumenTab(),
                    _buildPalletsTab(),
                    _buildPorColumnaTab(),
                  ],
                ),
    );
  }

  // ── TAB RESUMEN ──────────────────────────────────────────────

  Widget _buildResumenTab() {
    final total = _resultados?.length ?? 0;
    final ok    = _resultados?.where((r) => r.estado == EstadoComparacion.ok).length ?? 0;
    final otra  = _resultados?.where((r) => r.estado == EstadoComparacion.otraUbicacion).length ?? 0;
    final noInv = _resultados?.where((r) => r.estado == EstadoComparacion.noInventariado).length ?? 0;
    final fmt   = DateFormat('dd/MM/yyyy HH:mm');
    final eruColor = _eru == null ? Colors.grey
        : _eru! >= 98 ? AppTheme.verde : AppTheme.rojo;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [

        // ── ERU único ──────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: eruColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: eruColor, width: 2),
          ),
          child: Column(children: [
            Text('ERU',
                style: TextStyle(fontWeight: FontWeight.bold,
                    color: eruColor, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              _eru == null ? '--' : '${_eru!.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900,
                  color: eruColor),
            ),
            if (_eru != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: eruColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _eru! >= 98 ? '✓ OBJETIVO CUMPLIDO (≥98%)' : '✗ OBJETIVO NO CUMPLIDO (<98%)',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Resultado comparación ──────────────────────────────
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Resultado de Comparación',
                style: TextStyle(fontWeight: FontWeight.bold,
                    color: AppTheme.azulPrincipal, fontSize: 15)),
            const Divider(height: 20),
            _filaEstado(Icons.check_circle,  'OK',              ok,    total, AppTheme.verde),
            const SizedBox(height: 10),
            _filaEstado(Icons.swap_horiz,    'Otra Ubicación',  otra,  total, Colors.orange),
            const SizedBox(height: 10),
            _filaEstado(Icons.error_outline, 'No Inventariado', noInv, total, AppTheme.rojo),
          ]),
        )),
        const SizedBox(height: 12),

        // ── Info sesión ────────────────────────────────────────
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Información',
                style: TextStyle(fontWeight: FontWeight.bold,
                    color: AppTheme.azulPrincipal, fontSize: 15)),
            const Divider(height: 16),
            _infoRow(Icons.person,         'Usuario',          _session!.usuario),
            _infoRow(Icons.warehouse,      'Grupo',            _session!.grupo),
            _infoRow(Icons.calendar_today, 'Inicio',           fmt.format(_session!.fechaInicio)),
            _infoRow(Icons.grid_view,      'Columnas',         _session!.columnas.join(', ')),
            _infoRow(Icons.inventory_2,    'Total escaneados', '$total pallets'),
            if (otra > 0 || noInv > 0)
              _infoRow(Icons.warning_amber, 'Pendientes por corregir',
                  '${otra + noInv} pallets'),
          ]),
        )),
        const SizedBox(height: 16),

        // ── Botón recalcular ───────────────────────────────────
        if ((otra > 0 || noInv > 0))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            child: ElevatedButton.icon(
              onPressed: () => _compararConBaan(soloNoOk: true),
              icon: const Icon(Icons.refresh),
              label: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Recalcular ERU',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Solo re-compara los ${otra + noInv} pallets con problemas',
                      style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.azulPrincipal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                alignment: Alignment.centerLeft,
              ),
            ),
          ),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _exportarExcel,
            icon: const Icon(Icons.download),
            label: const Text('Exportar a Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.verde,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _filaEstado(IconData icon, String label, int count, int total, Color color) {
    final pct = total == 0 ? 0.0 : count / total;
    return Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('$count / $total',
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ])),
    ]);
  }

  // ── TAB PALLETS ──────────────────────────────────────────────

  Widget _buildPalletsTab() {
    if (_resultados == null || _resultados!.isEmpty) {
      return const Center(child: Text('Sin resultados',
          style: TextStyle(color: AppTheme.grisTexto)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _resultados!.length,
      itemBuilder: (ctx, i) {
        final r = _resultados![i];
        Color color;
        IconData icon;
        switch (r.estado) {
          case EstadoComparacion.ok:
            color = AppTheme.verde; icon = Icons.check_circle; break;
          case EstadoComparacion.otraUbicacion:
            color = Colors.orange; icon = Icons.swap_horiz; break;
          case EstadoComparacion.noInventariado:
            color = AppTheme.rojo; icon = Icons.error_outline; break;
        }

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: Icon(icon, color: color, size: 28),
            title: Text('Lote: ${r.lote}  ·  Pallet: ${r.pallet}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (r.descripcion.isNotEmpty)
                Text(r.descripcion,
                    style: const TextStyle(fontSize: 11, color: AppTheme.grisTexto)),
              Text(r.detalle,
                  style: TextStyle(fontSize: 12, color: color,
                      fontWeight: FontWeight.w500)),
            ]),
            isThreeLine: r.descripcion.isNotEmpty,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color),
              ),
              child: Text(r.estadoLabel,
                  style: TextStyle(color: color, fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  // ── TAB POR COLUMNA ──────────────────────────────────────────

  Widget _buildPorColumnaTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _session!.columnas.length,
      itemBuilder: (ctx, i) {
        final col    = _session!.columnas[i];
        final resCol = _resultados?.where((r) => r.columnaEscaneada == col).toList() ?? [];
        final total  = resCol.length;
        final ok     = resCol.where((r) => r.estado == EstadoComparacion.ok).length;
        final otra   = resCol.where((r) => r.estado == EstadoComparacion.otraUbicacion).length;
        final noInv  = resCol.where((r) => r.estado == EstadoComparacion.noInventariado).length;
        final eruCol = total == 0 ? 0.0 : ok / total * 100;
        final eruColor = eruCol >= 98 ? AppTheme.verde
            : eruCol >= 95 ? Colors.orange : AppTheme.rojo;

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.azulPrincipal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(col,
                    style: const TextStyle(fontWeight: FontWeight.w900,
                        color: AppTheme.azulPrincipal, fontSize: 14))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('$total pallets',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: eruColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: eruColor),
                    ),
                    child: Text(total == 0 ? '-' : '${eruCol.toStringAsFixed(0)}%',
                        style: TextStyle(color: eruColor,
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  _pill('$ok OK', AppTheme.verde),
                  const SizedBox(width: 6),
                  _pill('$otra Otra', Colors.orange),
                  const SizedBox(width: 6),
                  _pill('$noInv No Inv.', AppTheme.rojo),
                ]),
              ])),
            ]),
          ),
        );
      },
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, size: 16, color: AppTheme.grisTexto),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(color: AppTheme.grisTexto, fontSize: 13)),
      Expanded(child: Text(value,
          style: const TextStyle(fontWeight: FontWeight.w600,
              color: AppTheme.negro, fontSize: 13))),
    ]),
  );

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}