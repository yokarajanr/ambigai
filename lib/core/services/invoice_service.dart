import 'package:intl/intl.dart';
import 'order_service.dart';

/// Generates formatted invoice text from an Order.
class InvoiceService {
  InvoiceService._();

  /// Company info — update these for your business.
  static const String companyName = 'AMBIGAI BRICKS';
  static const String companyPhone = '+91 98765 43210'; // Update with real number
  static const String companyAddress = 'Brick Manufacturing Unit';

  /// Generate a plain-text invoice suitable for WhatsApp / clipboard sharing.
  static String generateTextInvoice(Order order) {
    final dateFormat = DateFormat('dd-MMM-yyyy');
    final now = dateFormat.format(DateTime.now());
    final orderDate = dateFormat.format(order.createdAt);
    final deliveryDate = order.deliveryDate != null
        ? dateFormat.format(order.deliveryDate!)
        : 'N/A';

    final buffer = StringBuffer();

    // Header
    buffer.writeln('═══════════════════════════════');
    buffer.writeln('        $companyName');
    buffer.writeln('═══════════════════════════════');
    buffer.writeln('INVOICE');
    buffer.writeln('');

    // Order info
    buffer.writeln('Invoice No  : ${order.orderNumber ?? order.id.substring(0, 8)}');
    buffer.writeln('Date        : $now');
    buffer.writeln('Order Date  : $orderDate');
    if (order.dcNumber != null && order.dcNumber!.isNotEmpty) {
      buffer.writeln('DC Number   : ${order.dcNumber}');
    }
    buffer.writeln('');

    // Customer info
    buffer.writeln('──── Customer ────────────────');
    buffer.writeln('Name    : ${order.customerName}');
    if (order.customerPhone != null && order.customerPhone!.isNotEmpty) {
      buffer.writeln('Phone   : ${order.customerPhone}');
    }
    if (order.customerAddress != null && order.customerAddress!.isNotEmpty) {
      buffer.writeln('Address : ${order.customerAddress}');
    }
    buffer.writeln('');

    // Items table
    buffer.writeln('──── Items ───────────────────');
    buffer.writeln('${_padRight('Product', 18)}${_padRight('Qty', 8)}${_padRight('Rate', 10)}Amount');
    buffer.writeln('─────────────────────────────────────────');

    for (final item in order.items) {
      final name = (item['product_name'] ?? item['brick_type'] ?? 'Brick') as String;
      final qty = item['quantity'] ?? 0;
      final rate = item['rate'] ?? item['price_per_unit'] ?? 0;
      final amount = item['amount'] ?? item['total_price'] ?? 0;

      buffer.writeln(
        '${_padRight(_truncate(name, 17), 18)}${_padRight('$qty', 8)}${_padRight('₹$rate', 10)}₹$amount'
      );
    }

    buffer.writeln('─────────────────────────────────────────');

    // Totals
    buffer.writeln('${_padRight('', 26)}${_padRight('Subtotal:', 12)}₹${order.totalAmount.toStringAsFixed(0)}');

    if (order.discount > 0) {
      buffer.writeln('${_padRight('', 26)}${_padRight('Discount:', 12)}-₹${order.discount.toStringAsFixed(0)}');
      buffer.writeln('${_padRight('', 26)}${_padRight('Net Total:', 12)}₹${order.effectiveAmount.toStringAsFixed(0)}');
    }

    buffer.writeln('');

    // Payment info
    buffer.writeln('──── Payment ─────────────────');
    final statusLabel = order.paymentStatus == PaymentStatus.paid
        ? '✅ Fully Paid'
        : order.amountPaid > 0
            ? '⏳ Partially Paid'
            : '❌ Unpaid';
    buffer.writeln('Status  : $statusLabel');
    buffer.writeln('Paid    : ₹${order.amountPaid.toStringAsFixed(0)}');
    if (order.balanceAmount > 0) {
      buffer.writeln('Balance : ₹${order.balanceAmount.toStringAsFixed(0)}');
    }
    buffer.writeln('');

    // Delivery info
    buffer.writeln('──── Delivery ────────────────');
    buffer.writeln('Status  : ${order.status.displayName}');
    buffer.writeln('Date    : $deliveryDate');
    buffer.writeln('');

    // Footer
    buffer.writeln('═══════════════════════════════');
    buffer.writeln('Thank you for your business!');
    buffer.writeln('$companyName | $companyPhone');
    buffer.writeln('═══════════════════════════════');

    return buffer.toString();
  }

  /// Generate a WhatsApp-ready shareable URL for the invoice.
  static Uri generateWhatsAppUri(Order order) {
    final uris = generateWhatsAppUris(order);
    return uris.first;
  }

  /// Generate WhatsApp URLs (primary + fallback) with normalized continuous number.
  static List<Uri> generateWhatsAppUris(Order order) {
    final rawPhone = order.customerPhone ?? '';
    final phone = _normalizePhoneForWhatsApp(rawPhone);
    final invoice = generateTextInvoice(order);
    final encoded = Uri.encodeComponent(invoice);

    return [
      Uri.parse('https://wa.me/$phone?text=$encoded'),
      Uri.parse('https://api.whatsapp.com/send?phone=$phone&text=$encoded'),
    ];
  }

  static String _padRight(String s, int width) =>
      s.length >= width ? s : s + ' ' * (width - s.length);

  static String _truncate(String s, int maxLen) =>
      s.length <= maxLen ? s : '${s.substring(0, maxLen - 2)}..';

  static String _normalizePhoneForWhatsApp(String phone) {
    var digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '';

    // Handle local India style: 0XXXXXXXXXX
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    // Assume India for 10-digit local numbers
    if (digits.length == 10) {
      digits = '91$digits';
    }

    return digits;
  }
}
