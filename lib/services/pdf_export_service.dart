import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/animal.dart';

class PdfExportService {
  static final PdfExportService instance = PdfExportService._init();

  PdfExportService._init();

  /// Genera un certificado de trazabilidad PDF y lo comparte.
  Future<void> exportTraceabilityCertificate(Animal animal) async {
    final pdf = pw.Document();

    final qrToken = animal.qrToken ?? animal.id;
    final publicUrl =
        "https://aura-agro-ai-landing-page.vercel.app/animal/$qrToken";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.green, width: 2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "CERTIFICADO DE TRAZABILIDAD",
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: publicUrl,
                      width: 80,
                      height: 80,
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(color: PdfColors.grey),
                pw.SizedBox(height: 10),
                pw.Text(
                  "DATOS PÚBLICOS DEL ANIMAL:",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildRow("Código / Arete:", animal.tag),
                _buildRow("Raza:", animal.breed),
                _buildRow("Sexo:", animal.sex),
                _buildRow("Categoría:", animal.category),
                _buildRow("Estado General:", animal.status),
                _buildRow("Score de Confianza AURA:", "${animal.score}%"),
                _buildRow("Estatus Sanitario:", animal.healthStatus),
                pw.SizedBox(height: 40),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  color: PdfColors.green50,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "SELLO DIGITAL DE VERIFICACIÓN AURA",
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Este animal ha sido validado electrónicamente en la red Aura Agro AI. Su historial de procedencia y vacunas esenciales han sido confirmados por la plataforma.",
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Token de Certificación: ${qrToken.toUpperCase()}",
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    "Aura Agro AI - Trazabilidad Rural y Sostenible",
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await _sharePdf(
      pdf,
      "certificado_trazabilidad_${animal.tag.replaceAll('#', '')}.pdf",
    );
  }

  /// Genera reporte financiero PDF.
  Future<void> exportFinancialReport(
    double totalIncome,
    double totalExpense,
    List<Map<String, dynamic>> expenses,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "REPORTE FINANCIERO AGROPECUARIO",
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text(
                  "RESUMEN DE SALDOS:",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                _buildRow(
                  "Total Ingresos (Ventas):",
                  "\$${totalIncome.toStringAsFixed(2)}",
                ),
                _buildRow(
                  "Total Gastos Operativos:",
                  "\$${totalExpense.toStringAsFixed(2)}",
                ),
                _buildRow(
                  "Utilidad Estimada:",
                  "\$${(totalIncome - totalExpense).toStringAsFixed(2)}",
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  "GASTOS DETALLADOS:",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                if (expenses.isEmpty)
                  pw.Text(
                    "Sin gastos operativos registrados.",
                    style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                  )
                else
                  pw.TableHelper.fromTextArray(
                    headers: ['Categoría', 'Monto', 'Fecha', 'Descripción'],
                    data: expenses
                        .map(
                          (e) => [
                            e['category'] ?? '',
                            "\$${(e['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}",
                            e['date'] ?? '',
                            e['description'] ?? '',
                          ],
                        )
                        .toList(),
                  ),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    "Aura Agro AI - Sello Digital de Verificación Financiera",
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await _sharePdf(pdf, "reporte_financiero.pdf");
  }

  /// Genera reporte de historial clínico en PDF.
  Future<void> exportClinicalHistory(
    Animal animal,
    List<Map<String, dynamic>> vaccines,
    List<Map<String, dynamic>> treatments,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "HISTORIAL CLÍNICO Y SANITARIO",
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red800,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  "Animal: ${animal.name} (${animal.tag}) - Raza: ${animal.breed}",
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.Divider(),
                pw.SizedBox(height: 15),
                pw.Text(
                  "VACUNAS APLICADAS:",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                if (vaccines.isEmpty)
                  pw.Text(
                    "Sin vacunas registradas.",
                    style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                  )
                else
                  pw.TableHelper.fromTextArray(
                    headers: ['Nombre de Vacuna', 'Fecha', 'Dosis', 'Notas'],
                    data: vaccines
                        .map(
                          (v) => [
                            v['name'] ?? '',
                            v['date_applied'] ?? '',
                            v['dose'] ?? '',
                            v['notes'] ?? '',
                          ],
                        )
                        .toList(),
                  ),
                pw.SizedBox(height: 20),
                pw.Text(
                  "TRATAMIENTOS MÉDICOS:",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                if (treatments.isEmpty)
                  pw.Text(
                    "Sin tratamientos registrados.",
                    style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                  )
                else
                  pw.TableHelper.fromTextArray(
                    headers: [
                      'Diagnóstico',
                      'Tratamiento',
                      'Fecha',
                      'Dosis',
                      'Responsable',
                    ],
                    data: treatments
                        .map(
                          (t) => [
                            t['diagnosis'] ?? '',
                            t['treatment'] ?? '',
                            t['date'] ?? '',
                            "${(t['dose'] as num?)?.toStringAsFixed(1) ?? '0'} ml",
                            t['responsible'] ?? '',
                          ],
                        )
                        .toList(),
                  ),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    "Aura Agro AI - Sello Digital de Verificación Médica",
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await _sharePdf(
      pdf,
      "historial_clinico_${animal.tag.replaceAll('#', '')}.pdf",
    );
  }

  /// Exportación de gastos a CSV.
  Future<void> exportExpensesToCsv(List<Map<String, dynamic>> expenses) async {
    final List<List<dynamic>> rows = [
      ['ID Gasto', 'Categoría', 'Monto', 'Fecha', 'Descripción', 'ID Animal'],
    ];

    for (var e in expenses) {
      rows.add([
        e['id'] ?? '',
        e['category'] ?? '',
        e['amount'] ?? 0.0,
        e['date'] ?? '',
        e['description'] ?? '',
        e['animal_id'] ?? '',
      ]);
    }

    final csvString = Csv().encode(rows);
    await _shareTextFile(csvString, "historial_gastos.csv", "text/csv");
  }

  /// Exportación de animales a CSV.
  Future<void> exportAnimalsToCsv(List<Animal> animals) async {
    final List<List<dynamic>> rows = [
      [
        'ID',
        'Nombre',
        'Arete/Tag',
        'Categoría',
        'Raza',
        'Sexo',
        'Peso (kg)',
        'Estado',
        'Propósito',
        'Condición Corporal',
      ],
    ];

    for (var a in animals) {
      rows.add([
        a.id,
        a.name,
        a.tag,
        a.category,
        a.breed,
        a.sex,
        a.weightKg,
        a.status,
        a.purpose,
        a.bodyCondition,
      ]);
    }

    final csvString = Csv().encode(rows);
    await _shareTextFile(csvString, "registro_animales.csv", "text/csv");
  }

  Future<void> exportMedicineInventory(
    List<Map<String, dynamic>> medicines,
    List<Map<String, dynamic>> movements,
  ) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            'INVENTARIO DE MEDICAMENTOS',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green800,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Producto',
              'Tipo',
              'Stock',
              'Unidad',
              'Caducidad',
              'Lote',
            ],
            data: medicines
                .map(
                  (m) => [
                    m['name'] ?? '',
                    m['type'] ?? '',
                    m['quantity'] ?? 0,
                    m['unit'] ?? '',
                    m['expiration_date'] ?? '',
                    m['batch_number'] ?? '',
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Movimientos recientes',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Fecha',
              'Producto ID',
              'Movimiento',
              'Cantidad',
              'Motivo',
            ],
            data: movements
                .take(100)
                .map(
                  (m) => [
                    m['created_at'] ?? '',
                    m['medicine_id'] ?? '',
                    m['movement_type'] ?? '',
                    m['quantity'] ?? 0,
                    m['reason'] ?? '',
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Documento informativo. El uso de medicamentos debe ser revisado por un veterinario.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    await _sharePdf(pdf, 'inventario_medicamentos.pdf');
  }

  Future<void> exportMedicineInventoryCsv(
    List<Map<String, dynamic>> medicines,
  ) async {
    final rows = <List<dynamic>>[
      [
        'ID',
        'Nombre',
        'Principio activo',
        'Tipo',
        'Presentacion',
        'Concentracion',
        'Stock',
        'Unidad',
        'Stock minimo',
        'Caducidad',
        'Lote',
        'Proveedor',
        'Retiro',
      ],
      ...medicines.map(
        (m) => [
          m['id'],
          m['name'],
          m['active_ingredient'],
          m['type'],
          m['presentation'],
          m['concentration'],
          m['quantity'],
          m['unit'],
          m['min_stock'],
          m['expiration_date'],
          m['batch_number'],
          m['provider'],
          m['withdrawal_period'],
        ],
      ),
    ];
    await _shareTextFile(
      Csv().encode(rows),
      'inventario_medicamentos.csv',
      'text/csv',
    );
  }

  Future<void> exportMedicineMovementsCsv(
    List<Map<String, dynamic>> movements,
  ) async {
    final rows = <List<dynamic>>[
      [
        'ID',
        'Medicamento ID',
        'Animal ID',
        'Movimiento',
        'Cantidad',
        'Motivo',
        'Responsable',
        'Fecha',
      ],
      ...movements.map(
        (m) => [
          m['id'],
          m['medicine_id'],
          m['animal_id'],
          m['movement_type'],
          m['quantity'],
          m['reason'],
          m['responsible'],
          m['created_at'],
        ],
      ),
    ];
    await _shareTextFile(
      Csv().encode(rows),
      'movimientos_medicamentos.csv',
      'text/csv',
    );
  }

  // --- MÉTODOS AUXILIARES DE ARCHIVOS ---

  pw.Widget _buildRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Text(
            "$label ",
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(value),
        ],
      ),
    );
  }

  Future<void> _sharePdf(pw.Document pdf, String filename) async {
    try {
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/$filename");
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([
        XFile(file.path),
      ], text: "Compartiendo documento de Aura Agro AI");
    } catch (e) {
      debugPrint("Error al compartir PDF: $e");
    }
  }

  Future<void> _shareTextFile(
    String content,
    String filename,
    String mimeType,
  ) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/$filename");
      await file.writeAsString(content);
      await Share.shareXFiles([
        XFile(file.path),
      ], text: "Exportación de datos de Aura Agro AI");
    } catch (e) {
      debugPrint("Error al compartir texto: $e");
    }
  }
}
