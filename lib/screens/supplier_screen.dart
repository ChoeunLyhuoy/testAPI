// lib/screens/supplier_screen.dart
// UI rebuilt to match screenshot 1 exactly.
// No logic changes.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/supplier_provider.dart';
import '../theme/app_theme.dart';
import '../utils/image_helper.dart';
import '../widgets/common_widgets.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});
  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<SupplierProvider>().load());
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('អ្នកផ្គត់ផ្គង់'),
        actions: [
          // "បញ្ចូល +" button matching screenshot top-right
          TextButton.icon(
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
            label: const Text('បញ្ចូល',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Consumer<SupplierProvider>(
        builder: (_, prov, __) => Column(children: [

          // ── Search + Sort row ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(children: [
              // Search bar
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => prov.load(query: v),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'ស្វែងរកអ្នកផ្គត់ផ្គង់…',
                      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textGrey, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () { _searchCtrl.clear(); prov.load(); },
                              child: const Icon(Icons.close, color: AppTheme.primary, size: 18))
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Sort pill — matches "សកម្ម ▼" in screenshot
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('សកម្ម', style: TextStyle(fontSize: 13, color: AppTheme.textGrey)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, color: AppTheme.textGrey, size: 20),
                ]),
              ),
            ]),
          ),

          // ── List ─────────────────────────────────────────────────────────
          Expanded(
            child: prov.isLoading
                ? const AppLoading()
                : prov.suppliers.isEmpty
                    ? EmptyState(
                        message: 'រកមិនឃើញអ្នកផ្គត់ផ្គង់',
                        icon: Icons.local_shipping_outlined,
                        action: 'បន្ថែមអ្នកផ្គត់ផ្គង់',
                        onAction: () => _openForm(context),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: prov.suppliers.length,
                        itemBuilder: (_, i) => _SupplierRow(
                          key: ValueKey(prov.suppliers[i].id),
                          sup: prov.suppliers[i],
                          onTap: () => _openForm(context, prov.suppliers[i]),
                        ),
                      ),
          ),
        ]),
      ),
    );
  }

  void _openForm(BuildContext context, [SupplierModel? sup]) {
    final prov = context.read<SupplierProvider>();
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: _SupplierFormScreen(sup: sup),
      ),
    ));
  }
}

// ── List row — matches screenshot exactly: image | name + phone | chevron ─────
class _SupplierRow extends StatelessWidget {
  final SupplierModel sup;
  final VoidCallback onTap;
  const _SupplierRow({super.key, required this.sup, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final resolved = ImageHelper.resolve(sup.imageUrl);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          // Avatar — circle, 48px
          resolved.isNotEmpty
              ? ClipOval(child: Image.network(resolved,
                  width: 48, height: 48, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _initials()))
              : _initials(),
          const SizedBox(width: 14),
          // Name + phone/subtitle
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sup.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppTheme.textDark)),
            const SizedBox(height: 3),
            Text(
              () {
                final parts = [sup.phone, sup.email]
                    .where((s) => s != null && s.isNotEmpty)
                    .cast<String>()
                    .join('  ·  ');
                if (parts.isNotEmpty) return parts;
                final contact = sup.contactName;
                if (contact != null && contact.isNotEmpty) return contact;
                return '—';
              }(),
              style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ])),
          // Chevron
          const Icon(Icons.chevron_right, color: AppTheme.textGrey, size: 22),
        ]),
      ),
    );
  }

  Widget _initials() => CircleAvatar(
    radius: 24,
    backgroundColor: AppTheme.primaryLt,
    child: Text(sup.initials,
        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
  );
}

// ── Form screen — unchanged logic ────────────────────────────────────────────
class _SupplierFormScreen extends StatefulWidget {
  final SupplierModel? sup;
  const _SupplierFormScreen({this.sup});
  @override
  State<_SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<_SupplierFormScreen> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.sup?.name ?? '');
  late final TextEditingController _contactCtrl =
      TextEditingController(text: widget.sup?.contactName ?? '');
  late final TextEditingController _phoneCtrl =
      TextEditingController(text: widget.sup?.phone ?? '');
  late final TextEditingController _emailCtrl =
      TextEditingController(text: widget.sup?.email ?? '');
  File? _image;
  bool  _saving = false;
  bool  get _isEdit => widget.sup != null;

  @override
  void dispose() {
    _nameCtrl.dispose(); _contactCtrl.dispose();
    _phoneCtrl.dispose(); _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p != null) setState(() => _image = File(p.path));
  }

  Future<void> _deleteSupplier() async {
    if (!mounted) return;
    if (!await confirmDelete(context, 'លុបអ្នកផ្គត់ផ្គង់ "${widget.sup!.name}"?')) return;
    if (!mounted) return;
    setState(() => _saving = true);
    final prov = context.read<SupplierProvider>();
    final ok = await prov.delete(widget.sup!.id);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
      showSnack(context, 'លុបបានជោគជ័យ');
    } else {
      showSnack(context, 'ការលុបបានបរាជ័យ', error: true);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showSnack(context, 'Enter supplier name', error: true); return;
    }
    setState(() => _saving = true);
    final fields = {
      'supplierName': _nameCtrl.text.trim(),
      'contactName':  _contactCtrl.text.trim(),
      'contactPhone': _phoneCtrl.text.trim(),
      'contactEmail': _emailCtrl.text.trim(),
    };
    final prov = context.read<SupplierProvider>();
    final ok = _isEdit
        ? await prov.update(widget.sup!.id, fields, image: _image)
        : await prov.create(fields, image: _image);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) { Navigator.pop(context); showSnack(context, 'Saved'); }
    else showSnack(context, 'Failed', error: true);
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
        title: Text(_isEdit ? 'Edit Supplier' : 'Add Supplier'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteSupplier(),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20,
            MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom + 32,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: _SupplierImagePicker(
              imageFile: _image,
              networkUrl: widget.sup?.imageUrl,
              onTap: _pickImage,
            )),
            const SizedBox(height: 24),
            AppField(controller: _nameCtrl,    label: 'Supplier Name', icon: Icons.business_outlined),
            const SizedBox(height: 12),
            AppField(controller: _contactCtrl, label: 'Contact Name',  icon: Icons.person_outline),
            const SizedBox(height: 12),
            AppField(controller: _phoneCtrl,   label: 'Phone',         icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            AppField(controller: _emailCtrl,   label: 'Email',         icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 28),
            PrimaryButton(label: _isEdit ? 'Save' : 'Add Supplier', loading: _saving,
                onPressed: _saving ? null : _save),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}

class _SupplierImagePicker extends StatelessWidget {
  final File? imageFile;
  final String? networkUrl;
  final VoidCallback onTap;
  final double size;
  const _SupplierImagePicker({
    required this.imageFile, required this.networkUrl,
    required this.onTap, this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(size * 0.18);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size, height: size + 16,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: size, height: size,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: br,
                color: AppTheme.primaryLt.withOpacity(0.18),
                border: Border.all(color: AppTheme.primaryLt, width: 1.2)),
            child: _content(),
          ),
          Positioned(right: -6, bottom: -6,
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15),
                      blurRadius: 4, offset: const Offset(0, 2))]),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
            )),
        ]),
      ),
    );
  }

  Widget _content() {
    if (imageFile != null) return Image.file(imageFile!, fit: BoxFit.cover);
    final resolved = ImageHelper.resolve(networkUrl);
    if (resolved.isNotEmpty) {
      return Image.network(resolved, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _ph());
    }
    return _ph();
  }

  Widget _ph() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.add_a_photo_outlined, size: 30, color: Colors.grey.shade400),
    const SizedBox(height: 6),
    Text('Image', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
  ]));
}
