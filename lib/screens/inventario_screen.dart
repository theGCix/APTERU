// lib/screens/inventario_screen.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';
import '../app_theme.dart';
import '../models/eru_models.dart';
import '../models/comparacion_result.dart';
import '../services/storage_service.dart';
import '../services/graph_service.dart';
import 'session_detail_screen.dart';
// 1) Agrega este import arriba, junto a los demás:
import 'package:permission_handler/permission_handler.dart';

class InventarioScreen extends StatefulWidget {
  final String sessionId;
  /// Fase del inventario: eruI (conteo inicial) o eruII (re-escaneo tras
  /// ajustes en Baan). Cada fase lleva su propio set de pallets registrados.
  final FaseInventario fase;
  const InventarioScreen({
    super.key,
    required this.sessionId,
    this.fase = FaseInventario.eruI,
  });

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  ERUSession? _session;
  List<StockEntry> _stockBaan = [];
  String? _columnaActual;
  bool _loading = true;
  bool _escaneando = false;
  bool _usarCamara = false; // false = usar el lector físico (gatillo)
  MobileScannerController? _scannerController;

  // ── Lector físico (modo "keyboard wedge") ──────────────────
  // El gatillo del PDA simula un teclado: el código escaneado llega
  // como texto + Enter al campo con foco. No usa la cámara.
  final _wedgeCtrl = TextEditingController();
  final _wedgeFocus = FocusNode();

  final _loteCtrl   = TextEditingController();
  final _palletCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _loteCtrl.dispose();
    _palletCtrl.dispose();
    _wedgeCtrl.dispose();
    _wedgeFocus.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    final session = await StorageService.instance.getSessionById(widget.sessionId);
    final stock   = await GraphService.instance.descargarStock();
    setState(() {
      _session     = session;
      _stockBaan   = stock;
      _columnaActual = session?.columnas.first;
      _loading     = false;
    });
  }

  Future<void> _reloadSession() async {
    final session = await StorageService.instance.getSessionById(widget.sessionId);
    setState(() => _session = session);
  }

  // ── COMPARACIÓN INMEDIATA con Baan ─────────────────────────

  /// Compara lote+pallet contra el TXT y retorna el resultado al instante
  ComparacionResult _compararPallet(String lote, String pallet, String columna) {
    final entry = GraphService.instance.buscarPallet(_stockBaan, lote, pallet);

    if (entry == null) {
      return ComparacionResult(
        lote: lote, pallet: pallet, descripcion: '',
        columnaEscaneada: columna, columnaEnBaan: null,
        estado: EstadoComparacion.noInventariado,
      );
    }

    final colBaan     = entry.columna.trim().toUpperCase();
    final colEscaneada = columna.trim().toUpperCase();

    return ComparacionResult(
      lote: lote, pallet: pallet,
      descripcion: entry.descripcion,
      columnaEscaneada: columna,
      columnaEnBaan: entry.columna,
      estado: colBaan == colEscaneada
          ? EstadoComparacion.ok
          : EstadoComparacion.otraUbicacion,
    );
  }

  // ── ENTRADA MANUAL ──────────────────────────────────────────

  void _mostrarEntradaManual() {
    _loteCtrl.clear();
    _palletCtrl.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Entrada Manual',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: AppTheme.azulPrincipal)),
            const SizedBox(height: 4),
            const Text('Se comparará automáticamente con Baan al registrar',
                style: TextStyle(color: AppTheme.grisTexto, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: _loteCtrl,
              decoration: const InputDecoration(
                labelText: 'Lote',
                hintText: 'Ej: 111329',
                prefixIcon: Icon(Icons.inventory),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _palletCtrl,
              decoration: const InputDecoration(
                labelText: 'N° Pallet',
                hintText: 'Ej: 5',
                prefixIcon: Icon(Icons.tag),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final lote   = _loteCtrl.text.trim();
                  final pallet = _palletCtrl.text.trim();
                  if (lote.isEmpty || pallet.isEmpty) return;
                  Navigator.pop(ctx);
                  _procesarYMostrarResultado(lote, pallet, metodo: 'manual');
                },
                icon: const Icon(Icons.search),
                label: const Text('Verificar y Registrar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.azulPrincipal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PROCESAR: comparar + mostrar resultado + confirmar ──────

  void _procesarYMostrarResultado(String lote, String pallet, {required String metodo}) {
    if (_columnaActual == null) return;
    final resultado = _compararPallet(lote, pallet, _columnaActual!);
    _mostrarResultadoComparacion(resultado, metodo: metodo);
  }

  void _mostrarResultadoComparacion(ComparacionResult r, {required String metodo}) {
    Color color;
    IconData icon;
    String titulo;

    switch (r.estado) {
      case EstadoComparacion.ok:
        color  = AppTheme.verde;
        icon   = Icons.check_circle;
        titulo = '✓ OK — Ubicación Correcta';
        break;
      case EstadoComparacion.otraUbicacion:
        color  = AppTheme.amarillo;
        icon   = Icons.swap_horiz;
        titulo = '⚠ Otra Ubicación';
        break;
      case EstadoComparacion.noInventariado:
        color  = AppTheme.rojo;
        icon   = Icons.error_outline;
        titulo = '✗ No Inventariado en Baan';
        break;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(child: Text(titulo,
              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogRow('Lote', r.lote),
            _dialogRow('Pallet', r.pallet),
            if (r.descripcion.isNotEmpty) _dialogRow('Producto', r.descripcion),
            _dialogRow('Col. escaneada', r.columnaEscaneada),
            if (r.columnaEnBaan != null)
              _dialogRow('Col. en Baan', r.columnaEnBaan!,
                  valueColor: r.estado == EstadoComparacion.otraUbicacion
                      ? AppTheme.rojo : AppTheme.verde),
            if (r.estado == EstadoComparacion.noInventariado)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.rojo.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.rojo.withOpacity(0.3)),
                ),
                child: const Text(
                  'Este pallet no existe en Baan.\nDebe registrarse manualmente en el sistema.',
                  style: TextStyle(color: AppTheme.rojo, fontSize: 12),
                ),
              ),
            if (r.estado == EstadoComparacion.otraUbicacion)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.amarillo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.amarillo.withOpacity(0.4)),
                ),
                child: Text(
                  'Baan lo registra en "${r.columnaEnBaan}" pero físicamente está en "${r.columnaEscaneada}".',
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.grisTexto)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _registrarPallet(r.lote, r.pallet,
                  descripcion: r.descripcion,
                  estadoComparacion: r.estado,
                  columnaEnBaan: r.columnaEnBaan,
                  metodo: metodo);
            },
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: const Text('Registrar igualmente'),
          ),
        ],
      ),
    );
  }

  Widget _dialogRow(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text('$label: ', style: const TextStyle(color: AppTheme.grisTexto, fontSize: 13)),
      Expanded(child: Text(value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
              color: valueColor ?? AppTheme.negro))),
    ]),
  );

  // ── QR SCANNER ─────────────────────────────────────────────

  // 2) Reemplaza tu _iniciarEscaneo() actual por esto:

  /// Inicia el modo de escaneo con el lector físico (gatillo del PDA).
  /// No usa la cámara: el equipo simula un teclado al leer un código.
  void _iniciarEscaneoFisico() {
    _wedgeCtrl.clear();
    setState(() => _escaneando = true);
    // Pedimos el foco después del rebuild para que el campo ya exista.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wedgeFocus.requestFocus();
    });
  }

  void _onWedgeSubmitted(String raw) {
    if (raw.trim().isEmpty) {
      // El lector a veces manda Enter vacío entre lecturas; solo
      // re-enfocamos para seguir escuchando.
      _wedgeFocus.requestFocus();
      return;
    }
    _detenerEscaneo();
    String lote   = raw.trim();
    String pallet = '1';
    if (raw.contains('-')) {
      final partes = raw.split('-');
      lote   = partes[0].trim();
      pallet = partes[1].trim();
    }
    _procesarYMostrarResultado(lote, pallet, metodo: 'lector');
  }

Future<void> _iniciarEscaneoCamara() async {
  final status = await Permission.camera.request();

  if (status.isGranted) {
    setState(() {
      _escaneando = true;
      _usarCamara = true;
      _scannerController = MobileScannerController(
        // Config más compatible con cámaras "legacy" típicas de PDAs
        // industriales, donde la config por defecto de CameraX falla.
        detectionSpeed: DetectionSpeed.normal,
        formats: const [BarcodeFormat.qrCode],
        cameraResolution: const Size(640, 480),
        autoStart: false,
      );
    });

    // Arrancamos manualmente y capturamos cualquier excepción para
    // mostrarla en pantalla (sin depender de adb logcat).
    try {
      await _scannerController!.start();
    } catch (e) {
      if (!mounted) return;
      setState(() => _escaneando = false);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Error al iniciar la cámara'),
          content: SingleChildScrollView(child: Text(e.toString())),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          ],
        ),
      );
    }
    return;
  }

  if (!mounted) return;

  if (status.isPermanentlyDenied) {
    // El usuario ya lo denegó "para siempre": el diálogo del sistema
    // no vuelve a aparecer, hay que mandarlo a Ajustes.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Activa el permiso de cámara en Ajustes para escanear QR'),
      backgroundColor: AppTheme.rojo,
      action: SnackBarAction(
        label: 'Ajustes',
        onPressed: openAppSettings,
      ),
    ));
  } else {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Se necesita el permiso de cámara para escanear'),
      backgroundColor: AppTheme.rojo,
    ));
  }
}

  void _detenerEscaneo() {
    _scannerController?.dispose();
    setState(() {
      _escaneando = false;
      _scannerController = null;
      _usarCamara = false;
    });
  }

  void _onQRDetectado(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    _detenerEscaneo();

    String lote   = raw;
    String pallet = '1';
    if (raw.contains('-')) {
      final partes = raw.split('-');
      lote   = partes[0].trim();
      pallet = partes[1].trim();
    }
    _procesarYMostrarResultado(lote, pallet, metodo: 'qr');
  }

  // ── REGISTRAR PALLET ────────────────────────────────────────

  Future<void> _registrarPallet(String lote, String pallet, {
    required String descripcion,
    required EstadoComparacion estadoComparacion,
    String? columnaEnBaan,
    required String metodo,
  }) async {
    if (_session == null || _columnaActual == null) return;

    // Verificar duplicado (dentro de la misma fase: ERU I y ERU II son independientes)
    final yaExiste = _session!.conteos.any(
      (c) => c.columna == _columnaActual && c.lote == lote &&
          c.numeroPallet == pallet && c.fase == widget.fase,
    );
    if (yaExiste) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠ Este pallet ya fue registrado en esta columna'),
        backgroundColor: AppTheme.amarillo,
      ));
      return;
    }

    // Mapear estado de comparación a EstadoPallet
    final estadoPallet = estadoComparacion == EstadoComparacion.ok
        ? EstadoPallet.ok
        : estadoComparacion == EstadoComparacion.otraUbicacion
            ? EstadoPallet.error
            : EstadoPallet.pendiente;

    final conteo = PalletConteo(
      id:              const Uuid().v4(),
      sessionId:       widget.sessionId,
      columna:         _columnaActual!,
      lote:            lote,
      numeroPallet:    pallet,
      ubicacionFisica: _columnaActual!,
      ubicacionSistema: columnaEnBaan,
      estado:          estadoPallet,
      timestamp:       DateTime.now(),
      metodo:          metodo,
      fase:            widget.fase,
    );

    await StorageService.instance.saveConteo(conteo);
    await _reloadSession();

    if (!mounted) return;
    final color = estadoComparacion == EstadoComparacion.ok
        ? AppTheme.verde
        : estadoComparacion == EstadoComparacion.otraUbicacion
            ? Colors.orange
            : AppTheme.rojo;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Registrado: $lote-$pallet → ${_resultadoLabel(estadoComparacion)}'),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
    ));
  }

  String _resultadoLabel(EstadoComparacion e) {
    switch (e) {
      case EstadoComparacion.ok:             return 'OK';
      case EstadoComparacion.otraUbicacion:  return 'Otra Ubicación';
      case EstadoComparacion.noInventariado: return 'No Inventariado';
    }
  }


    // ── EDITAR / ELIMINAR PALLET ────────────────────────────────

  void _editarPallet(PalletConteo c) {
    final loteCtrl   = TextEditingController(text: c.lote);
    final palletCtrl = TextEditingController(text: c.numeroPallet);
    String columnaSel = c.columna;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: Text('Editar Pallet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: AppTheme.azulPrincipal))),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.rojo),
                  tooltip: 'Eliminar pallet',
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmarYEliminarPallet(c);
                  },
                ),
              ]),
              const Text('Se recalculará la comparación con Baan al guardar',
                  style: TextStyle(color: AppTheme.grisTexto, fontSize: 12)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: columnaSel,
                decoration: const InputDecoration(
                  labelText: 'Columna', prefixIcon: Icon(Icons.grid_view)),
                items: _session!.columnas.map((col) => DropdownMenuItem(
                  value: col, child: Text(col))).toList(),
                onChanged: (v) { if (v != null) setModalState(() => columnaSel = v); },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: loteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lote', prefixIcon: Icon(Icons.inventory)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: palletCtrl,
                decoration: const InputDecoration(
                  labelText: 'N° Pallet', prefixIcon: Icon(Icons.tag)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final lote   = loteCtrl.text.trim();
                    final pallet = palletCtrl.text.trim();
                    if (lote.isEmpty || pallet.isEmpty) return;
                    Navigator.pop(ctx);
                    _guardarEdicionPallet(c, columnaSel, lote, pallet);
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar Cambios'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.azulPrincipal, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _guardarEdicionPallet(
      PalletConteo original, String columna, String lote, String pallet) async {
    if (_session == null) return;

    // Verificar duplicado contra otros pallets (excluyendo el que se edita)
    final yaExiste = _session!.conteos.any((c) =>
        c.id != original.id &&
        c.columna == columna && c.lote == lote &&
        c.numeroPallet == pallet && c.fase == widget.fase);
    if (yaExiste) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠ Ya existe otro registro con ese lote y pallet en esa columna'),
        backgroundColor: AppTheme.amarillo,
      ));
      return;
    }

    final r = _compararPallet(lote, pallet, columna);
    final estadoPallet = r.estado == EstadoComparacion.ok
        ? EstadoPallet.ok
        : r.estado == EstadoComparacion.otraUbicacion
            ? EstadoPallet.error
            : EstadoPallet.pendiente;

    final actualizado = PalletConteo(
      id:              original.id,
      sessionId:       original.sessionId,
      columna:         columna,
      lote:            lote,
      numeroPallet:    pallet,
      ubicacionFisica: columna,
      ubicacionSistema: r.columnaEnBaan,
      estado:          estadoPallet,
      timestamp:       original.timestamp,
      metodo:          original.metodo,
      fase:            original.fase,
    );

    await StorageService.instance.saveConteo(actualizado);
    await _reloadSession();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Actualizado: $lote-$pallet → ${_resultadoLabel(r.estado)}'),
      backgroundColor: AppTheme.verde,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _confirmarYEliminarPallet(PalletConteo c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Pallet'),
        content: Text('¿Eliminar el registro de Lote ${c.lote} - Pallet ${c.numeroPallet}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rojo),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await StorageService.instance.deleteConteo(c.id);
    await _reloadSession();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Pallet eliminado'),
      backgroundColor: AppTheme.grisTexto,
    ));
  }

  // ── FINALIZAR ───────────────────────────────────────────────

  Future<void> _finalizarSesion() async {
    if (_session == null) return;
    final esEruII = widget.fase == FaseInventario.eruII;
    final totalFase = _session!.totalPorFase(widget.fase);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esEruII ? 'Finalizar Re-escaneo ERU II' : 'Finalizar Sesión'),
        content: Text('Total pallets: $totalFase\n¿Deseas ver el reporte?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.verde),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (esEruII) {
      _session!.fechaFinEruII = DateTime.now();
    } else {
      _session!.fechaFin = DateTime.now();
    }
    await StorageService.instance.saveSession(_session!);

    if (!mounted) return;
    if (esEruII) {
      // Vuelve a la SessionDetailScreen ya existente en el stack (Opción B:
      // el detalle mandó a esta pantalla y espera el resultado para refrescar)
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => SessionDetailScreen(sessionId: widget.sessionId)),
      );
    }
  }

  // ── BUILD ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_session == null) return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
      body: const Center(child: Text('Sesión no encontrada')),
    );

    final esEruII = widget.fase == FaseInventario.eruII;

    return Scaffold(
      appBar: AppBar(
        title: Text(esEruII
            ? 'ERU II · Re-escaneo - ${_session!.grupo}'
            : 'Inventariando - ${_session!.grupo}'),
        actions: [
          TextButton.icon(
            onPressed: _finalizarSesion,
            icon: const Icon(Icons.check_circle, color: Colors.white),
            label: const Text('Finalizar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(children: [
        if (esEruII)
          Container(
            width: double.infinity,
            color: AppTheme.amarillo.withOpacity(0.15),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text(
              'Re-escaneando para ERU II. Estos pallets se comparan por separado '
              'de los de ERU I.',
              style: TextStyle(fontSize: 11.5, color: AppTheme.azulOscuro),
            ),
          ),
        // Selector de columna
        Container(
          color: AppTheme.azulPrincipal.withOpacity(0.07),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            const Text('Columna:', style: TextStyle(fontWeight: FontWeight.bold,
                color: AppTheme.azulPrincipal)),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _columnaActual,
                  isDense: true,
                  items: _session!.columnas.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c, style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppTheme.azulPrincipal)),
                  )).toList(),
                  onChanged: (v) => setState(() => _columnaActual = v),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.azulPrincipal,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_session!.conteoPorColumna(_columnaActual ?? '', fase: widget.fase).length} pallets',
                style: const TextStyle(color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ]),
        ),

        if (_escaneando && !_usarCamara)
          Expanded(child: Stack(children: [
            // Área invisible que mantiene el foco para capturar la
            // entrada del lector físico (modo keyboard wedge).
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: _wedgeCtrl,
                  focusNode: _wedgeFocus,
                  autofocus: true,
                  onSubmitted: _onWedgeSubmitted,
                  onTapOutside: (_) => _wedgeFocus.requestFocus(),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _wedgeFocus.requestFocus(),
              child: Container(
                color: AppTheme.azulOscuro,
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_scanner, color: Colors.white, size: 72),
                      const SizedBox(height: 16),
                      const Text('Presiona el gatillo del lector',
                          style: TextStyle(color: Colors.white, fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('Apunta al QR del pallet y dispara',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: () {
                          _detenerEscaneo();
                          _iniciarEscaneoCamara();
                        },
                        icon: const Icon(Icons.camera_alt, color: Colors.white70, size: 18),
                        label: const Text('Usar cámara en su lugar',
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(top: 0, left: 0, right: 0,
              child: Container(
                color: AppTheme.azulPrincipal.withOpacity(0.7),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: const Text('Escaneo por lector físico',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            Positioned(bottom: 16, left: 0, right: 0,
              child: Center(child: ElevatedButton.icon(
                onPressed: _detenerEscaneo,
                icon: const Icon(Icons.close),
                label: const Text('Cancelar'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rojo),
              )),
            ),
          ])),

        if (_escaneando && _usarCamara)
          Expanded(child: Stack(children: [
            MobileScanner(
  controller: _scannerController!,
  onDetect: _onQRDetectado,
  errorBuilder: (context, error, child) {
    debugPrint('MobileScanner error: ${error.errorCode} — ${error.errorDetails}');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text('${error.errorCode}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Mostramos el detalle completo del error para poder
            // diagnosticar sin necesidad de logcat.
            Text(
              error.errorDetails?.message ?? 'Sin detalles adicionales',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: openAppSettings,
              child: const Text('Abrir Ajustes'),
            ),
          ],
        ),
      ),
    );
  },
),
            Positioned(top: 0, left: 0, right: 0,
              child: Container(
                color: AppTheme.azulPrincipal.withOpacity(0.7),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: const Text('Apunta al QR del pallet',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            Positioned(bottom: 16, left: 0, right: 0,
              child: Center(child: ElevatedButton.icon(
                onPressed: _detenerEscaneo,
                icon: const Icon(Icons.close),
                label: const Text('Cancelar'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rojo),
              )),
            ),
          ]))
        else ...[
          // Botones
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: _iniciarEscaneoFisico,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.verde, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: _mostrarEntradaManual,
                icon: const Icon(Icons.edit),
                label: const Text('Manual'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.azulClaro, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              )),
            ]),
          ),

          // Leyenda de colores
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _leyenda(Icons.check_circle, 'OK', AppTheme.verde),
              const SizedBox(width: 12),
              _leyenda(Icons.swap_horiz, 'Otra Ubic.', Colors.orange),
              const SizedBox(width: 12),
              _leyenda(Icons.error_outline, 'No Inv.', AppTheme.rojo),
            ]),
          ),

          const SizedBox(height: 8),
          Expanded(child: _buildListaPallets()),
        ],
      ]),
    );
  }

  Widget _leyenda(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ],
  );

    Widget _buildListaPallets() {
    final conteos = _session!.conteoPorColumna(_columnaActual ?? '', fase: widget.fase);
    if (conteos.isEmpty) return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.qr_code_2, size: 64, color: AppTheme.azulPrincipal.withOpacity(0.3)),
        const SizedBox(height: 12),
        const Text('Sin pallets en esta columna', style: TextStyle(color: AppTheme.grisTexto)),
        const Text('Escanea o ingresa manualmente',
            style: TextStyle(color: AppTheme.grisTexto, fontSize: 12)),
      ]),
    );

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: conteos.length,
      itemBuilder: (ctx, i) {
        final c = conteos[i];
        Color color;
        IconData icon;
        String estadoStr;
        switch (c.estado) {
          case EstadoPallet.ok:
            color = AppTheme.verde; icon = Icons.check_circle; estadoStr = 'OK';
            break;
          case EstadoPallet.error:
            color = Colors.orange; icon = Icons.swap_horiz; estadoStr = 'Otra Ubic.';
            break;
          case EstadoPallet.pendiente:
            color = AppTheme.rojo; icon = Icons.error_outline; estadoStr = 'No Inv.';
            break;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () => _editarPallet(c),
            leading: Icon(icon, color: color, size: 28),
            title: Text('Lote: ${c.lote}  ·  Pallet: ${c.numeroPallet}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.ubicacionSistema != null && c.ubicacionSistema!.isNotEmpty)
                  Text('Baan: ${c.ubicacionSistema}',
                      style: TextStyle(color: color, fontSize: 11)),
                Text(c.metodo.toUpperCase(),
                    style: const TextStyle(color: AppTheme.grisTexto, fontSize: 11)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color),
                  ),
                  child: Text(estadoStr,
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.edit, size: 16, color: AppTheme.grisTexto),
              ],
            ),
            isThreeLine: c.ubicacionSistema != null && c.ubicacionSistema!.isNotEmpty,
          ),
        );
      },
    );
  }
}