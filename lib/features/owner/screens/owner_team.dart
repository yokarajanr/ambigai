import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/team_service.dart';

/// Owner Team Management screen — add, edit, remove managers & factory staff.
class OwnerTeam extends StatefulWidget {
  const OwnerTeam({super.key});

  @override
  State<OwnerTeam> createState() => _OwnerTeamState();
}

class _OwnerTeamState extends State<OwnerTeam> {
  List<TeamMember> _members = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final members = await TeamService.getAll();
      if (mounted) setState(() => _members = members);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Generate a random password like "Ab@x7k2m9"
  String _generatePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random();
    return 'Ab@${List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _members.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
      ),
    );
  }

  // ── Error state ────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            const Text(
              'Failed to load team members',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            OutlinedButton.icon(onPressed: _loadMembers, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text('No team members yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('Add office managers and factory managers\nto your team.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  // ── Member list ────────────────────────────────────────────────────

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _members.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _memberCard(_members[index]),
      ),
    );
  }

  Widget _memberCard(TeamMember member) {
    final isOffice = member.role == 'office_manager';
    final roleColor = isOffice ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: roleColor.withValues(alpha: 0.12),
              child: Text(
                member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : '?',
                style: TextStyle(color: roleColor, fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.fullName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 3),
                  Text(member.email, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(member.roleDisplayName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: roleColor)),
                  ),
                ],
              ),
            ),
            // 3-dot menu: Edit, Reset Password, Remove
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditDialog(member);
                } else if (value == 'reset_password') {
                  _showResetPasswordDialog(member);
                } else if (value == 'remove') {
                  _confirmRemove(member);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary), SizedBox(width: 10), Text('Edit'),
                ])),
                const PopupMenuItem(value: 'reset_password', child: Row(children: [
                  Icon(Icons.lock_reset, size: 18, color: AppTheme.textSecondary), SizedBox(width: 10), Text('Reset Password'),
                ])),
                const PopupMenuItem(value: 'remove', child: Row(children: [
                  Icon(Icons.delete_outline, size: 18, color: AppTheme.errorColor), SizedBox(width: 10), Text('Remove', style: TextStyle(color: AppTheme.errorColor)),
                ])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── ADD Member Dialog (with password) ──────────────────────────────

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: _generatePassword());
    String selectedRole = 'office_manager';
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Team Member', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogTextField(nameCtrl, 'Full Name', Icons.person_outline),
                    const SizedBox(height: 14),
                    _dialogTextField(emailCtrl, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    _dialogTextField(phoneCtrl, 'Phone', Icons.phone_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 14),
                    // Password field with generate button
                    TextField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off, size: 20),
                              onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              tooltip: 'Generate password',
                              onPressed: () => setDialogState(() => passwordCtrl.text = _generatePassword()),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Role selector
                    _roleSelector(selectedRole, (v) => setDialogState(() => selectedRole = v)),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final email = emailCtrl.text.trim();
                    final password = passwordCtrl.text.trim();
                    if (name.isEmpty || email.isEmpty || password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Name, email and password are required')),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop();
                    try {
                      await TeamService.add(
                        fullName: name,
                        email: email,
                        phone: phoneCtrl.text.trim(),
                        role: selectedRole,
                        password: password,
                      );
                      await _loadMembers();
                      if (mounted) _showCredentialsDialog(name, email, password);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
                        );
                      }
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── EDIT Member Dialog ─────────────────────────────────────────────

  void _showEditDialog(TeamMember member) {
    final nameCtrl = TextEditingController(text: member.fullName);
    final emailCtrl = TextEditingController(text: member.email);
    final phoneCtrl = TextEditingController(text: member.phone);
    String selectedRole = member.role;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Edit Member', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogTextField(nameCtrl, 'Full Name', Icons.person_outline),
                    const SizedBox(height: 14),
                    _dialogTextField(emailCtrl, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress, enabled: false),
                    const SizedBox(height: 14),
                    _dialogTextField(phoneCtrl, 'Phone', Icons.phone_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 18),
                    _roleSelector(selectedRole, (v) => setDialogState(() => selectedRole = v)),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
                      return;
                    }
                    Navigator.of(ctx).pop();
                    try {
                      await TeamService.update(id: member.id, fullName: name, email: member.email, phone: phoneCtrl.text.trim(), role: selectedRole);
                      await _loadMembers();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member updated')));
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor));
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── RESET PASSWORD Dialog ──────────────────────────────────────────

  void _showResetPasswordDialog(TeamMember member) {
    if (member.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This member has no login account')),
      );
      return;
    }

    final passwordCtrl = TextEditingController(text: _generatePassword());
    bool obscure = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reset password for ${member.fullName}', style: const TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, size: 20), onPressed: () => setDialogState(() => obscure = !obscure)),
                          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: () => setDialogState(() => passwordCtrl.text = _generatePassword())),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await TeamService.resetPassword(id: member.id, userId: member.userId!, newPassword: passwordCtrl.text);
                      if (mounted) _showCredentialsDialog(member.fullName, member.email, passwordCtrl.text);
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor));
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  child: const Text('Reset'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── CREDENTIALS Dialog (shown after add / reset) ───────────────────

  void _showCredentialsDialog(String name, String email, String password) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.check_circle, color: AppTheme.successColor, size: 48),
        title: Text('$name can now login!', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Email:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text(email, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  const Text('Password:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text(password, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Share these credentials with the team member.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'Email: $email\nPassword: $password'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credentials copied!')));
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ── REMOVE Confirmation ────────────────────────────────────────────

  void _confirmRemove(TeamMember member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Member', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Remove ${member.fullName}?\nThey will no longer be able to login.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await TeamService.remove(member.id);
                await _loadMembers();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member removed')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────

  Widget _dialogTextField(
    TextEditingController controller, String label, IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _roleSelector(String selectedRole, ValueChanged<String> onChanged) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text('Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          ),
          RadioGroup<String>(
            groupValue: selectedRole,
            onChanged: (v) => onChanged(v!),
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'office_manager',
                  title: const Text('Office Manager', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  dense: true,
                  activeColor: AppTheme.primaryColor,
                ),
                RadioListTile<String>(
                  value: 'manufacturing_manager',
                  title: const Text('Manufacturing Manager', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  dense: true,
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
