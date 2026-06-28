// lib/screens/category_screen.dart
// UI rebuilt to match screenshot 2 exactly.
// No logic changes.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/category_provider.dart';
import '../theme/app_theme.dart';
import '../utils/image_helper.dart';
import '../widgets/common_widgets.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});
  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<CategoryProvider>().load());
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('ប្រភេទទំនិញ'),
        actions: [
          TextButton.icon(
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
            label: const Text('បញ្ចូល',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Consumer<CategoryProvider>(
        builder: (_, prov, __) => Column(children: [

          // ── Search + Sort row ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(children: [
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
                      hintText: 'ស្វែងរកប្រភេទ…',
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
                : prov.categories.isEmpty
                    ? EmptyState(
                        message: 'រកមិនឃើញប្រភេទ',
                        icon: Icons.category_outlined,
                        action: 'Add Category',
                        onAction: () => _openForm(context),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: prov.categories.length,
                        itemBuilder: (_, i) => _CatRow(
                          key: ValueKey(prov.categories[i].id),
                          cat: prov.categories[i],
                          onTap: () => _openForm(context, prov.categories[i]),
                        ),
                      ),
          ),
        ]),
      ),
    );
  }

  void _openForm(BuildContext context, [CategoryModel? cat]) {
    final prov = context.read<CategoryProvider>();
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: _CategoryFormScreen(cat: cat),
      ),
    ));
  }
}

// ── Category list row — grid icon placeholder | name | description | chevron ──
class _CatRow extends StatelessWidget {
  final CategoryModel cat;
  final VoidCallback  onTap;
  const _CatRow({super.key, required this.cat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final resolved = ImageHelper.resolve(cat.imageUrl);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          // Image / placeholder icon
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48, height: 48,
              child: resolved.isNotEmpty
                  ? Image.network(resolved, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
          ),
          const SizedBox(width: 14),
          // Name + description
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cat.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppTheme.textDark)),
            const SizedBox(height: 3),
            Text(
              cat.description?.isNotEmpty == true ? cat.description! : 'Default',
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

  Widget _placeholder() => Container(
    color: const Color(0xFFF2F2F2),
    child: const Center(
      child: Icon(Icons.apps_outlined, color: Color(0xFFCCCCCC), size: 26),
    ),
  );
}

// ── Form screen — unchanged logic ─────────────────────────────────────────────
class _CategoryFormScreen extends StatefulWidget {
  final CategoryModel? cat;
  const _CategoryFormScreen({this.cat});
  @override
  State<_CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<_CategoryFormScreen> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.cat?.name ?? '');
  late final TextEditingController _descCtrl =
      TextEditingController(text: widget.cat?.description ?? '');
  File? _image;
  bool  _saving  = false;
  bool  get _isEdit => widget.cat != null;

  @override
  void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p != null) setState(() => _image = File(p.path));
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showSnack(context, 'Enter category name', error: true); return;
    }
    setState(() => _saving = true);
    final fields = {'name': _nameCtrl.text.trim(), 'description': _descCtrl.text.trim()};
    final prov = context.read<CategoryProvider>();
    final ok = _isEdit
        ? await prov.update(widget.cat!.id, fields, image: _image)
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
        title: Text(_isEdit ? 'Edit Category' : 'Add Category'),
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
            Center(child: ImagePickerBox(
              imageFile: _image,
              networkUrl: widget.cat?.imageUrl,
              onTap: _pickImage,
            )),
            const SizedBox(height: 24),
            AppField(controller: _nameCtrl, label: 'ឈ្មោះប្រភេទ', icon: Icons.translate),
            const SizedBox(height: 12),
            AppField(controller: _descCtrl, label: 'បរិយាយ',       icon: Icons.notes),
            const SizedBox(height: 28),
            PrimaryButton(label: _isEdit ? 'Save' : 'Add Category', loading: _saving,
                onPressed: _saving ? null : _save),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}
