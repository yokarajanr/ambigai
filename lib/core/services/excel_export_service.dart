import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_pkg;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'order_service.dart';

/// Excel export utility for orders and payments.
class ExcelExportService {
  static final dateFormat = DateFormat('dd-MM-yyyy');

  /// Export orders to Excel file with formatting.
  static Future<void> exportOrdersToExcel(
    List<Order> orders, {
    required String fileName,
  }) async {
    if (orders.isEmpty) return;

    final workbook = excel_pkg.Excel.createExcel();
    final sheet = workbook['Orders'];

    // Headers
    final headers = [
      'Order No', 'Customer', 'Phone', 'Order Date', 'Status',
      'Total Amount', 'Discount', 'Net Amount', 'Paid', 'Balance',
      'Payment Status', 'DC Number', 'Delivery Date', 'Items',
    ];

    // Add header row
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = excel_pkg.TextCellValue(headers[i]);
    }

    // Add data rows
    for (var rowIdx = 0; rowIdx < orders.length; rowIdx++) {
      final order = orders[rowIdx];
      final row = [
        order.orderNumber ?? '',
        order.customerName,
        order.customerPhone ?? '',
        dateFormat.format(order.createdAt),
        order.status.displayName,
        order.totalAmount.toStringAsFixed(2),
        order.discount.toStringAsFixed(2),
        order.effectiveAmount.toStringAsFixed(2),
        order.amountPaid.toStringAsFixed(2),
        order.balanceAmount.toStringAsFixed(2),
        order.paymentStatus.displayName,
        order.dcNumber ?? '',
        order.deliveryDate != null ? dateFormat.format(order.deliveryDate!) : '',
        order.items.map((i) => '${i['product_name'] ?? 'Brick'} x${i['quantity']}').join('; '),
      ];

      for (var colIdx = 0; colIdx < row.length; colIdx++) {
        final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: rowIdx + 1));
        cell.value = excel_pkg.TextCellValue(row[colIdx].toString());
      }
    }

    // Auto-adjust column widths
    _adjustColumnWidths(sheet, headers.length, orders.length + 1);

    // Convert to bytes and share
    final bytes = workbook.save();
    if (bytes != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(Uint8List.fromList(bytes), mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: fileName),
          ],
        ),
      );
    }
  }

  /// Export payments to Excel file with formatting.
  static Future<void> exportPaymentsToExcel(
    List<Order> orders, {
    required String fileName,
  }) async {
    if (orders.isEmpty) return;

    final workbook = excel_pkg.Excel.createExcel();
    final sheet = workbook['Payments'];

    // Headers
    final headers = [
      'Customer', 'Phone', 'Order No', 'Order Date',
      'Total Amount', 'Amount Paid', 'Balance Due', 'Payment Status', 'Notes',
    ];

    // Add header row
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = excel_pkg.TextCellValue(headers[i]);
    }

    // Add data rows
    for (var rowIdx = 0; rowIdx < orders.length; rowIdx++) {
      final order = orders[rowIdx];
      final row = [
        order.customerName,
        order.customerPhone ?? '',
        order.orderNumber ?? '',
        dateFormat.format(order.createdAt),
        order.totalAmount.toStringAsFixed(2),
        order.amountPaid.toStringAsFixed(2),
        order.balanceAmount.toStringAsFixed(2),
        order.paymentStatus.displayName,
        order.notes ?? '',
      ];

      for (var colIdx = 0; colIdx < row.length; colIdx++) {
        final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: rowIdx + 1));
        cell.value = excel_pkg.TextCellValue(row[colIdx].toString());
      }
    }

    // Auto-adjust column widths
    _adjustColumnWidths(sheet, headers.length, orders.length + 1);

    // Convert to bytes and share
    final bytes = workbook.save();
    if (bytes != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(Uint8List.fromList(bytes), mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: fileName),
          ],
        ),
      );
    }
  }

  /// Auto-adjust column widths based on content.
  static void _adjustColumnWidths(excel_pkg.Sheet sheet, int columnCount, int rowCount) {
    for (var col = 0; col < columnCount; col++) {
      int maxLength = 15; // minimum width

      for (var row = 0; row < rowCount; row++) {
        final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        final value = cell.value?.toString() ?? '';
        if (value.length > maxLength) {
          maxLength = value.length;
        }
      }

      // Set column width (approximately 1 unit per character)
      final width = (maxLength + 2).clamp(12, 60).toDouble();
      sheet.setColumnWidth(col, width);
    }
  }
}
