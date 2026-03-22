import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// User roles in the system
enum UserRole {
  customer,
  officeManager,
  manufacturingManager,
  owner,
}

/// Auth service that talks to Supabase.
/// Think of this as the "brain" that handles login, signup, and logout.
class AuthService extends ChangeNotifier {
  AuthService() {
    _listenToAuthChanges();
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Get the currently logged-in user (null if not logged in)
  User? get currentUser => Supabase.instance.client.auth.currentUser;

  /// Check if someone is logged in
  bool get isAuthenticated => currentUser != null;

  /// Get the user's full name from their profile metadata
  String get userName {
    final meta = currentUser?.userMetadata;
    return meta?['full_name'] as String? ?? 'User';
  }

  /// Known business email-to-role mapping.
  /// These emails always get their assigned role regardless of metadata.
  static const Map<String, String> _knownRoles = {
    'ashok@ambigai.com': 'owner',
    'factory@ambigai.com': 'manufacturing_manager',
    'manager@ambigai.com': 'office_manager',
  };

  /// Get the user's role — checks known emails first, then metadata.
  UserRole get userRole {
    final email = currentUser?.email?.toLowerCase().trim();

    // 1. Check known business emails first (always takes priority)
    if (email != null && _knownRoles.containsKey(email)) {
      return _roleFromString(_knownRoles[email]!);
    }

    // 2. Fall back to metadata
    final meta = currentUser?.userMetadata;
    final roleString = meta?['role'] as String? ?? 'customer';
    // Block customer role — feature not yet available
    final role = _roleFromString(roleString);
    return role;
  }

  /// Convert role string to enum
  static UserRole _roleFromString(String role) {
    switch (role) {
      case 'office_manager':
        return UserRole.officeManager;
      case 'manufacturing_manager':
        return UserRole.manufacturingManager;
      case 'owner':
        return UserRole.owner;
      default:
        return UserRole.customer;
    }
  }

  /// Listen for login/logout events from Supabase
  void _listenToAuthChanges() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  /// Sign in with email and password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      // Sync role metadata for known business emails
      final normalizedEmail = email.trim().toLowerCase();
      if (_knownRoles.containsKey(normalizedEmail)) {
        final expectedRole = _knownRoles[normalizedEmail]!;
        final meta = currentUser?.userMetadata;
        if (meta?['role'] != expectedRole) {
          try {
            await Supabase.instance.client.auth.updateUser(
              UserAttributes(data: {'role': expectedRole}),
            );
          } catch (_) {
            // Non-fatal: role sync failed but login succeeded
          }
        }
      }
    } on AuthException catch (e) {
      throw _friendlyAuthError(e);
    } catch (e) {
      throw 'Sign in failed. Please check your credentials and try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Convert AuthException to user-friendly message
  static String _friendlyAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
      return 'Invalid email or password. Please try again.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please confirm your email address before signing in.';
    }
    if (msg.contains('database error') || msg.contains('unexpected_failure')) {
      return 'Server error. Please try again in a moment.';
    }
    if (msg.contains('too many requests') || msg.contains('rate limit')) {
      return 'Too many login attempts. Please wait a moment and try again.';
    }
    return e.message;
  }

  /// Create a new account (for customers only)
  /// Office managers and manufacturing managers are created by the owner
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    required String phone,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // All signups through this method are customers
      await Supabase.instance.client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'role': 'customer', // Always customer for public signup
        },
      );
    } on AuthException catch (e) {
      throw e.message;
    } catch (e) {
      throw 'Sign up failed. Please check your connection and try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Log out the current user
  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    notifyListeners();
  }
}
