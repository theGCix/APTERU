import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/comparacion_result.dart';
import '../models/eru_models.dart';
import '../services/graph_service.dart';
class ReporteEruScreen extends StatefulWidget {
  final ERUSession session;
  const ReporteEruScreen({super.key, required this.session});
@override
  State<ReporteEruScreen> createState() => _ReporteEruScreenState();
}
class _ReporteEruScreenState extends State<ReporteEruScreen> {
  List<ComparacionResult>? _resultados;
  bool _cargando = false;
  String? _error;
  double? _eruI;
  double? _eruII;
  DateTime? _ultimaDescarga;
Future<void> _descargarYComparar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final stock = await GraphService.instance.descargarStock();
      final resultados = widget.session.compararConBaan(stock);
      setState(() {
        _resultados = resultados;
        _eruI = widget.session.calcularEruI(resultados);
        _ultimaDescarga = DateTime.now();
        _cargando = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _cargando = false; });
    }
  }
Future<void> _recalcularEruII() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final stock = await GraphService.instance.descargarStock();
      final resultados = widget.session.compararConBaan(stock);
      setState(() {
        _resultados = resultados;
        _eruII = widget.session.calcularEruI(resultados);
        _cargando = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _cargando = false; });
    }
  }
@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reporte ERU - ${widget.session.grupo}')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _resultados == null
              ? _buildInicio()
              : _buildReporte(),
    );
  }
Widget _buildInicio() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_download_outlined, size: 64, color: AppTheme.azulPrincipal),
        const SizedBox(height: 16),
        const Text('Descarga el stock de Baan para\ncomparar con lo escaneado',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.grisTexto)),
        const SizedBox(height: 24),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!, style: const TextStyle(color: AppTheme.rojo)),
          ),
        ElevatedButton.icon(
          onPressed: _descargarYComparar,
          icon: const Icon(Icons.download),
          label: const Text('Descargar Baan y Comparar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.azulPrincipal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          ),
        ),
      ],
    ),
  );
Widget _buildReporte() {
    final ok = _resultados!.where((r) => r.estado == EstadoComparacion.ok).length;
    final otraUbic = _resultados!.where((r) => r.estado == EstadoComparacion.otraUbicacion).length;
    final noInv = _resultados!.where((r) => r.estado == EstadoComparacion.noInventariado).length;
    final total = _resultados!.length;
return Column(
      children: [
        // ERU Cards
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _eruCard('ERU I', _eruI, 'Antes de ajustes'),
              const SizedBox(width: 12),
              _eruCard('ERU II', _eruII, 'Después de ajustes'),
            ],
          ),
        ),
// Resumen
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _chipStat('$ok OK', AppTheme.verde),
              const SizedBox(width: 8),
              _chipStat('$otraUbic Otra Ubic.', AppTheme.amarillo),
              const SizedBox(width: 8),
              _chipStat('$noInv No Inv.', AppTheme.rojo),
              const Spacer(),
              Text('Total: $total', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
const SizedBox(height: 8),
// Tabla
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _resultados!.length,
            itemBuilder: (ctx, i) {
              final r = _resultados![i];
              Color color;
              IconData icon;
              switch (r.estado) {
                case EstadoComparacion.ok:
                  color = AppTheme.verde; icon = Icons.check_circle;
                  break;
                case EstadoComparacion.otraUbicacion:
                  color = AppTheme.amarillo; icon = Icons.swap_horiz;
                  break;
                case EstadoComparacion.noInventariado:
                  color = AppTheme.rojo; icon = Icons.error_outline;
                  break;
              }
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: Icon(icon, color: color),
                  title: Text('Lote: ${r.lote}  |  Pallet: ${r.pallet}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: r.estado == EstadoComparacion.otraUbicacion
                      ? Text('Escaneado: ${r.columnaEscaneada}  →  Baan: ${r.columnaEnBaan}',
                          style: TextStyle(color: color, fontSize: 12))
                      : Text('Columna: ${r.columnaEscaneada}',
                          style: TextStyle(color: color, fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color),
                    ),
                    child: Text(r.estadoLabel,
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            },
          ),
        ),

// Botón ERU II
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_ultimaDescarga != null)
                Text('Última descarga: ${_ultimaDescarga!.hour}:${_ultimaDescarga!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: AppTheme.grisTexto, fontSize: 12)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _recalcularEruII,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recalcular ERU II (tras ajustes en Baan)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.verde,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
Widget _eruCard(String titulo, double? valor, String subtitulo) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: valor == null
            ? Colors.grey.shade100
            : valor >= 98 ? AppTheme.verde.withOpacity(0.1) : AppTheme.rojo.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: valor == null ? Colors.grey.shade300
              : valor >= 98 ? AppTheme.verde : AppTheme.rojo,
        ),
      ),
      child: Column(
        children: [
          Text(titulo,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.azulPrincipal)),
          const SizedBox(height: 8),
          Text(
            valor == null ? '--' : '${valor.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: valor == null ? Colors.grey
                  : valor >= 98 ? AppTheme.verde : AppTheme.rojo,
            ),
          ),
          Text(subtitulo,
              style: const TextStyle(fontSize: 11, color: AppTheme.grisTexto)),
        ],
      ),
    ),
  );
Widget _chipStat(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color),
    ),
    child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
  );
}