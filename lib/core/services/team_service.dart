import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Represents a team member (manager or factory staff)
class TeamMember {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String role; // 'office_manager' or 'manufacturing_manager'
  final String? userId; // Supabase auth user ID
  final String? tempPassword; // Last set password (for owner reference)
  final DateTime createdAt;

  TeamMember({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.userId,
    this.tempPassword,
    required this.createdAt,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'office_manager',
      userId: json['user_id'] as String?,
      tempPassword: json['temp_password'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String get roleDisplayName {
    switch (role) {
      case 'office_manager':
        return 'Office Manager';
      case 'manufacturing_manager':
        return 'Manufacturing Manager';
      default:
        return role;
    }
  }
}

/// Service for managing team members + their login accounts.
class TeamService {
  static final _client = Supabase.instance.client;
  static const _table = 'team_members';

  /// Fetch all team members (excludes temp_password for security)
  static Future<List<TeamMember>> getAll() async {
    final data = await _client
        .from(_table)
        .select('id, full_name, email, phone, role, user_id, created_at')
        .order('created_at', ascending: false);
    return (data as List).map((e) => TeamMember.fromJson(e)).toList();
  }

  /// Add a new team member + create their login account.
  ///
  /// Uses a separate SupabaseClient to call signUp() so the current
  /// owner session is NOT affected. This properly creates the user
  /// in both auth.users AND auth.identities (required for login).
  static Future<void> add({
    required String fullName,
    required String email,
    required String phone,
    required String role,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final trimmedName = fullName.trim();
    final trimmedPhone = phone.trim();

    // 1. Create login account via a separate client (won't log out owner)
    //    Use implicit flow since this temp client has no persistent storage
    //    for the PKCE code verifier.
    final tempClient = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabaseAnonKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );

    String? userId;
    try {
      final response = await tempClient.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'full_name': trimmedName,
          'role': role,
          'phone': trimmedPhone,
        },
      );
      userId = response.user?.id;
    } finally {
      tempClient.dispose();
    }

    if (userId == null) {
      throw Exception('Failed to create user account. Check if email is already in use.');
    }

    // 2. Save to team_members table
    await _client.from(_table).insert({
      'full_name': trimmedName,
      'email': normalizedEmail,
      'phone': trimmedPhone,
      'role': role,
      'user_id': userId,
      'temp_password': password,
    });
  }

  /// Update an existing team member's info
  static Future<void> update({
    required String id,
    required String fullName,
    required String email,
    required String phone,
    required String role,
  }) async {
    await _client.from(_table).update({
      'full_name': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'role': role,
    }).eq('id', id);
  }

  /// Remove a team member + delete their login account
  static Future<void> remove(String id) async {
    // Get user_id first (use maybeSingle to avoid PGRST116 when row not found)
    final member = await _client
        .from(_table)
        .select('user_id')
        .eq('id', id)
        .maybeSingle();

    final userId = member?['user_id'];

    // Delete from team_members
    await _client.from(_table).delete().eq('id', id);

    // Try to delete their login account (best-effort — RPC may not exist)
    if (userId != null) {
      try {
        await _client.rpc('delete_team_user', params: {
          'target_user_id': userId,
        });
      } catch (e) {
        debugPrint('Could not delete auth user $userId: $e');
        // Non-fatal: user removed from team_members, auth record remains
      }
    }
  }

  /// Reset a team member's password
  static Future<void> resetPassword({
    required String id,
    required String userId,
    required String newPassword,
  }) async {
    // Try RPC to update auth password
    try {
      await _client.rpc('update_team_user_password', params: {
        'target_user_id': userId,
        'new_password': newPassword,
      });
    } catch (e) {
      debugPrint('RPC update_team_user_password failed: $e');
      throw Exception(
        'Password reset failed. Please ensure the database function '
        '"update_team_user_password" exists. See SUPABASE_SETUP.md.',
      );
    }

    // Save new password for owner reference
    await _client.from(_table).update({
      'temp_password': newPassword,
    }).eq('id', id);
  }
}
