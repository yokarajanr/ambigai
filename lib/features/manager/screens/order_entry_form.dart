import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import '../../../core/services/order_service.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/invoice_service.dart';
import '../../../core/services/pdf_invoice_service.dart';
import '../../../core/theme/app_theme.dart';

/// Order item for the form.
class OrderItemEntry {
  Product? product;
  int quantity;

  OrderItemEntry({this.product, this.quantity = 0});

  double get amount => (product?.pricePerUnit ?? 0) * quantity;
  bool get isValid => product != null && quantity > 0;
}

/// Order Entry Form - Manager enters phone orders here.
class OrderEntryForm extends StatefulWidget {
  const OrderEntryForm({super.key});

  @override
  State<OrderEntryForm> createState() => _OrderEntryFormState();
}

class _OrderEntryFormState extends State<OrderEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _notesController = TextEditingController();

  final List<OrderItemEntry> _items = [OrderItemEntry()];
  bool _isSubmitting = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Ensure products are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductService>().fetchProducts();
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _totalAmount {
    return _items.fold(0, (sum, item) => sum + item.amount);
  }

  void _addItem() {
    setState(() {
      _items.add(OrderItemEntry());
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items.removeAt(index);
      });
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if at least one valid item
    final validItems = _items.where((item) => item.isValid).toList();
    if (validItems.isEmpty) {
      _showError('Please add at least one item to the order.');
      return;
    }

    setState(() => _isSubmitting = true);

    final orderService = context.read<OrderService>();

    // Convert items to JSON format
    final itemsJson = validItems.map((item) => {
      'product_name': item.product!.name,
      'product_id': item.product!.id,
      'quantity': item.quantity,
      'rate': item.product!.pricePerUnit,
      'amount': item.amount,
    }).toList();

    final order = await orderService.createOrder(
      customerName: _customerNameController.text.trim(),
      customerPhone: _customerPhoneController.text.trim(),
      customerAddress: _customerAddressController.text.trim(),
      items: itemsJson,
      totalAmount: _totalAmount,
      notes: _notesController.text.trim().isEmpty 
          ? null 
          : _notesController.text.trim(),
      orderDate: _selectedDate,
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (order != null) {
      _showSuccess('Order ${order.orderNumber ?? ''} created successfully!');
      await _showPostCreateInvoiceDialog(order);
      if (!mounted) return;
      Navigator.pop(context, order);
    } else {
      _showError(orderService.error ?? 'Failed to create order.');
    }
  }

  Future<void> _showPostCreateInvoiceDialog(Order order) async {
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Order Created'),
        content: const Text('Do you want to send a simple invoice now?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
            },
            child: const Text('Skip'),
          ),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: InvoiceService.generateTextInvoice(order)));
              Navigator.pop(dialogCtx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invoice copied to clipboard'),
                    backgroundColor: Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy Invoice'),
          ),
          TextButton.icon(
            onPressed: () async {
              try {
                await PdfInvoiceService.shareInvoice(order);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not share PDF: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Send PDF'),
          ),
          ElevatedButton.icon(
            onPressed: (order.customerPhone == null || order.customerPhone!.trim().isEmpty)
                ? null
                : () async {
                    var opened = false;
                    for (final uri in InvoiceService.generateWhatsAppUris(order)) {
                      try {
                        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                        if (ok) {
                          opened = true;
                          break;
                        }
                      } catch (_) {
                        // Try fallback URL format
                      }
                    }
                    if (mounted && !opened) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not open WhatsApp'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send WhatsApp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productService = context.watch<ProductService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Order'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: productService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Customer Details Section
                          _buildSectionHeader('Customer Details'),
                          const SizedBox(height: 12),
                          _buildCustomerNameField(),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _customerPhoneController,
                            label: 'Phone Number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _customerAddressController,
                            label: 'Delivery Address',
                            icon: Icons.location_on_outlined,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),

                          // Order Date Picker
                          _buildDatePicker(),
                          const SizedBox(height: 24),

                          // Order Items Section
                          _buildSectionHeader('Order Items'),
                          const SizedBox(height: 12),
                          ...List.generate(_items.length, (index) {
                            return _buildItemRow(index, productService.activeProducts);
                          }),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Add Another Item'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Notes Section
                          _buildSectionHeader('Notes (Optional)'),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _notesController,
                            label: 'Special instructions',
                            icon: Icons.note_outlined,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 24),

                          // Order Summary
                          _buildOrderSummary(),
                        ],
                      ),
                    ),
                  ),

                  // Submit Button
                  _buildSubmitButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildCustomerNameField() {
    final orderService = context.read<OrderService>();
    final customerNames = orderService.getUniqueCustomerNames();

    return TypeAheadFormField<String>(
      textFieldConfiguration: TextFieldConfiguration(
        controller: _customerNameController,
        decoration: InputDecoration(
          labelText: 'Customer Name',
          prefixIcon: const Icon(Icons.person_outline, color: AppTheme.textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFFFAFAFA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (value) {
          setState(() {});
        },
      ),
      suggestionsCallback: (pattern) {
        if (pattern.isEmpty) return [];
        final lowercasePattern = pattern.toLowerCase();
        return customerNames
            .where((name) => name.toLowerCase().startsWith(lowercasePattern))
            .toList();
      },
      itemBuilder: (context, String suggestion) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Text(
            suggestion,
            style: const TextStyle(fontSize: 14),
          ),
        );
      },
      onSuggestionSelected: (String suggestion) {
        _customerNameController.text = suggestion;
        setState(() {});
      },
      noItemsFoundBuilder: (context) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'No matching customers',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        );
      },
      hideOnEmpty: true,
      debounceDuration: const Duration(milliseconds: 300),
      validator: (value) => value?.trim().isEmpty == true 
          ? 'Please enter customer name' 
          : null,
    );
  }

  Widget _buildDatePicker() {
    final dateFormat = DateFormat('EEE, dd MMM yyyy');
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Date',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, color: AppTheme.textSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isToday ? 'Today - ${dateFormat.format(_selectedDate)}' : dateFormat.format(_selectedDate),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
                if (!isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Backdated',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Select a past date if entering orders from a previous day',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      helpText: 'Select Order Date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildItemRow(int index, List<Product> products) {
    final item = _items[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Product Dropdown
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<Product>(
                  initialValue: item.product,
                  decoration: InputDecoration(
                    labelText: 'Select Brick',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                  ),
                  items: products.map((product) {
                    return DropdownMenuItem(
                      value: product,
                      child: Text(
                        product.name,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (product) {
                    setState(() {
                      _items[index].product = product;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              
              // Remove Button
              if (_items.length > 1)
                IconButton(
                  onPressed: () => _removeItem(index),
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppTheme.errorColor,
                  iconSize: 24,
                ),
            ],
          ),
          if (item.product != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // Price Display
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '₹${item.product!.pricePerUnit.toStringAsFixed(2)}/${item.product!.unit}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Quantity Input
                Expanded(
                  child: TextFormField(
                    initialValue: item.quantity > 0 ? item.quantity.toString() : '',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _items[index].quantity = int.tryParse(value) ?? 0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                
                // Amount Display
                Container(
                  width: 100,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: item.amount > 0 
                        ? const Color(0xFFECFDF5) 
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '₹${item.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: item.amount > 0 
                          ? const Color(0xFF10B981) 
                          : AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    final validItems = _items.where((item) => item.isValid).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (validItems.isEmpty)
            const Text(
              'No items added yet',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            )
          else ...[
            ...validItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item.product!.name} × ${item.quantity}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(
                    '₹${item.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '₹${_totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.5),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Create Order • ₹${_totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
