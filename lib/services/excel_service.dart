// lib/services/excel_service.dart

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/eru_models.dart';
import '../models/comparacion_result.dart';

class ExcelService {
  static final ExcelService instance = ExcelService._();
  ExcelService._();

  static const String _azul    = 'FF003087';
  static const String _rojo    = 'FFCE1126';
  static const String _blanco  = 'FFFFFFFF';
  static const String _gris    = 'FFF2F2F2';
  static const String _verde   = 'FF00AA44';
  static const String _rojoClr = 'FFFF3333';
  static const String _naranja = 'FFFF8800';

  Future<String> exportERU(ERUSession session, List<ComparacionResult>? resultados) async {
    final excel = Excel.createExcel();

    final resumen = excel['Resumen ERU'];
    excel.setDefaultSheet('Resumen ERU');
    _buildResumen(resumen, session, resultados);

    final detalle = excel['Detalle Pallets'];
    _buildDetalle(detalle, resultados ?? []);

    final porCol = excel['Por Columna'];
    _buildPorColumna(porCol, session, resultados ?? []);

    final bytes = excel.save();
    if (bytes == null) throw Exception('Error al generar Excel');

    final dir      = await getTemporaryDirectory();
    final fecha    = DateFormat('yyyyMMdd_HHmm').format(session.fechaInicio);
    final fileName = 'ERU_${session.grupo}_$fecha.xlsx';
    final path     = '${dir.path}/$fileName';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  void _buildResumen(Sheet s, ERUSession session, List<ComparacionResult>? res) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    _set(s, 0, 0, 'REPORTE ERU — HEINZ', bold: true, fs: 16, bg: _azul, fc: _blanco);

    _set(s, 2, 0, 'Grupo:',   bold: true, bg: _gris); _set(s, 2, 1, session.grupo);
    _set(s, 3, 0, 'Usuario:', bold: true, bg: _gris); _set(s, 3, 1, session.usuario);
    _set(s, 4, 0, 'Inicio:',  bold: true, bg: _gris); _set(s, 4, 1, fmt.format(session.fechaInicio));
    _set(s, 5, 0, 'Columnas:', bold: true, bg: _gris); _set(s, 5, 1, session.columnas.join(', '));

    final total  = res?.length ?? 0;
    final ok     = res?.where((r) => r.estado == EstadoComparacion.ok).length ?? 0;
    final otra   = res?.where((r) => r.estado == EstadoComparacion.otraUbicacion).length ?? 0;
    final noInv  = res?.where((r) => r.estado == EstadoComparacion.noInventariado).length ?? 0;
    final eruI   = total == 0 ? 0.0 : ok / total * 100;

    _set(s, 7, 0, 'RESULTADO ERU', bold: true, fs: 14, bg: _rojo, fc: _blanco);
    _set(s, 8, 0, 'Total pallets:',       bold: true, bg: _gris); _set(s, 8, 1, '$total');
    _set(s, 9, 0, 'OK:',                  bold: true, bg: _gris); _set(s, 9, 1, '$ok', fc: _verde);
    _set(s, 10, 0, 'Otra Ubicación:',     bold: true, bg: _gris); _set(s, 10, 1, '$otra', fc: _naranja);
    _set(s, 11, 0, 'No Inventariado:',    bold: true, bg: _gris); _set(s, 11, 1, '$noInv', fc: _rojoClr);
    _set(s, 12, 0, 'ERU I:',              bold: true, fs: 14, bg: _gris);
    _set(s, 12, 1, '${eruI.toStringAsFixed(1)}%', bold: true, fs: 18,
        fc: eruI >= 98 ? _verde : _rojoClr);
    _set(s, 13, 0, eruI >= 98 ? '✓ OBJETIVO CUMPLIDO (≥98%)' : '✗ OBJETIVO NO CUMPLIDO (<98%)',
        bold: true, bg: eruI >= 98 ? _verde : _rojoClr, fc: _blanco);
  }

  void _buildDetalle(Sheet s, List<ComparacionResult> res) {
    final headers = ['#','Lote','Pallet','Descripción','Col. Escaneada','Col. Baan','Estado'];
    for (int i = 0; i < headers.length; i++) {
      _set(s, 0, i, headers[i], bold: true, bg: _azul, fc: _blanco);
    }
    for (int i = 0; i < res.length; i++) {
      final r   = res[i];
      final bg  = i % 2 == 0 ? _gris : _blanco;
      String fc;
      switch (r.estado) {
        case EstadoComparacion.ok:             fc = _verde; break;
        case EstadoComparacion.otraUbicacion:  fc = _naranja; break;
        case EstadoComparacion.noInventariado: fc = _rojoClr; break;
      }
      _set(s, i+1, 0, '${i+1}',               bg: bg);
      _set(s, i+1, 1, r.lote,                 bg: bg);
      _set(s, i+1, 2, r.pallet,               bg: bg);
      _set(s, i+1, 3, r.descripcion,          bg: bg);
      _set(s, i+1, 4, r.columnaEscaneada,     bg: bg);
      _set(s, i+1, 5, r.columnaEnBaan ?? '-', bg: bg);
      _set(s, i+1, 6, r.estadoLabel, bold: true, fc: fc, bg: bg);
    }
  }

  void _buildPorColumna(Sheet s, ERUSession session, List<ComparacionResult> res) {
    _set(s, 0, 0, 'RESUMEN POR COLUMNA', bold: true, bg: _azul, fc: _blanco);
    final h = ['Columna','Total','OK','Otra Ubic.','No Inv.','ERU%'];
    for (int i = 0; i < h.length; i++) _set(s, 1, i, h[i], bold: true, bg: _rojo, fc: _blanco);

    int row = 2;
    for (final col in session.columnas) {
      final rc    = res.where((r) => r.columnaEscaneada == col).toList();
      final total = rc.length;
      final ok    = rc.where((r) => r.estado == EstadoComparacion.ok).length;
      final otra  = rc.where((r) => r.estado == EstadoComparacion.otraUbicacion).length;
      final noInv = rc.where((r) => r.estado == EstadoComparacion.noInventariado).length;
      final eru   = total == 0 ? 0.0 : ok / total * 100;
      final bg    = row % 2 == 0 ? _gris : _blanco;

      _set(s, row, 0, col,             bold: true, bg: bg);
      _set(s, row, 1, '$total',        bg: bg);
      _set(s, row, 2, '$ok',           fc: _verde,   bg: bg);
      _set(s, row, 3, '$otra',         fc: _naranja, bg: bg);
      _set(s, row, 4, '$noInv',        fc: _rojoClr, bg: bg);
      _set(s, row, 5, '${eru.toStringAsFixed(1)}%',
          bold: true, fc: eru >= 98 ? _verde : _rojoClr, bg: bg);
      row++;
    }
  }

  void _set(Sheet s, int row, int col, String val, {
    bool bold = false, double? fs, String? bg, String? fc,
  }) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(val);

    if (bg != null && fc != null) {
      cell.cellStyle = CellStyle(bold: bold, fontSize: fs?.toInt() ?? 11,
          backgroundColorHex: ExcelColor.fromHexString(bg),
          fontColorHex: ExcelColor.fromHexString(fc));
    } else if (bg != null) {
      cell.cellStyle = CellStyle(bold: bold, fontSize: fs?.toInt() ?? 11,
          backgroundColorHex: ExcelColor.fromHexString(bg));
    } else if (fc != null) {
      cell.cellStyle = CellStyle(bold: bold, fontSize: fs?.toInt() ?? 11,
          fontColorHex: ExcelColor.fromHexString(fc));
    } else {
      cell.cellStyle = CellStyle(bold: bold, fontSize: fs?.toInt() ?? 11);
    }
  }

  Future<void> shareExcel(String path) async {
    await Share.shareXFiles([XFile(path)], text: 'Reporte ERU Heinz');
  }
}
