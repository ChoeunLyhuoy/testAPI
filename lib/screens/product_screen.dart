// lib/screens/product_screen.dart
// Full product screen: grid/list + product detail (options) + add/edit forms

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../providers/product_provider.dart';
import '../providers/supplier_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../utils/image_helper.dart';
import '../widgets/common_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  CODE GENERATOR  — produces kok-000001, kok-000002, … sequentially.
//  The last-used counter is persisted in SharedPreferences so the sequence
//  survives app restarts without needing a server round-trip.
// ══════════════════════════════════════════════════════════════════════════════
class _CodeGenerator {
  static const _prefKey = 'kok_code_counter';

  /// Returns the next code in the sequence, e.g. "kok-000001".
  /// Thread-safe within a single isolate; each call increments the counter.
  static Future<String> next() async {
    final prefs   = await SharedPreferences.getInstance();
    final current = prefs.getInt(_prefKey) ?? 0;
    final next    = current + 1;
    await prefs.setInt(_prefKey, next);
    // Zero-pad to 6 digits → kok-000001 … kok-999999
    return 'kok-${next.toString().padLeft(6, '0')}';
  }

  /// Peek at the NEXT code without incrementing the counter.
  /// Useful for previewing what code will be assigned before saving.
  static Future<String> peek() async {
    final prefs   = await SharedPreferences.getInstance();
    final current = prefs.getInt(_prefKey) ?? 0;
    return 'kok-${(current + 1).toString().padLeft(6, '0')}';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PRODUCT LIST / GRID SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final _searchCtrl = TextEditingController();
  bool _isGridView  = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadAll();
      context.read<SupplierProvider>().load();
    });
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('ផលិតផល'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view,
                color: Colors.white),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _openForm(context),
          ),
        ],
      ),
      body: Consumer<ProductProvider>(
        builder: (_, prod, __) => Column(children: [
          // ── Search + filter ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(children: [
              Expanded(
                child: AppSearchBar(
                  hint: 'ស្វែងរកផលិតផល…',
                  controller: _searchCtrl,
                  onChanged: prod.setQuery,
                  onClear: () { _searchCtrl.clear(); prod.setQuery(''); },
                  onScan: () => _scanToSearch(context, prod),
                ),
              ),
              const SizedBox(width: 8),
              _FilterButton(provider: prod),
            ]),
          ),
          // ── Category chips ────────────────────────────────────────
          if (!prod.isLoading && prod.categories.isNotEmpty)
            _CategoryChips(provider: prod),
          // ── Count ─────────────────────────────────────────────────
          if (!prod.isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('ផលិតផល ${prod.filtered.length} ប្រភេទ',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textGrey)),
              ),
            ),
          // ── Content ───────────────────────────────────────────────
          Expanded(
            child: prod.isLoading
                ? const AppLoading()
                : prod.filtered.isEmpty
                ? EmptyState(
              message: 'រកមិនឃើញផលិតផល',
              icon: Icons.inventory_2_outlined,
              action: 'បន្ថែមផលិតផល',
              onAction: () => _openForm(context),
            )
                : _isGridView
                ? _ProductGrid(
              products: prod.filtered,
              onTap:       (p) => _openDetail(context, p),
              onEdit:      (p) => _openForm(context, p),
              onAddOption: (p) => _openOptionForm(context, p),
            )
                : _ProductList(
              products: prod.filtered,
              onTap:       (p) => _openDetail(context, p),
              onEdit:      (p) => _openForm(context, p),
              onAddOption: (p) => _openOptionForm(context, p),
            ),
          ),
        ]),
      ),
    );
  }

  void _push(BuildContext ctx, Widget screen) =>
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen));

  void _openDetail(BuildContext ctx, ProductModel p) =>
      _push(ctx, ProductDetailScreen(product: p));

  void _openForm(BuildContext ctx, [ProductModel? p]) =>
      _push(ctx, _ProductFormScreen(product: p));

  void _openOptionForm(BuildContext ctx, ProductModel p) =>
      _push(ctx, _OptionFormScreen(product: p));

  Future<void> _scanToSearch(BuildContext ctx, ProductProvider prod) async {
    final code = await scanBarcode(ctx);
    if (code != null && code.isNotEmpty) {
      _searchCtrl.text = code;
      prod.setQuery(code);
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  GRID
// ══════════════════════════════════════════════════════════════════════════════
class _ProductGrid extends StatelessWidget {
  final List<ProductModel> products;
  final ValueChanged<ProductModel> onTap;
  final ValueChanged<ProductModel> onEdit;
  final ValueChanged<ProductModel> onAddOption;

  const _ProductGrid({
    required this.products,
    required this.onTap,
    required this.onEdit,
    required this.onAddOption,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
        childAspectRatio: 0.68,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) => _GridCard(
        product: products[i],
        onTap:       () => onTap(products[i]),
        onEdit:      () => onEdit(products[i]),
        onAddOption: () => onAddOption(products[i]),
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onAddOption;

  const _GridCard({
    required this.product,
    required this.onTap,
    required this.onEdit,
    required this.onAddOption,
  });

  @override
  Widget build(BuildContext context) {
    final opt    = product.firstOption;
    final imgUrl = product.imageUrl;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                child: SizedBox.expand(child: _ProdImg(url: imgUrl)),
              ),
              if (opt != null)
                Positioned(
                  top: 5, right: 5,
                  child: _Badge(text: Formatter.currency(opt.price),
                      color: AppTheme.primary),
                ),
              if (product.options.length > 1)
                Positioned(
                  top: 5, left: 5,
                  child: _Badge(
                      text: '${product.options.length} opts',
                      color: Colors.black54),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (opt != null)
                Text(opt.productCode,
                    style: const TextStyle(
                        fontSize: 9, color: AppTheme.textGrey, fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(product.name,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppTheme.textDark, height: 1.2),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              Row(children: [
                Expanded(child: _ActionBtn(
                    color: AppTheme.primaryLt,
                    icon: Icons.copy_all_outlined,
                    iconColor: AppTheme.primary,
                    onTap: onAddOption)),
                const SizedBox(width: 5),
                Expanded(child: _ActionBtn(
                    color: AppTheme.dangerLt,
                    icon: Icons.delete_outline,
                    iconColor: AppTheme.danger,
                    onTap: () => _delete(context))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    if (!await confirmDelete(context, 'លុប "${product.name}"?')) return;
    final ok = await context.read<ProductProvider>().deleteProduct(product.id);
    if (context.mounted) showSnack(context, ok ? 'លុបបានជោគជ័យ' : 'មានបញ្ហា', error: !ok);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  LIST
// ══════════════════════════════════════════════════════════════════════════════
class _ProductList extends StatelessWidget {
  final List<ProductModel> products;
  final ValueChanged<ProductModel> onTap;
  final ValueChanged<ProductModel> onEdit;
  final ValueChanged<ProductModel> onAddOption;

  const _ProductList({
    required this.products, required this.onTap,
    required this.onEdit, required this.onAddOption,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      itemCount: products.length,
      itemBuilder: (_, i) => _ListRow(
        product: products[i],
        onTap:       () => onTap(products[i]),
        onEdit:      () => onEdit(products[i]),
        onAddOption: () => onAddOption(products[i]),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onAddOption;

  const _ListRow({
    required this.product, required this.onTap,
    required this.onEdit, required this.onAddOption,
  });

  @override
  Widget build(BuildContext context) {
    final opt = product.firstOption;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 52, height: 52,
                child: _ProdImg(url: product.imageUrl)),
          ),
          title: Text(product.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppTheme.textDark)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (opt != null)
              Text(opt.productCode,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
            Text(
              opt != null
                  ? '${Formatter.currency(opt.price)}  ·  ${product.options.length} ជម្រើស'
                  : 'មិនមានជម្រើស',
              style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
            ),
          ]),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.textGrey, size: 20),
            onSelected: (v) {
              if (v == 'edit')   onEdit();
              if (v == 'option') onAddOption();
              if (v == 'delete') _delete(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit',   child: Text('កែប្រែ')),
              PopupMenuItem(value: 'option', child: Text('បន្ថែមជម្រើស')),
              PopupMenuItem(value: 'delete',
                  child: Text('លុប', style: TextStyle(color: Colors.red))),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    if (!await confirmDelete(context, 'លុប "${product.name}"?')) return;
    final ok = await context.read<ProductProvider>().deleteProduct(product.id);
    if (context.mounted) showSnack(context, ok ? 'លុបបានជោគជ័យ' : 'មានបញ្ហា', error: !ok);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PRODUCT DETAIL SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class ProductDetailScreen extends StatelessWidget {
  final ProductModel product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (_, prod, __) {
        final live = prod.products.firstWhere(
              (p) => p.id == product.id,
          orElse: () => product,
        );
        return _ProductDetailBody(product: live);
      },
    );
  }
}

class _ProductDetailBody extends StatelessWidget {
  final ProductModel product;
  const _ProductDetailBody({required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => _ProductFormScreen(product: product))),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            tooltip: 'Add Option',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => _OptionFormScreen(product: product))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border)),
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 90, height: 90,
                  child: _ProdImg(url: product.imageUrl),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold,
                          color: AppTheme.textDark)),
                  if (product.category != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppTheme.primaryLt,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(product.category!,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                  if (product.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(product.description!,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    _InfoChip(
                        icon: Icons.tune_outlined,
                        label: '${product.options.length} ជម្រើស'),
                    const SizedBox(width: 6),
                    _InfoChip(
                        icon: Icons.inventory_2_outlined,
                        label: 'Stock: ${product.totalQuantity}'),
                  ]),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ជម្រើស (${product.options.length})',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold,
                    color: AppTheme.textDark),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16, color: AppTheme.primary),
                label: const Text('បន្ថែមជម្រើស',
                    style: TextStyle(fontSize: 13, color: AppTheme.primary)),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _OptionFormScreen(product: product))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (product.options.isEmpty)
            const EmptyState(
                message: 'មិនទាន់មានជម្រើស',
                icon: Icons.tune_outlined)
          else
            ...product.options.asMap().entries.map(
                    (e) => _OptionCard(
                    option: e.value,
                    index: e.key,
                    product: product)),
        ]),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final ProductOptionModel option;
  final int index;
  final ProductModel product;

  const _OptionCard({
    required this.option,
    required this.index,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
          child: SizedBox(
            width: 80, height: 80,
            child: _ProdImg(url: option.imageUrl),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              option.productCode,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold,
                  color: AppTheme.textDark),
            ),
            const SizedBox(height: 4),
            Wrap(spacing: 5, runSpacing: 4, children: [
              if (option.ramSize != null)
                _SpecChip(label: option.ramSize!.replaceAll('RAM_', '')),
              if (option.storageSize != null)
                _SpecChip(label: option.storageSize!.replaceAll('STORAGE_', '')),
            ]),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(Formatter.currency(option.price),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold,
                        color: AppTheme.primary)),
                if (option.unitCost != null)
                  Text('Cost: ${Formatter.currency(option.unitCost!)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textGrey)),
                _StockBadge(qty: option.quantity),
              ],
            ),
          ]),
        )),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppTheme.primary, size: 18),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) =>
                    _OptionFormScreen(product: product, editOption: option))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppTheme.danger, size: 18),
            onPressed: () => _deleteOption(context),
          ),
        ]),
      ]),
    );
  }

  Future<void> _deleteOption(BuildContext context) async {
    if (!await confirmDelete(context, 'លុបជម្រើស "${option.productCode}"?')) return;
    if (option.id.isEmpty) {
      showSnack(context, 'Cannot delete — no option ID', error: true); return;
    }
    final ok = await context.read<ProductProvider>().deleteOption(option.id);
    if (context.mounted) {
      showSnack(context, ok ? 'លុបបានជោគជ័យ' : 'មានបញ្ហា', error: !ok);
      if (ok) Navigator.pop(context);
    }
  }
}

class _SpecChip extends StatelessWidget {
  final String label;
  const _SpecChip({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppTheme.border)),
    child: Text(label,
        style: const TextStyle(fontSize: 10, color: AppTheme.textGrey,
            fontWeight: FontWeight.w500)),
  );
}

class _StockBadge extends StatelessWidget {
  final int qty;
  const _StockBadge({required this.qty});
  @override
  Widget build(BuildContext context) {
    final color = qty == 0 ? AppTheme.danger : qty < 10 ? AppTheme.warning : AppTheme.success;
    final lt    = qty == 0 ? AppTheme.dangerLt : qty < 10 ? AppTheme.warningLt : AppTheme.successLt;
    final label = qty == 0 ? 'អស់ស្តុក' : qty < 10 ? 'ទាប $qty' : 'Stock $qty';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: lt, borderRadius: BorderRadius.circular(5)),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon; final String label;
  const _InfoChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppTheme.textGrey),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  PRODUCT FORM SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class _ProductFormScreen extends StatefulWidget {
  final ProductModel? product;
  const _ProductFormScreen({this.product});
  @override
  State<_ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<_ProductFormScreen> {
  final _nameCtrl     = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _codeCtrl     = TextEditingController();
  final _priceCtrl    = TextEditingController();
  final _unitCostCtrl = TextEditingController();

  File?   _image;
  int?    _catId;
  int?    _supplierId;
  String? _ramSize;
  String? _storageSize;
  bool    _saving   = false;
  // FIX: tracks whether the checkbox is ticked AND a code has been
  // generated. Separating the two states prevents the code field from
  // re-generating on every rebuild while the checkbox stays ticked.
  bool    _autoCode = false;

  static const _ramOptions = [
    'RAM_4GB','RAM_6GB','RAM_8GB','RAM_12GB','RAM_16GB','RAM_32GB',
  ];
  static const _storageOptions = [
    'STORAGE_64GB','STORAGE_128GB','STORAGE_256GB','STORAGE_512GB','STORAGE_1TB',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _nameCtrl.text     = p.name;
      _descCtrl.text     = p.description ?? '';
      _codeCtrl.text     = p.firstOption?.productCode ?? '';
      _priceCtrl.text    = p.firstOption?.price.toStringAsFixed(2) ?? '';
      _unitCostCtrl.text = p.firstOption?.unitCost?.toStringAsFixed(2) ?? '';
      _ramSize    = _ramOptions.contains(p.firstOption?.ramSize)
          ? p.firstOption?.ramSize : null;
      _storageSize = _storageOptions.contains(p.firstOption?.storageSize)
          ? p.firstOption?.storageSize : null;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose();
    _codeCtrl.dispose(); _priceCtrl.dispose();
    _unitCostCtrl.dispose();
    super.dispose();
  }

  // ── FIX: was `_codeCtrl.text = 'kok-\${DateTime.now()...}'`  ────────────
  // That put the raw Dart expression as a literal string in the field.
  // Now calls _CodeGenerator.next() (an async function) which:
  //   1. reads the last counter from SharedPreferences,
  //   2. increments it,
  //   3. returns a formatted string like "kok-000001".
  // While waiting we show a placeholder so the field isn't blank.
  Future<void> _generateCode() async {
    _codeCtrl.text = 'generating…';
    final code = await _CodeGenerator.next();
    if (mounted) setState(() => _codeCtrl.text = code);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    final prod   = context.read<ProductProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: Text(isEdit ? 'កែប្រែផលិតផល' : 'បន្ថែមផលិតផល')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16, 16, 16,
            MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                32,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Image picker ───────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 130, height: 130,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 1.5),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: _image != null
                        ? Image.file(_image!, fit: BoxFit.cover)
                        : (widget.product?.imageUrl != null
                        ? _ProdImg(url: widget.product!.imageUrl)
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                            color: AppTheme.primaryLt,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.image_outlined, size: 30, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 8),
                      const Text('Choose Image',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: AppTheme.primary)),
                    ])),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),

            _SecHead(icon: Icons.inventory_2_outlined, label: 'Item Information'),
            const SizedBox(height: 12),

            // ── Generate code checkbox ─────────────────────────────────
            // FIX: previously set _codeCtrl.text to a raw Dart expression
            // string literal. Now correctly awaits _generateCode() which
            // calls _CodeGenerator.next() and writes kok-000001, kok-000002…
            // Unchecking clears the field so the user can type manually.
            Row(children: [
              Checkbox(
                value: _autoCode,
                activeColor: AppTheme.primary,
                onChanged: (v) {
                  final checked = v ?? false;
                  setState(() => _autoCode = checked);
                  if (checked) {
                    _generateCode();          // ← async, fills field when ready
                  } else {
                    _codeCtrl.clear();        // let user type their own code
                  }
                },
              ),
              const Text('Generate Item Code',
                  style: TextStyle(fontSize: 13, color: AppTheme.textDark)),
            ]),
            const SizedBox(height: 6),

            _TF(ctrl: _codeCtrl,  label: 'Item Code',    icon: Icons.grid_view_rounded,
                readOnly: _autoCode,
                onScan: _autoCode ? null : () => _scanCode(context)),
            const SizedBox(height: 12),
            _TF(ctrl: _nameCtrl,  label: 'Product Name', icon: Icons.label_outline),
            const SizedBox(height: 12),
            _TF(ctrl: _descCtrl,  label: 'Description',  icon: Icons.notes, maxLines: 2),
            const SizedBox(height: 12),

            const _DL('Category'),
            Consumer<ProductProvider>(
              builder: (_, pv, __) {
                if (_catId == null && widget.product?.category != null && pv.categories.isNotEmpty) {
                  final match = pv.categories.where((c) => c.name == widget.product!.category);
                  if (match.isNotEmpty) {
                    final resolvedId = int.tryParse(match.first.id);
                    if (resolvedId != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _catId = resolvedId);
                      });
                    }
                  }
                }
                return _DD<int>(
                  value: _catId,
                  hint: 'Category',
                  icon: Icons.category_outlined,
                  items: pv.categories.map((c) => DropdownMenuItem(
                      value: int.tryParse(c.id) ?? 0,
                      child: Text(c.name))).toList(),
                  onChanged: (v) => setState(() => _catId = v),
                );
              },
            ),
            const SizedBox(height: 18),

            _SecHead(icon: Icons.people_outlined, label: 'Supplier Information'),
            const SizedBox(height: 12),

            Consumer<SupplierProvider>(
              builder: (_, sv, __) {
                if (_supplierId == null && widget.product?.supplierName != null && sv.suppliers.isNotEmpty) {
                  final match = sv.suppliers.where((s) => s.name == widget.product!.supplierName);
                  if (match.isNotEmpty) {
                    final resolvedId = int.tryParse(match.first.id);
                    if (resolvedId != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _supplierId = resolvedId);
                      });
                    }
                  }
                }
                return _DD<int>(
                  value: _supplierId,
                  hint: 'Select Suppliers',
                  icon: Icons.local_shipping_outlined,
                  items: sv.suppliers.map((s) => DropdownMenuItem(
                      value: int.tryParse(s.id) ?? 0,
                      child: Text(s.name))).toList(),
                  onChanged: (v) => setState(() => _supplierId = v),
                );
              },
            ),
            const SizedBox(height: 12),

            _TF(ctrl: _priceCtrl, label: 'Item Price', icon: Icons.attach_money,
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),

            _TF(ctrl: _unitCostCtrl, label: 'Unit Cost', icon: Icons.payments_outlined,
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),

            const _DL('RAM Size'),
            _DD<String>(
              value: _ramOptions.contains(_ramSize) ? _ramSize : null,
              hint: 'Select RAM', icon: Icons.memory_outlined,
              items: _ramOptions.map((r) => DropdownMenuItem(
                  value: r, child: Text(r.replaceAll('RAM_', '')))).toList(),
              onChanged: (v) => setState(() => _ramSize = v),
            ),
            const SizedBox(height: 12),

            const _DL('Storage Size'),
            _DD<String>(
              value: _storageOptions.contains(_storageSize) ? _storageSize : null,
              hint: 'Select Storage', icon: Icons.storage_outlined,
              items: _storageOptions.map((s) => DropdownMenuItem(
                  value: s, child: Text(s.replaceAll('STORAGE_', '')))).toList(),
              onChanged: (v) => setState(() => _storageSize = v),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(isEdit ? Icons.save_outlined : Icons.add, size: 20),
                label: Text(isEdit ? 'Save Changes' : 'បន្ថែមផលិតផល',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: _saving ? null : () => _submit(context, prod),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p != null) setState(() => _image = File(p.path));
  }

  Future<void> _scanCode(BuildContext context) async {
    final code = await scanBarcode(context);
    if (code != null && code.isNotEmpty) {
      setState(() {
        _autoCode = false;
        _codeCtrl.text = code;
      });
    }
  }

  Future<void> _submit(BuildContext ctx, ProductProvider prod) async {
    if (_nameCtrl.text.trim().isEmpty) {
      showSnack(ctx, 'សូមបំពេញឈ្មោះផលិតផល', error: true); return;
    }
    setState(() => _saving = true);
    final fields = <String, String>{
      'name': _nameCtrl.text.trim(),
      if (_descCtrl.text.isNotEmpty) 'description': _descCtrl.text.trim(),
      if (_catId != null) 'categoryId': _catId.toString(),
      if (_supplierId != null) 'supplierId': _supplierId.toString(),
      if (_codeCtrl.text.isNotEmpty) 'productCode': _codeCtrl.text.trim(),
      if (_ramSize != null) 'ramSize': _ramSize!,
      if (_storageSize != null) 'storageSize': _storageSize!,
      if (_priceCtrl.text.isNotEmpty) 'price': _priceCtrl.text.trim(),
      if (_unitCostCtrl.text.isNotEmpty) 'unitCost': _unitCostCtrl.text.trim(),
    };
    final ok = widget.product == null
        ? await prod.createProduct(fields, image: _image)
        : await prod.updateProduct(widget.product!.id, fields, image: _image);
    setState(() => _saving = false);
    if (ctx.mounted) {
      if (ok) { Navigator.pop(ctx); showSnack(ctx, 'រក្សាទុកបានជោគជ័យ'); }
      else showSnack(ctx, 'មានបញ្ហា — សូមព្យាយាមម្ដងទៀត', error: true);
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  OPTION FORM SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class _OptionFormScreen extends StatefulWidget {
  final ProductModel product;
  final ProductOptionModel? editOption;
  const _OptionFormScreen({required this.product, this.editOption});
  @override
  State<_OptionFormScreen> createState() => _OptionFormScreenState();
}

class _OptionFormScreenState extends State<_OptionFormScreen> {
  final _codeCtrl     = TextEditingController();
  final _priceCtrl    = TextEditingController();
  final _unitCostCtrl = TextEditingController();

  File?   _image;
  String? _ramSize;
  String? _storageSize;
  bool    _saving   = false;
  bool    _autoCode = false;

  static const _ramOptions = [
    'RAM_4GB','RAM_6GB','RAM_8GB','RAM_12GB','RAM_16GB','RAM_32GB',
  ];
  static const _storageOptions = [
    'STORAGE_64GB','STORAGE_128GB','STORAGE_256GB','STORAGE_512GB','STORAGE_1TB',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.editOption;
    if (e != null) {
      _codeCtrl.text     = e.productCode;
      _priceCtrl.text    = e.price.toStringAsFixed(2);
      _unitCostCtrl.text = e.unitCost?.toStringAsFixed(2) ?? '';
      _ramSize     = _ramOptions.contains(e.ramSize) ? e.ramSize : null;
      _storageSize = _storageOptions.contains(e.storageSize) ? e.storageSize : null;
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose(); _priceCtrl.dispose();
    _unitCostCtrl.dispose();
    super.dispose();
  }

  // ── FIX: same broken-literal-string bug as the Product form. ─────────────
  // Calls _CodeGenerator.next() to produce kok-000001, kok-000002, …
  // The counter is shared with the Product form (same SharedPreferences
  // key) so codes are unique across both entry points.
  Future<void> _generateCode() async {
    _codeCtrl.text = 'generating…';
    final code = await _CodeGenerator.next();
    if (mounted) setState(() => _codeCtrl.text = code);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editOption != null;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(isEdit
            ? 'កែប្រែជម្រើស — ${widget.product.name}'
            : 'បន្ថែមជម្រើស — ${widget.product.name}'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16, 16, 16,
            MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                32,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Product info banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryLt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 44, height: 44,
                      child: _ProdImg(url: widget.product.imageUrl)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.product.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                            color: AppTheme.primary)),
                    Text('${widget.product.options.length} ជម្រើសរួចហើយ',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textGrey)),
                  ],
                )),
              ]),
            ),
            const SizedBox(height: 18),

            // Image picker
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 1.5)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: _image != null
                        ? Image.file(_image!, fit: BoxFit.cover)
                        : (widget.editOption?.imageUrl != null
                        ? _ProdImg(url: widget.editOption!.imageUrl)
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.add_photo_alternate_outlined,
                          size: 30, color: AppTheme.primary),
                      const SizedBox(height: 5),
                      const Text('Choose Image',
                          style: TextStyle(fontSize: 11, color: AppTheme.primary,
                              fontWeight: FontWeight.w600)),
                    ])),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            _SecHead(icon: Icons.tune, label: 'Option Details'),
            const SizedBox(height: 12),

            // ── Generate code checkbox ─────────────────────────────────
            // FIX: same fix as Product form — calls _generateCode() which
            // awaits _CodeGenerator.next() instead of writing a raw
            // Dart expression string like 'kok-\${...}' literally.
            Row(children: [
              Checkbox(
                value: _autoCode,
                activeColor: AppTheme.primary,
                onChanged: (v) {
                  final checked = v ?? false;
                  setState(() => _autoCode = checked);
                  if (checked) {
                    _generateCode();
                  } else {
                    _codeCtrl.clear();
                  }
                },
              ),
              const Text('Generate Item Code',
                  style: TextStyle(fontSize: 13, color: AppTheme.textDark)),
            ]),
            const SizedBox(height: 6),

            _TF(ctrl: _codeCtrl,  label: 'Product Code', icon: Icons.grid_view_rounded,
                readOnly: _autoCode,
                onScan: _autoCode ? null : () => _scanCode(context)),
            const SizedBox(height: 12),
            _TF(ctrl: _priceCtrl, label: 'Price', icon: Icons.attach_money,
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _TF(ctrl: _unitCostCtrl, label: 'Unit Cost', icon: Icons.payments_outlined,
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            const _DL('RAM Size'),
            _DD<String>(
              value: _ramOptions.contains(_ramSize) ? _ramSize : null,
              hint: 'Select RAM', icon: Icons.memory_outlined,
              items: _ramOptions.map((r) => DropdownMenuItem(
                  value: r, child: Text(r.replaceAll('RAM_', '')))).toList(),
              onChanged: (v) => setState(() => _ramSize = v),
            ),
            const SizedBox(height: 12),
            const _DL('Storage Size'),
            _DD<String>(
              value: _storageOptions.contains(_storageSize) ? _storageSize : null,
              hint: 'Select Storage', icon: Icons.storage_outlined,
              items: _storageOptions.map((s) => DropdownMenuItem(
                  value: s, child: Text(s.replaceAll('STORAGE_', '')))).toList(),
              onChanged: (v) => setState(() => _storageSize = v),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(isEdit ? Icons.save_outlined : Icons.add, size: 20),
                label: Text(isEdit ? 'Save Changes' : 'បន្ថែមជម្រើស',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: _saving ? null : _submit,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p != null) setState(() => _image = File(p.path));
  }

  Future<void> _scanCode(BuildContext context) async {
    final code = await scanBarcode(context);
    if (code != null && code.isNotEmpty) {
      setState(() {
        _autoCode = false;
        _codeCtrl.text = code;
      });
    }
  }

  Future<void> _submit() async {
    if (_codeCtrl.text.trim().isEmpty) {
      showSnack(context, 'សូមបំពេញ Product Code', error: true); return;
    }
    setState(() => _saving = true);

    final prod   = context.read<ProductProvider>();
    final isEdit = widget.editOption != null;

    final fields = <String, String>{
      'productId': widget.product.id,
      'productCode': _codeCtrl.text.trim(),
      if (_ramSize != null) 'ramSize': _ramSize!,
      if (_storageSize != null) 'storageSize': _storageSize!,
      if (_priceCtrl.text.isNotEmpty) 'price': _priceCtrl.text.trim(),
      if (_unitCostCtrl.text.isNotEmpty) 'unitCost': _unitCostCtrl.text.trim(),
    };

    final ok = isEdit
        ? await prod.updateOption(widget.editOption!.id, fields, image: _image)
        : await prod.createOption(fields, image: _image);

    setState(() => _saving = false);
    if (context.mounted) {
      if (ok) { Navigator.pop(context); showSnack(context, isEdit ? 'Updated!' : 'Option added!'); }
      else showSnack(context, 'Failed — please try again', error: true);
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════
Future<String?> scanBarcode(BuildContext context) async {
  return Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => const _BarcodeScanScreen()),
  );
}

class _BarcodeScanScreen extends StatefulWidget {
  const _BarcodeScanScreen();
  @override
  State<_BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<_BarcodeScanScreen> {
  final MobileScannerController _ctrl = MobileScannerController(
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );
  bool _handled = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onDetect(BarcodeCapture cap) {
    if (_handled) return;
    final raw = cap.barcodes.isNotEmpty ? cap.barcodes.first.rawValue : null;
    if (raw == null || raw.isEmpty) return;
    _handled = true;
    Navigator.pop(context, raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('ស្កេនកូដ', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _ctrl.toggleTorch(),
          ),
        ],
      ),
      body: Stack(children: [
        MobileScanner(controller: _ctrl, onDetect: _onDetect),
        Center(
          child: Container(
            width: 240, height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.primary, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          bottom: 32, left: 0, right: 0,
          child: Center(
            child: Text('ដាក់កូដបាកូដ/QR ឱ្យចំក្របខណ្ឌ',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
          ),
        ),
      ]),
    );
  }
}

class _ProdImg extends StatelessWidget {
  final String? url;
  const _ProdImg({this.url});

  static const _ph = ColoredBox(
    color: Color(0xFFF2F2F2),
    child: Center(child: Icon(Icons.inventory_2_outlined,
        color: Color(0xFFCCCCCC), size: 26)),
  );

  @override
  Widget build(BuildContext context) {
    final resolved = ImageHelper.resolve(url);
    if (kDebugMode) debugPrint('[ProdImg] raw="$url" → "$resolved"');
    if (resolved.isEmpty) return _ph;
    return Image.network(
      resolved,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, prog) {
        if (prog == null) return child;
        return Container(
          color: const Color(0xFFF2F2F2),
          child: Center(
            child: SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.primary,
                value: prog.expectedTotalBytes != null
                    ? prog.cumulativeBytesLoaded / prog.expectedTotalBytes!
                    : null,
              ),
            ),
          ),
        );
      },
      errorBuilder: (_, err, __) {
        debugPrint('[ProdImg] ✗ FAILED: $resolved  ($err)');
        return _ph;
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final String text; final Color color;
  const _Badge({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
    child: Text(text,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
  );
}

class _ActionBtn extends StatelessWidget {
  final Color color, iconColor; final IconData icon; final VoidCallback onTap;
  const _ActionBtn({required this.color, required this.icon, required this.iconColor, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 28,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, size: 14, color: iconColor),
    ),
  );
}

class _CategoryChips extends StatelessWidget {
  final ProductProvider provider;
  const _CategoryChips({required this.provider});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
        children: [
          _Chip(label: 'ទាំងអស់',
              sel: provider.selectedCategoryId == null,
              onTap: () => provider.setCategory(null)),
          ...provider.categories.map((c) => _Chip(
            label: c.name,
            sel: provider.selectedCategoryId == int.tryParse(c.id),
            onTap: () => provider.setCategory(int.tryParse(c.id)),
          )),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label; final bool sel; final VoidCallback onTap;
  const _Chip({required this.label, required this.sel, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(right: 7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: sel ? AppTheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sel ? AppTheme.primary : AppTheme.border),
      ),
      child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: sel ? Colors.white : AppTheme.textGrey)),
    ),
  );
}

class _FilterButton extends StatelessWidget {
  final ProductProvider provider;
  const _FilterButton({required this.provider});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(title: 'ចំណាត់ថ្នាក់'),
          ListTile(
            leading: const Icon(Icons.swap_vert),
            title: const Text('លំដាប់ដើម'),
            trailing: provider.sortMode == 'none' ? const Icon(Icons.check, color: AppTheme.primary) : null,
            onTap: () { provider.setSort('none'); Navigator.pop(context); },
          ),
          ListTile(
            leading: const Icon(Icons.sort_by_alpha),
            title: const Text('ឈ្មោះ A–Z'),
            trailing: provider.sortMode == 'name' ? const Icon(Icons.check, color: AppTheme.primary) : null,
            onTap: () { provider.setSort('name'); Navigator.pop(context); },
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('តម្លៃ ទាប–ខ្ពស់'),
            trailing: provider.sortMode == 'price' ? const Icon(Icons.check, color: AppTheme.primary) : null,
            onTap: () { provider.setSort('price'); Navigator.pop(context); },
          ),
        ]),
      ),
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border)),
      child: Row(children: const [
        Icon(Icons.sort, size: 16, color: AppTheme.textGrey),
        SizedBox(width: 4),
        Text('ស្រង់', style: TextStyle(fontSize: 12, color: AppTheme.textGrey)),
      ]),
    ),
  );
}

class _SecHead extends StatelessWidget {
  final IconData icon; final String label;
  const _SecHead({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: AppTheme.primary),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary)),
    const SizedBox(width: 12),
    Expanded(child: Container(height: 1, color: AppTheme.border)),
  ]);
}

class _TF extends StatelessWidget {
  final TextEditingController ctrl;
  final String label; final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines; final bool readOnly;
  final VoidCallback? onScan;
  const _TF({required this.ctrl, required this.label, required this.icon,
    this.keyboardType, this.maxLines = 1, this.readOnly = false, this.onScan});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, keyboardType: keyboardType,
    maxLines: maxLines, readOnly: readOnly,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppTheme.primary, size: 18),
      suffixIcon: onScan == null ? null : IconButton(
        icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primary, size: 20),
        tooltip: 'ស្កេនកូដ',
        onPressed: onScan,
      ),
      filled: true,
      fillColor: readOnly ? const Color(0xFFF5F5F5) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
    ),
  );
}

class _DL extends StatelessWidget {
  final String text;
  const _DL(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 2),
    child: Text(text, style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textGrey)),
  );
}

class _DD<T> extends StatelessWidget {
  final T? value; final String hint; final IconData icon;
  final List<DropdownMenuItem<T>> items; final ValueChanged<T?> onChanged;
  const _DD({this.value, required this.hint, required this.icon,
    required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    value: value, isExpanded: true,
    decoration: InputDecoration(
      prefixIcon: Icon(icon, color: AppTheme.primary, size: 18),
      hintText: hint, filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
    ),
    items: items, onChanged: onChanged,
  );
}