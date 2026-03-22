import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A single production log entry.
class ProductionLog {
  final String id;
  final String productName;
  final String? productId;
  final int quantity;
  final int? defectCount;
  final String? notes;
  final String? createdBy;
  final DateTime productionDate;
  final DateTime createdAt;

  ProductionLog({
    required this.id,
    required this.productName,
    this.productId,
    required this.quantity,
    this.defectCount,
    this.notes,
    this.createdBy,
    required this.productionDate,
    required this.createdAt,
  });

  factory ProductionLog.fromJson(Map<String, dynamic> json) {
    return ProductionLog(
      id: json['id'] as String,
      productName: json['product_name'] as String? ?? 'Unknown',
      productId: json['product_id'] as String?,
      quantity: json['quantity'] as int? ?? 0,
      defectCount: json['defect_count'] as int?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      productionDate: DateTime.parse(json['production_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'product_name': productName,
    'product_id': productId,
    'quantity': quantity,
    'defect_count': defectCount,
    'notes': notes,
    'production_date': productionDate.toIso8601String().split('T').first,
  };

  double get qualityRate {
    if (defectCount == null || defectCount == 0) return 100.0;
    return ((quantity - defectCount!) / quantity * 100).clamp(0, 100);
  }
}

/// Production service for logging and tracking brick production.
class ProductionService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<ProductionLog> _logs = [];
  bool _isLoading = false;
  String? _error;

  List<ProductionLog> get logs => List.unmodifiable(_logs);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Today's logs.
  List<ProductionLog> get todaysLogs {
    final today = DateTime.now();
    return _logs.where((l) =>
      l.productionDate.year == today.year &&
      l.productionDate.month == today.month &&
      l.productionDate.day == today.day
    ).toList();
  }

  /// Today's total production.
  int get todaysTotal => todaysLogs.fold(0, (sum, l) => sum + l.quantity);

  /// Today's total defects.
  int get todaysDefects => todaysLogs.fold(0, (sum, l) => sum + (l.defectCount ?? 0));

  /// Today's quality rate.
  double get todaysQualityRate {
    if (todaysTotal == 0) return 100.0;
    return ((todaysTotal - todaysDefects) / todaysTotal * 100).clamp(0, 100);
  }

  /// Fetch all production logs (most recent first).
  Future<void> fetchLogs() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('production_logs')
          .select()
          .order('production_date', ascending: false)
          .order('created_at', ascending: false);

      _logs = (response as List)
          .map((json) => ProductionLog.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = 'Failed to load production logs.';
      debugPrint('Error fetching production logs: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Log a new production entry.
  Future<ProductionLog?> logProduction({
    required String productName,
    String? productId,
    required int quantity,
    int? defectCount,
    String? notes,
    DateTime? productionDate,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = {
        'product_name': productName,
        'product_id': productId,
        'quantity': quantity,
        'defect_count': defectCount ?? 0,
        'notes': notes,
        'created_by': userId,
        'production_date': (productionDate ?? DateTime.now()).toIso8601String().split('T').first,
      };

      final response = await _supabase
          .from('production_logs')
          .insert(data)
          .select()
          .single();

      final log = ProductionLog.fromJson(response);
      _logs.insert(0, log);
      notifyListeners();
      return log;
    } on PostgrestException catch (e) {
      _error = 'Database error: ${e.message}';
      debugPrint('PostgrestException logging production: ${e.message}');
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Failed to log production: $e';
      debugPrint('Error logging production: $e');
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a production log entry.
  Future<bool> deleteLog(String logId) async {
    try {
      await _supabase
          .from('production_logs')
          .delete()
          .eq('id', logId);

      _logs.removeWhere((l) => l.id == logId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete log.';
      debugPrint('Error deleting production log: $e');
      notifyListeners();
      return false;
    }
  }

  /// Get production summary grouped by product for a date range.
  Map<String, int> getProductSummary({DateTime? from, DateTime? to}) {
    final filtered = _logs.where((l) {
      if (from != null && l.productionDate.isBefore(from)) return false;
      if (to != null && l.productionDate.isAfter(to)) return false;
      return true;
    });

    final summary = <String, int>{};
    for (final log in filtered) {
      summary[log.productName] = (summary[log.productName] ?? 0) + log.quantity;
    }
    return summary;
  }

  /// Get logs for a specific month.
  List<ProductionLog> getLogsForMonth(int year, int month) {
    return _logs.where((l) =>
      l.productionDate.year == year && l.productionDate.month == month
    ).toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
