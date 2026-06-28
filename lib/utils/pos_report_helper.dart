// lib/utils/pos_report_helper.dart
//
// Generates all POS PDF reports matching the reference PDF layouts:
//   1. Purchase Order Listing   (simple list of all items)
//   2. Purchase by Invoice      (grouped by invoice / purchase ID)
//   3. Purchase by Date         (grouped by date)
//   4. Purchase by Supplier     (grouped by supplier)
//   5. Sale Invoice A4          (full invoice with logo, KHR conversion)
//   6. Sale Invoice (compact)   (same data, alternate layout)
//
// Uses: pdf + printing packages (already in pubspec).
// No logic changes to providers or API — only reads data passed in.

import 'dart:typed_data';
import 'package:flutter/material.dart' show BuildContext;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/purchase_model.dart';
import '../models/order_model.dart';
import 'formatter.dart';

// ── Brand colours (match AppTheme) ────────────────────────────────────────────
const _primary  = PdfColor.fromInt(0xFF880E4F);
const _primaryLt= PdfColor.fromInt(0xFFFCE4EC);
const _textDark = PdfColor.fromInt(0xFF1A1A2E);
const _textGrey = PdfColor.fromInt(0xFF888888);
const _border   = PdfColor.fromInt(0xFFEEEEEE);
const _rowAlt   = PdfColor.fromInt(0xFFFFF3F7);
const _white    = PdfColors.white;

const _khrRate  = 4100.0;

// ════════════════════════════════════════════════════════════════════════════
//  PUBLIC API
// ════════════════════════════════════════════════════════════════════════════

/// Print / share a purchase report.
/// [mode] = 'listing' | 'byInvoice' | 'byDate' | 'bySupplier'
Future<void> printPurchaseReport({
  required BuildContext context,
  required String mode,
  required String pageFormat, // 'a4' | 'compact'
  required List<PurchaseModel> purchases,
  required DateTime from,
  required DateTime to,
  String? supplierFilter,
  String? note,
}) async {
  final bytes = await _buildPurchasePdf(
    mode: mode,
    pageFormat: pageFormat,
    purchases: purchases,
    from: from,
    to: to,
    supplierFilter: supplierFilter,
    note: note,
  );
  final titles = {
    'listing':    'POSPurchaseOrderListingReport',
    'byInvoice':  'POSPurchaseOrderByInvoiceReport',
    'byDate':     'POSPurchaseOrderByDateReport',
    'bySupplier': 'POSPurchaseOrderBySupplierReport',
  };
  final title = titles[mode] ?? 'POSReport';
  final now   = DateTime.now();
  final stamp = '${now.year}${_p2(now.month)}${_p2(now.day)}_${_p2(now.hour)}${_p2(now.minute)}${_p2(now.second)}';
  await Printing.layoutPdf(
    onLayout: (format) async => bytes,
    name: '${title}_$stamp',
  );
}

/// Print / share a sale invoice.
/// [mode] = 'a4' | 'compact'
Future<void> printSaleInvoice({
  required BuildContext context,
  required String mode,
  required OrderModel order,
  required String storeName,
  String? logoUrl,
}) async {
  final bytes = mode == 'a4'
      ? await _buildSaleInvoiceA4(order: order, storeName: storeName)
      : await _buildSaleInvoiceCompact(order: order, storeName: storeName);
  final now   = DateTime.now();
  final stamp = '${now.year}${_p2(now.month)}${_p2(now.day)}_${_p2(now.hour)}${_p2(now.minute)}${_p2(now.second)}';
  final name  = mode == 'a4' ? 'POSSaleInvoiceA5Report' : 'POSSaleInvoiceReport';
  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => bytes,
    name: '${name}_$stamp',
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  PURCHASE PDF BUILDER
// ════════════════════════════════════════════════════════════════════════════

Future<Uint8List> _buildPurchasePdf({
  required String mode,
  required String pageFormat,
  required List<PurchaseModel> purchases,
  required DateTime from,
  required DateTime to,
  String? supplierFilter,
  String? note,
}) async {
  final font = await PdfGoogleFonts.nokoraRegular();
  final fontBold = await PdfGoogleFonts.nokoraBold();
  final doc     = pw.Document(
    theme: pw.ThemeData.withFont(
      base: font,
      bold: fontBold,
    ),
  );
  final dateRange = '${_fmtDate(from)} ~${_fmtDate(to)}';
  final printed   = 'ថ្ងៃព្រីន ៖ ${_fmtDate(DateTime.now())}';

  final titles = {
    'listing':    'វិក្កយបត្របញ្ជាទិញ',
    'byInvoice':  'វិក្កយបត្របញ្ជាទិញតាមវិក្កយបត្រ',
    'byDate':     'វិក្កយបត្របញ្ជាទិញតាមកាលបរិច្ឆេទ',
    'bySupplier': 'វិក្កយបត្របញ្ជាទិញអ្នកផ្គត់ផ្គង់',
  };
  final title = titles[mode] ?? 'របាយការណ៍';
  
  final isA4 = pageFormat == 'a4';
  final format = isA4
      ? PdfPageFormat.a4
      : const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm);

  doc.addPage(pw.MultiPage(
    pageFormat: format,
    margin: isA4 ? const pw.EdgeInsets.fromLTRB(28, 28, 28, 40) : const pw.EdgeInsets.fromLTRB(10, 10, 10, 15),
    footer: isA4 ? _footer : null,
    build: (ctx) => [
      // ── Page title ───────────────────────────────────────────────────────
      pw.Center(child: pw.Text(title,
          style: pw.TextStyle(fontSize: isA4 ? 16 : 11, fontWeight: pw.FontWeight.bold,
              color: _primary))),
      pw.SizedBox(height: 4),
      pw.Center(child: pw.Text(dateRange,
          style: pw.TextStyle(fontSize: isA4 ? 10 : 8, color: _textGrey))),
      if (supplierFilter != null && supplierFilter.trim().isNotEmpty) ...[
        pw.SizedBox(height: 2),
        pw.Center(child: pw.Text('អ្នកផ្គត់ផ្គង់ ៖ $supplierFilter',
            style: pw.TextStyle(fontSize: isA4 ? 10 : 8, color: _textDark, fontWeight: pw.FontWeight.bold))),
      ],
      pw.Center(child: pw.Text(printed,
          style: pw.TextStyle(fontSize: isA4 ? 10 : 8, color: _textGrey))),
      pw.SizedBox(height: isA4 ? 14 : 6),

      // ── Supplier header (bySupplier mode only) ───────────────────────────
      if (mode == 'bySupplier' && supplierFilter != null) ...[
        _groupHeader('អ្នកផ្គត់ផ្គង់', supplierFilter, isA4),
        pw.SizedBox(height: 6),
      ],

      // ── Body ─────────────────────────────────────────────────────────────
      if (mode == 'listing')    ..._buildListing(purchases, isA4)
      else if (mode == 'byInvoice')  ..._buildByInvoice(purchases, isA4)
      else if (mode == 'byDate')     ..._buildByDate(purchases, isA4)
      else if (mode == 'bySupplier') ..._buildBySupplier(purchases, isA4),

      // ── Note ─────────────────────────────────────────────────────────────
      pw.SizedBox(height: 16),
      pw.Divider(color: _border, thickness: 0.5),
      pw.SizedBox(height: 4),
      pw.Text('ចំណាំ ៖  ${note?.trim().isNotEmpty == true ? note! : ""}',
          style: pw.TextStyle(fontSize: isA4 ? 9 : 7, color: _textGrey)),
    ],
  ));

  return doc.save();
}

// ── LISTING mode: one flat table, all items ──────────────────────────────────
List<pw.Widget> _buildListing(List<PurchaseModel> purchases, bool isA4) {
  final allItems = <_FlatRow>[];
  int idx = 1;
  for (final p in purchases) {
    for (final item in p.items) {
      allItems.add(_FlatRow(idx: idx++, item: item));
    }
  }
  if (allItems.isEmpty) return [_emptyNote()];

  final totalQty  = allItems.fold(0,    (s, r) => s + r.item.quantity);
  final totalCost = allItems.fold(0.0,  (s, r) => s + r.item.unitCost);
  final totalSub  = allItems.fold(0.0,  (s, r) => s + r.item.unitCost * r.item.quantity);

  return [
    _itemsTable(allItems, isA4),
    pw.SizedBox(height: 4),
    _totalRow(totalQty, totalCost, totalSub, isA4),
    ..._signatureBlock(isA4),
  ];
}

// ── BY INVOICE mode: one section per purchase ─────────────────────────────────
List<pw.Widget> _buildByInvoice(List<PurchaseModel> purchases, bool isA4) {
  if (purchases.isEmpty) return [_emptyNote()];
  final widgets = <pw.Widget>[];
  int grandQty = 0; double grandCost = 0; double grandSub = 0;

  for (final p in purchases) {
    widgets.add(_groupHeader('លេខរៀង', 'INV-${p.id.padLeft(6, '0')}', isA4));
    widgets.add(pw.SizedBox(height: 4));

    final rows = <_FlatRow>[];
    int idx = 1;
    for (final item in p.items) {
      rows.add(_FlatRow(idx: idx++, item: item));
    }

    if (rows.isEmpty) {
      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(left: 8, bottom: 8),
        child: pw.Text('មិនមានធាតុ',
            style: pw.TextStyle(fontSize: isA4 ? 9 : 7, color: _textGrey)),
      ));
    } else {
      widgets.add(_itemsTable(rows, isA4));
      final qty  = rows.fold(0,   (s, r) => s + r.item.quantity);
      final cost = rows.fold(0.0, (s, r) => s + r.item.unitCost);
      final sub  = rows.fold(0.0, (s, r) => s + r.item.unitCost * r.item.quantity);
      grandQty  += qty;
      grandCost += cost;
      grandSub  += sub;
      widgets.add(_subTotalRow(qty, cost, sub, isA4));
    }
    widgets.add(pw.SizedBox(height: 10));
  }

  widgets.add(pw.SizedBox(height: 4));
  widgets.add(_totalRow(grandQty, grandCost, grandSub, isA4));
  widgets.addAll(_signatureBlock(isA4));
  return widgets;
}

// ── BY DATE mode: group by date ───────────────────────────────────────────────
List<pw.Widget> _buildByDate(List<PurchaseModel> purchases, bool isA4) {
  if (purchases.isEmpty) return [_emptyNote()];

  // Group purchases by date string
  final Map<String, List<PurchaseModel>> grouped = {};
  for (final p in purchases) {
    final key = _fmtDate(p.createdAt).replaceAll('/', '-');
    grouped.putIfAbsent(key, () => []).add(p);
  }

  final widgets = <pw.Widget>[];
  int grandQty = 0; double grandCost = 0; double grandSub = 0;

  for (final entry in grouped.entries) {
    widgets.add(_groupHeader('កាលបរិច្ឆេទ', entry.key, isA4));
    widgets.add(pw.SizedBox(height: 4));

    final rows = <_FlatRow>[];
    int idx = 1;
    for (final p in entry.value) {
      for (final item in p.items) {
        rows.add(_FlatRow(idx: idx++, item: item));
      }
    }

    if (rows.isNotEmpty) {
      widgets.add(_itemsTable(rows, isA4));
      final qty  = rows.fold(0,   (s, r) => s + r.item.quantity);
      final cost = rows.fold(0.0, (s, r) => s + r.item.unitCost);
      final sub  = rows.fold(0.0, (s, r) => s + r.item.unitCost * r.item.quantity);
      grandQty  += qty;
      grandCost += cost;
      grandSub  += sub;
      widgets.add(_subTotalRow(qty, cost, sub, isA4));
    }
    widgets.add(pw.SizedBox(height: 10));
  }

  widgets.add(_totalRow(grandQty, grandCost, grandSub, isA4));
  widgets.addAll(_signatureBlock(isA4));
  return widgets;
}

// ── BY SUPPLIER mode: group by supplier ──────────────────────────────────────
List<pw.Widget> _buildBySupplier(List<PurchaseModel> purchases, bool isA4) {
  if (purchases.isEmpty) return [_emptyNote()];

  final Map<String, List<PurchaseModel>> grouped = {};
  for (final p in purchases) {
    final key = p.supplierName?.trim().isNotEmpty == true
        ? p.supplierName!
        : 'Unknown Supplier';
    grouped.putIfAbsent(key, () => []).add(p);
  }

  final widgets = <pw.Widget>[];
  int grandQty = 0; double grandCost = 0; double grandSub = 0;

  for (final entry in grouped.entries) {
    widgets.add(_groupHeader('អ្នកផ្គត់ផ្គង់', entry.key, isA4));
    widgets.add(pw.SizedBox(height: 4));

    final rows = <_FlatRow>[];
    int idx = 1;
    for (final p in entry.value) {
      for (final item in p.items) {
        rows.add(_FlatRow(idx: idx++, item: item));
      }
    }

    if (rows.isNotEmpty) {
      widgets.add(_itemsTable(rows, isA4));
      final qty  = rows.fold(0,   (s, r) => s + r.item.quantity);
      final cost = rows.fold(0.0, (s, r) => s + r.item.unitCost);
      final sub  = rows.fold(0.0, (s, r) => s + r.item.unitCost * r.item.quantity);
      grandQty  += qty;
      grandCost += cost;
      grandSub  += sub;
      widgets.add(_subTotalRow(qty, cost, sub, isA4));
    }
    widgets.add(pw.SizedBox(height: 10));
  }

  widgets.add(_totalRow(grandQty, grandCost, grandSub, isA4));
  widgets.addAll(_signatureBlock(isA4));
  return widgets;
}

// ── Shared purchase table ──────────────────────────────────────────────────────
pw.Widget _itemsTable(List<_FlatRow> rows, bool isA4) {
  return pw.Table(
    columnWidths: isA4
        ? const {
            0: pw.FixedColumnWidth(26),
            1: pw.FixedColumnWidth(58),
            2: pw.FlexColumnWidth(3),
            3: pw.FixedColumnWidth(40),
            4: pw.FixedColumnWidth(58),
            5: pw.FixedColumnWidth(58),
          }
        : const {
            0: pw.FixedColumnWidth(14),
            1: pw.FlexColumnWidth(2.5),
            2: pw.FixedColumnWidth(18),
            3: pw.FixedColumnWidth(30),
            4: pw.FixedColumnWidth(36),
          },
    children: [
      // Header
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _primary),
        children: isA4
            ? [
                _th('ល.រ',       align: pw.TextAlign.center, color: _white),
                _th('លេខកូដ',     color: _white),
                _th('ឈ្មោះទំនិញ', color: _white),
                _th('ចំនួន',     align: pw.TextAlign.center, color: _white),
                _th('តម្លៃឯកតា', align: pw.TextAlign.right, color: _white),
                _th('តម្លៃសរុប', align: pw.TextAlign.right, color: _white),
              ]
            : [
                _th('ល.រ',       align: pw.TextAlign.center, color: _white),
                _th('ឈ្មោះទំនិញ', color: _white),
                _th('ចំនួន',     align: pw.TextAlign.center, color: _white),
                _th('តម្លៃឯកតា', align: pw.TextAlign.right, color: _white),
                _th('តម្លៃសរុប', align: pw.TextAlign.right, color: _white),
              ],
      ),
      // Rows
      for (int i = 0; i < rows.length; i++) ...[
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: i.isOdd ? _rowAlt : _white,
            border: const pw.Border(
              bottom: pw.BorderSide(color: _border, width: 0.4),
            ),
          ),
          children: isA4
              ? [
                  _td('${rows[i].idx}', align: pw.TextAlign.center),
                  _td(rows[i].item.productCode),
                  _td(rows[i].item.productName),
                  _td('${rows[i].item.quantity}', align: pw.TextAlign.center),
                  _td(Formatter.currency(rows[i].item.unitCost), align: pw.TextAlign.right),
                  _td(Formatter.currency(rows[i].item.unitCost * rows[i].item.quantity),
                      align: pw.TextAlign.right, bold: true),
                ]
              : [
                  _td('${rows[i].idx}', align: pw.TextAlign.center),
                  _td(rows[i].item.productName),
                  _td('${rows[i].item.quantity}', align: pw.TextAlign.center),
                  _td(Formatter.currency(rows[i].item.unitCost), align: pw.TextAlign.right),
                  _td(Formatter.currency(rows[i].item.unitCost * rows[i].item.quantity),
                      align: pw.TextAlign.right, bold: true),
                ],
        ),
      ],
    ],
  );
}

pw.Widget _subTotalRow(int qty, double cost, double sub, bool isA4) {
  return pw.Table(
    columnWidths: isA4
        ? const {
            0: pw.FlexColumnWidth(1),
            1: pw.FixedColumnWidth(40),
            2: pw.FixedColumnWidth(58),
            3: pw.FixedColumnWidth(58),
          }
        : const {
            0: pw.FlexColumnWidth(1),
            1: pw.FixedColumnWidth(18),
            2: pw.FixedColumnWidth(30),
            3: pw.FixedColumnWidth(36),
          },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _primary, width: 0.8))),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            child: pw.Text('សរុប', style: pw.TextStyle(fontSize: isA4 ? 9 : 7, fontWeight: pw.FontWeight.bold, color: _primary), textAlign: pw.TextAlign.right),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            child: pw.Text('$qty', style: pw.TextStyle(fontSize: isA4 ? 9 : 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            child: pw.Text(Formatter.currency(cost), style: pw.TextStyle(fontSize: isA4 ? 9 : 7), textAlign: pw.TextAlign.right),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            child: pw.Text(Formatter.currency(sub), style: pw.TextStyle(fontSize: isA4 ? 9 : 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
          ),
        ]
      )
    ]
  );
}

pw.Widget _totalRow(int qty, double cost, double sub, bool isA4) {
  return pw.Table(
    columnWidths: isA4
        ? const {
            0: pw.FlexColumnWidth(1),
            1: pw.FixedColumnWidth(40),
            2: pw.FixedColumnWidth(58),
            3: pw.FixedColumnWidth(58),
          }
        : const {
            0: pw.FlexColumnWidth(1),
            1: pw.FixedColumnWidth(18),
            2: pw.FixedColumnWidth(30),
            3: pw.FixedColumnWidth(36),
          },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _primaryLt),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            child: pw.Text('សរុប', style: pw.TextStyle(fontSize: isA4 ? 9.5 : 7.5, fontWeight: pw.FontWeight.bold, color: _primary), textAlign: pw.TextAlign.right),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            child: pw.Text('$qty', style: pw.TextStyle(fontSize: isA4 ? 9.5 : 7.5, fontWeight: pw.FontWeight.bold, color: _primary), textAlign: pw.TextAlign.center),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            child: pw.Text(Formatter.currency(cost), style: pw.TextStyle(fontSize: isA4 ? 9.5 : 7.5, fontWeight: pw.FontWeight.bold, color: _primary), textAlign: pw.TextAlign.right),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            child: pw.Text(Formatter.currency(sub), style: pw.TextStyle(fontSize: isA4 ? 9.5 : 7.5, fontWeight: pw.FontWeight.bold, color: _primary), textAlign: pw.TextAlign.right),
          ),
        ]
      )
    ]
  );
}

// ── Signature block ────────────────────────────────────────────────────────────
List<pw.Widget> _signatureBlock(bool isA4) => isA4
    ? [
        pw.SizedBox(height: 30),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _sigCol('ហត្ថលេខាអ្នកផ្គត់ផ្គង់'),
            _sigCol('ហត្ថលេខាអ្នកត្រួតពិនិត្យ'),
            _sigCol('ហត្ថលេខាអ្នកកាន់ស្តុក'),
          ],
        ),
      ]
    : [];

pw.Widget _sigCol(String label) => pw.SizedBox(
  width: 150,
  child: pw.Column(children: [
    pw.SizedBox(height: 28),
    pw.Divider(color: _textGrey, thickness: 0.5),
    pw.SizedBox(height: 4),
    pw.Text(label,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _textDark)),
  ]),
);

pw.Widget _groupHeader(String label, String value, bool isA4) => pw.Container(
  padding: pw.EdgeInsets.symmetric(horizontal: isA4 ? 10 : 6, vertical: isA4 ? 5 : 3),
  decoration: const pw.BoxDecoration(color: _primaryLt),
  child: pw.Row(children: [
    pw.Text('$label   ',
        style: pw.TextStyle(fontSize: isA4 ? 9.5 : 8, fontWeight: pw.FontWeight.bold, color: _primary)),
    pw.Text(value,
        style: pw.TextStyle(fontSize: isA4 ? 9.5 : 8, fontWeight: pw.FontWeight.bold, color: _textDark)),
  ]),
);

pw.Widget _emptyNote() => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 16),
  child: pw.Center(child: pw.Text('មិនមានទិន្នន័យ',
      style: const pw.TextStyle(fontSize: 10, color: _textGrey))),
);

// ════════════════════════════════════════════════════════════════════════════
//  SALE INVOICE A4  (reference: POSSaleInvoiceA5Report PDF)
// ════════════════════════════════════════════════════════════════════════════

Future<Uint8List> _buildSaleInvoiceA4({
  required OrderModel order,
  required String storeName,
}) async {
  final font = await PdfGoogleFonts.nokoraRegular();
  final fontBold = await PdfGoogleFonts.nokoraBold();
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: font,
      bold: fontBold,
    ),
  );

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 40),
    build: (ctx) {
      final discount = order.discountTotal;
      final khrTotal = (order.totalAmount * _khrRate).round();

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Header: store name + invoice meta ────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 4,
                height: 32,
                decoration: const pw.BoxDecoration(
                  color: _primary,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(storeName,
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold,
                          color: _textDark)),
                  pw.Text('វិក្កយបត្រ / INVOICE',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold,
                          color: _primary)),
                ],
              )),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                _metaRow2('លេខវិក្កយបត្រ', order.transactionRef),
                _metaRow2('ថ្ងៃចេញវិក្កយបត្រ',
                    order.createdAt != null ? Formatter.dateTime(order.createdAt!) : '-'),
              ]),
            ],
          ),
          pw.SizedBox(height: 14),

          // ── Customer info section ─────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const pw.BoxDecoration(
              color: _primaryLt,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(children: [
                  pw.Expanded(child: _infoBox('អតិថិជន', '-')),
                  pw.SizedBox(width: 14),
                  pw.Expanded(child: _infoBox('លេខទូរស័ព្ទ', '-')),
                ]),
                pw.SizedBox(height: 4),
                _infoBox('ទីតាំង', '-'),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── Items table ───────────────────────────────────────────────
          pw.Table(
            columnWidths: const {
              0: pw.FixedColumnWidth(26),
              1: pw.FixedColumnWidth(54),
              2: pw.FlexColumnWidth(3),
              3: pw.FixedColumnWidth(36),
              4: pw.FixedColumnWidth(50),
              5: pw.FixedColumnWidth(58),
              6: pw.FixedColumnWidth(58),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _primary),
                children: [
                  _th('ល.រ',         align: pw.TextAlign.center, color: _white),
                  _th('លេខកូដ',     color: _white),
                  _th('ឈ្មោះទំនិញ', color: _white),
                  _th('ចំនួន',       align: pw.TextAlign.center, color: _white),
                  _th('តម្លៃ',       align: pw.TextAlign.right, color: _white),
                  _th('បញ្ចុះតម្លៃ', align: pw.TextAlign.right, color: _white),
                  _th('សរុប',        align: pw.TextAlign.right, color: _white),
                ],
              ),
              for (int i = 0; i < order.items.length; i++) ...[
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: i.isOdd ? _rowAlt : _white,
                    border: const pw.Border(
                      bottom: pw.BorderSide(color: _border, width: 0.4),
                    ),
                  ),
                  children: [
                    _td('${i + 1}', align: pw.TextAlign.center),
                    _td(order.items[i].productCode),
                    _td(order.items[i].productName),
                    _td('${order.items[i].quantity}', align: pw.TextAlign.center),
                    _td(Formatter.currency(order.items[i].unitPrice),
                        align: pw.TextAlign.right),
                    _td(_pctDiscount(order.items[i]), align: pw.TextAlign.right),
                    _td(Formatter.currency(order.items[i].subTotal),
                        align: pw.TextAlign.right, bold: true),
                  ],
                ),
              ],
            ],
          ),
          pw.SizedBox(height: 16),

          // ── Totals + note ─────────────────────────────────────────────
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            // Note
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ចំណាំ ៖', style: const pw.TextStyle(fontSize: 9, color: _textGrey)),
                pw.SizedBox(height: 10),
                pw.Container(
                  width: 70,
                  height: 70,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: order.transactionRef,
                    drawText: false,
                  ),
                ),
              ],
            )),
            // Totals
            pw.SizedBox(width: 180,
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                _totalLine('សរុបរង',  Formatter.currency(order.subtotalAmount)),
                _totalLine('បញ្ចុះថ្លៃ', Formatter.currency(discount),
                    valueColor: _primary),
                pw.Divider(color: _border, thickness: 0.5),
                _totalLine('សរុបដុល្លារ', Formatter.currency(order.totalAmount),
                    bold: true, valueColor: _primary),
                _totalLine('អត្រាប្តូរក្នុង', '៛ ${_khrRate.toInt()}'),
                _totalLine('សរុបប្រាក់រៀល', '៛ ${_fmtKhr(khrTotal)}',
                    bold: true, valueColor: _primary),
              ]),
            ),
          ]),

          pw.Spacer(),
          pw.Divider(color: _border, thickness: 0.5),
          pw.SizedBox(height: 10),

          // ── Signature row ─────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _sigCol('ហត្ថលេខាអ្នកលក់'),
              _sigCol('ហត្ថលេខាអ្នកកាន់ស្តុក'),
              _sigCol('ហត្ថលេខាអតិថិជន'),
            ],
          ),
        ],
      );
    },
  ));

  return doc.save();
}

// ════════════════════════════════════════════════════════════════════════════
//  SALE INVOICE COMPACT  (reference: POSSaleInvoiceReport PDF)
// ════════════════════════════════════════════════════════════════════════════

Future<Uint8List> _buildSaleInvoiceCompact({
  required OrderModel order,
  required String storeName,
}) async {
  final font = await PdfGoogleFonts.nokoraRegular();
  final fontBold = await PdfGoogleFonts.nokoraBold();
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: font,
      bold: fontBold,
    ),
  );

  doc.addPage(pw.Page(
    pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity,
        marginAll: 4 * PdfPageFormat.mm),
    build: (ctx) {
      final discount = order.discountTotal;
      final khrTotal = (order.totalAmount * _khrRate).round();

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Center Header ─────────────────────────────────────────────
          pw.Center(
            child: pw.Text(
              storeName,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _textDark),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Center(
            child: pw.Text(
              'វិក្កយបត្រ / RECEIPT',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _primary),
            ),
          ),
          pw.SizedBox(height: 6),

          // Meta Info
          pw.Text('វិក្កយបត្រ #: ${order.transactionRef}', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Text('ថ្ងៃចេញ: ${order.createdAt != null ? Formatter.dateTime(order.createdAt!) : '-'}', style: const pw.TextStyle(fontSize: 7.5)),
          if (order.paymentName != null)
            pw.Text('វិធីទូទាត់: ${order.paymentName}', style: const pw.TextStyle(fontSize: 7.5)),
          pw.SizedBox(height: 4),

          // Ticket Number
          if (order.id.isNotEmpty)
            pw.Center(
              child: pw.Container(
                margin: const pw.EdgeInsets.symmetric(vertical: 6),
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: const pw.BoxDecoration(
                  color: _primaryLt,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  'Ticket Number ${order.id}',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _primary),
                ),
              ),
            ),
          pw.Divider(color: _border, thickness: 0.5),

          // ── Items table ───────────────────────────────────────────────
          pw.Table(
            columnWidths: const {
              0: pw.FixedColumnWidth(14),  // ល.រ
              1: pw.FlexColumnWidth(3),    // ឈ្មោះទំនិញ
              2: pw.FixedColumnWidth(18),  // ចំនួន
              3: pw.FixedColumnWidth(30),  // តម្លៃ
              4: pw.FixedColumnWidth(36),  // សរុប
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _primary),
                children: [
                  _th('ល.រ', align: pw.TextAlign.center, color: _white),
                  _th('ឈ្មោះទំនិញ', color: _white),
                  _th('ចំនួន', align: pw.TextAlign.center, color: _white),
                  _th('តម្លៃ', align: pw.TextAlign.right, color: _white),
                  _th('សរុប', align: pw.TextAlign.right, color: _white),
                ],
              ),
              for (int i = 0; i < order.items.length; i++)
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.4)),
                  ),
                  children: [
                    _td('${i + 1}', align: pw.TextAlign.center),
                    _td(order.items[i].productName),
                    _td('${order.items[i].quantity}', align: pw.TextAlign.center),
                    _td(Formatter.currency(order.items[i].unitPrice), align: pw.TextAlign.right),
                    _td(Formatter.currency(order.items[i].subTotal), align: pw.TextAlign.right, bold: true),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 8),

          // ── Totals ────────────────────────────────────────────────────
          pw.Divider(color: _textDark, thickness: 0.5),
          _totalLineCompact('សរុបរង:', Formatter.currency(order.subtotalAmount)),
          if (discount > 0)
            _totalLineCompact('បញ្ចុះតម្លៃ:', '-${Formatter.currency(discount)}', valueColor: _primary),
          pw.Divider(color: _border, thickness: 0.5),
          _totalLineCompact('សរុប USD:', Formatter.currency(order.totalAmount), bold: true),
          _totalLineCompact('អត្រាប្តូរ:', '៛ ${_fmtKhr(_khrRate.toInt())}'),
          _totalLineCompact('សរុបរៀល:', '៛ ${_fmtKhr(khrTotal)}', bold: true, valueColor: _primary),
          pw.Divider(color: _textDark, thickness: 0.5),
          pw.SizedBox(height: 6),

          // Footer
          pw.Center(child: pw.Text('WIFI: rosiecoffee8888', style: const pw.TextStyle(fontSize: 7.5))),
          pw.Center(child: pw.Text('សូមអរគុណ! សូមអញ្ជើញមកម្តងទៀត', style: const pw.TextStyle(fontSize: 7.5, color: _textGrey))),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Container(
              width: 55,
              height: 55,
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: order.transactionRef,
                drawText: false,
              ),
            ),
          ),
        ],
      );
    },
  ));

  return doc.save();
}

pw.Widget _totalLineCompact(String label, String value, {bool bold = false, PdfColor? valueColor}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 7.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: valueColor)),
        ],
      ),
    );

// ════════════════════════════════════════════════════════════════════════════
//  SMALL HELPER WIDGETS
// ════════════════════════════════════════════════════════════════════════════

pw.Widget _th(String t, {pw.TextAlign align = pw.TextAlign.left, PdfColor color = _textDark}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(t,
          textAlign: align,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
              color: _textDark)),
    );

pw.Widget _td(String t,
    {pw.TextAlign align = pw.TextAlign.left, bool bold = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(t,
          textAlign: align,
          style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: _textDark)),
    );

pw.Widget _metaRow2(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 2),
  child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
    pw.Text('$label ៖  ',
        style: const pw.TextStyle(fontSize: 9, color: _textGrey)),
    pw.Text(value,
        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold,
            color: _textDark)),
  ]),
);

pw.Widget _infoBox(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 1),
  child: pw.Row(children: [
    pw.Text('$label ៖  ',
        style: const pw.TextStyle(fontSize: 9.5, color: _textGrey)),
    pw.Text(value,
        style: const pw.TextStyle(fontSize: 9.5, color: _textDark)),
  ]),
);

pw.Widget _totalLine(String label, String value,
    {bool bold = false, PdfColor? valueColor}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: bold ? 10 : 9,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: _textGrey)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: bold ? 10.5 : 9.5,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: valueColor ?? _textDark)),
        ],
      ),
    );

pw.Widget Function(pw.Context) get _footer => (ctx) => pw.Container(
  alignment: pw.Alignment.centerRight,
  margin: const pw.EdgeInsets.only(top: 8),
  child: pw.Text(
    'ទំព័រ ${ctx.pageNumber} / ${ctx.pagesCount}',
    style: const pw.TextStyle(fontSize: 8, color: _textGrey),
  ),
);

// ── Utils ──────────────────────────────────────────────────────────────────────
class _FlatRow {
  final int idx;
  final PurchaseItemModel item;
  const _FlatRow({required this.idx, required this.item});
}

String _fmtDate(DateTime d) =>
    '${_p2(d.day)}/${_p2(d.month)}/${d.year}';

String _p2(int v) => v.toString().padLeft(2, '0');

String _fmtKhr(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _pctDiscount(OrderItemModel item) {
  if (item.unitPrice <= 0) return '0.00%';
  final pct = ((item.unitPrice - item.discountedUnitPrice) / item.unitPrice * 100);
  return '${pct.toStringAsFixed(2)}%';
}
