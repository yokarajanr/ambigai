import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'order_service.dart';

/// Generates a professional PDF invoice from an Order.
class PdfInvoiceService {
  PdfInvoiceService._();

  static const String companyName = 'AMBIGAI BRICKS';
  static const String companyPhone = '+91 98765 43210'; // Update with real number
  static const String companyAddress = 'Brick Manufacturing Unit';

  /// Generate PDF bytes for an order invoice.
  static Future<Uint8List> generatePdf(Order order) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd-MMM-yyyy');
    final now = dateFormat.format(DateTime.now());
    final orderDate = dateFormat.format(order.createdAt);
    final deliveryDate = order.deliveryDate != null
        ? dateFormat.format(order.deliveryDate!)
        : 'N/A';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        header: (context) => pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#1A1F36'),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    companyName,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    companyAddress,
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                  ),
                  pw.Text(
                    companyPhone,
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                  ),
                ],
              ),
              pw.Text(
                'INVOICE',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Thank you for your business!',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F3F4F6'),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Bill To', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(order.customerName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                        pw.Text('Phone: ${order.customerPhone}', style: const pw.TextStyle(fontSize: 10)),
                      if (order.customerAddress != null && order.customerAddress!.isNotEmpty)
                        pw.Text('Address: ${order.customerAddress}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Container(
                width: 180,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Invoice No', order.orderNumber ?? order.id.substring(0, 8)),
                    _infoRow('Date', now),
                    _infoRow('Order Date', orderDate),
                    if (order.dcNumber != null && order.dcNumber!.isNotEmpty)
                      _infoRow('DC Number', order.dcNumber!),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          _buildItemsTable(order),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 230,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#FAFAFA'),
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  _totalRow('Subtotal', '₹${order.totalAmount.toStringAsFixed(2)}'),
                  if (order.discount > 0)
                    _totalRow('Discount', '-₹${order.discount.toStringAsFixed(2)}', isRed: true),
                  pw.Divider(height: 10, thickness: 1),
                  _totalRow('Net Total', '₹${order.effectiveAmount.toStringAsFixed(2)}', isBold: true),
                  pw.SizedBox(height: 6),
                  _totalRow('Amount Paid', '₹${order.amountPaid.toStringAsFixed(2)}'),
                  if (order.balanceAmount > 0)
                    _totalRow('Balance Due', '₹${order.balanceAmount.toStringAsFixed(2)}', isRed: true, isBold: true),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Delivery Status', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    pw.Text(order.status.displayName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Delivery Date', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    pw.Text(deliveryDate, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Payment', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    pw.Text(order.paymentStatus.displayName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildItemsTable(Order order) {
    final headers = ['#', 'Product', 'Qty', 'Rate', 'Amount'];
    final data = <List<String>>[];

    for (int i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      final name = (item['product_name'] ?? item['brick_type'] ?? 'Brick') as String;
      final qty = '${item['quantity'] ?? 0}';
      final rateValue = (item['rate'] ?? item['price_per_unit'] ?? 0) as num;
      final amountValue = (item['amount'] ?? item['total_price'] ?? 0) as num;
      final rate = '₹${rateValue.toStringAsFixed(2)}';
      final amount = '₹${amountValue.toStringAsFixed(2)}';
      data.add(['${i + 1}', name, qty, rate, amount]);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1A1F36')),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      columnWidths: {
        0: const pw.FixedColumnWidth(24),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FixedColumnWidth(40),
        3: const pw.FixedColumnWidth(68),
        4: const pw.FixedColumnWidth(72),
      },
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      headerAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      border: pw.TableBorder.all(color: PdfColors.grey300),
      oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F9FAFB')),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$label: ', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value, {bool isBold = false, bool isRed = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(
            fontSize: isBold ? 12 : 10,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isRed ? PdfColors.red : PdfColors.black,
          )),
        ],
      ),
    );
  }

  /// Generate PDF and share it.
  static Future<void> shareInvoice(Order order) async {
    final bytes = await generatePdf(order);
    final fileName = 'Invoice_${order.orderNumber ?? order.id.substring(0, 8)}.pdf';

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name: fileName,
          ),
        ],
        fileNameOverrides: [fileName],
        text: 'Invoice for ${order.customerName}',
      ),
    );
  }

  /// Generate PDF and trigger platform save/share flow.
  static Future<String> saveInvoice(Order order) async {
    final bytes = await generatePdf(order);
    final fileName = 'Invoice_${order.orderNumber ?? order.id.substring(0, 8)}.pdf';

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name: fileName,
          ),
        ],
        fileNameOverrides: [fileName],
        text: 'Invoice for ${order.customerName}',
      ),
    );

    return fileName;
  }
}
