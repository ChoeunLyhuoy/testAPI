// lib/screens/bank_account_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/payment_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class BankAccountScreen extends StatefulWidget {
  const BankAccountScreen({super.key});
  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<PaymentProvider>().load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('គណនីធនាគារ'),
        actions: [
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showForm(context)),
        ],
      ),
      body: Consumer<PaymentProvider>(
        builder: (_, prov, __) {
          if (prov.isLoading) return const AppLoading();

          // Always show default banks + API banks
          final apiBanks = prov.payments;

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              // Section: Default / preset banks

              // Section: API banks
              if (apiBanks.isNotEmpty) ...[
                _SectionLabel('គណនីបន្ថែម'),
                ...apiBanks.map((p) => _BankRow(
                      key: ValueKey(p.id),
                      pay: p,
                      onEdit: () => _showForm(context, p),
                    )),
              ],

            ],
          );
        },
      ),
    );
  }

  void _showForm(BuildContext context, [PaymentModel? pay]) {
    final prov = context.read<PaymentProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChangeNotifierProvider.value(
          value: prov,
          child: _BankAccountFormScreen(pay: pay),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ADD / EDIT BANK ACCOUNT — full screen
// ══════════════════════════════════════════════════════════════════════════════
class _BankAccountFormScreen extends StatefulWidget {
  final PaymentModel? pay;
  const _BankAccountFormScreen({this.pay});

  @override
  State<_BankAccountFormScreen> createState() => _BankAccountFormScreenState();
}

class _BankAccountFormScreenState extends State<_BankAccountFormScreen> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.pay?.name ?? '');
  late final TextEditingController _descCtrl =
      TextEditingController(text: widget.pay?.description ?? '');

  File? _image;
  bool _saving = false;

  bool get _isEdit => widget.pay != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final p = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p != null) setState(() => _image = File(p.path));
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showSnack(context, 'សូមបំពេញឈ្មោះធនាគារ', error: true);
      return;
    }
    setState(() => _saving = true);

    final fields = {
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
    };

    final prov = context.read<PaymentProvider>();
    final ok = _isEdit
        ? await prov.update(widget.pay!.id, fields, image: _image)
        : await prov.create(fields, image: _image);

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context);
      showSnack(context, 'រក្សាទុកបានជោគជ័យ');
    } else {
      showSnack(context, 'មានកំហុស', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEdit ? 'កែប្រែធនាគារ' : 'បន្ថែមធនាគារ'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ImagePickerBox(
                  imageFile: _image,
                  networkUrl: widget.pay?.imageUrl,
                  size: 120,
                  onTap: _pickImage,
                ),
              ),
              const SizedBox(height: 24),
              AppField(
                  controller: _nameCtrl,
                  label: 'ឈ្មោះធនាគារ',
                  icon: Icons.account_balance_outlined),
              const SizedBox(height: 12),
              AppField(
                  controller: _descCtrl,
                  label: 'បរិយាយ',
                  icon: Icons.notes,
                  maxLines: 2),
              const SizedBox(height: 28),
              PrimaryButton(
                label: _isEdit ? 'រក្សាទុក' : 'បន្ថែម',
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark),
      ),
    );
  }
}

// ── Preset bank (with asset image) ───────────────────────────────────────────
class _PresetBank {
  final String name;
  final String nameKh;
  final String description;
  final String assetPath;
  final Color bgColor;
  const _PresetBank({
    required this.name,
    required this.nameKh,
    required this.description,
    required this.assetPath,
    required this.bgColor,
  });
}

class _DefaultBankRow extends StatelessWidget {
  final _PresetBank bank;
  const _DefaultBankRow({required this.bank});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Logo
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              bank.assetPath,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: bank.bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance,
                    color: Colors.white, size: 26),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bank.nameKh,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark),
                ),
                const SizedBox(height: 2),
                Text(
                  bank.name,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textGrey),
                ),
                const SizedBox(height: 2),
                Text(
                  bank.description,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textGrey),
                ),
              ],
            ),
          ),
          // Active badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.successLt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'សកម្ម',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.success),
            ),
          ),
        ],
      ),
    );
  }
}

// ── API bank row ──────────────────────────────────────────────────────────────
class _BankRow extends StatefulWidget {
  final PaymentModel pay;
  final VoidCallback onEdit;
  const _BankRow({super.key, required this.pay, required this.onEdit});

  @override
  State<_BankRow> createState() => _BankRowState();
}

class _BankRowState extends State<_BankRow> {
  // Guards against a double-tap firing two concurrent delete calls for the
  // same row while the confirm dialog / network request is in flight.
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final pay = widget.pay;
    return CardRow(
      leading: NetImage(
        url: pay.imageUrl,
        size: 48,
        radius: BorderRadius.circular(10),
        fallback: Icons.account_balance_outlined,
      ),
      title: pay.name,
      subtitle: pay.description,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppTheme.primary, size: 18),
            // FIX: was `onPressed: () {}` — edit button was a no-op, so
            // there was no way to update a bank account once created.
            onPressed: widget.onEdit),
        IconButton(
            icon: _deleting
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                : const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            onPressed: _deleting ? null : () => _delete(context)),
      ]),
    );
  }

  Future<void> _delete(BuildContext context) async {
    if (!await confirmDelete(context, 'លុប "${widget.pay.name}"?')) return;
    if (!context.mounted) return;
    setState(() => _deleting = true);
    final ok = await context.read<PaymentProvider>().delete(widget.pay.id);
    if (!context.mounted) return;
    setState(() => _deleting = false);
    showSnack(context, ok ? 'លុបបានជោគជ័យ' : 'មានកំហុស', error: !ok);
  }
}
