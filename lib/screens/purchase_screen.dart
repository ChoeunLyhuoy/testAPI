// lib/screens/purchase_screen.dart
//
// UI rebuilt to match invoice_screen.dart style:
//  • Purchase LIST → striped table rows (like invoice list), white cards,
//    primary-colour amounts, clean Khmer labels
//  • Purchase DETAIL → same _Card / _DR / _SR widget pattern as invoice detail,
//    item rows with image + spec label, totals card
//  • Create Purchase → unchanged layout (purchase header + category chips +
//    grid + bottom nav), same as before
//  • Zero logic changes — all providers, models, API calls untouched

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';
import '../providers/purchase_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../utils/image_helper.dart';
import '../widgets/common_widgets.dart';
import 'product_screen.dart' show scanBarcode;
import '../services/api_service.dart';
import '../utils/pos_report_helper.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  PURCHASE LIST SCREEN  — invoice-style table layout
// ══════════════════════════════════════════════════════════════════════════════
class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});
  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchaseProvider>().load();
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
        title: const Text('ការទិញ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
            tooltip: 'របាយការណ៍ការទិញ',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const _PurchaseReportModal())),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: 'ការទិញថ្មី',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const _CreatePurchaseScreen())),
          ),
        ],
      ),
      body: Consumer<PurchaseProvider>(
        builder: (_, prov, __) {
          if (prov.isLoading) return const AppLoading();
          if (prov.purchases.isEmpty) {
            return EmptyState(
              message: 'រកមិនឃើញការទិញ',
              icon: Icons.shopping_bag_outlined,
              action: 'ការទិញថ្មី',
              onAction: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const _CreatePurchaseScreen())),
            );
          }

          return Column(children: [
            // ── Table header (invoice-style) ─────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: const [
                SizedBox(
                    width: 32,
                    child: Text('ល.រ', style: _hdrStyle, textAlign: TextAlign.center)),
                SizedBox(width: 10),
                Expanded(flex: 4, child: Text('លេខការទិញ', style: _hdrStyle)),
                Expanded(flex: 4,
                    child: Text('កាលបរិច្ឆេទ', style: _hdrStyle, textAlign: TextAlign.center)),
                Expanded(flex: 3,
                    child: Text('សរុប', style: _hdrStyle, textAlign: TextAlign.right)),
              ]),
            ),
            Container(height: 1, color: AppTheme.border),

            // ── Rows ─────────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: prov.purchases.length,
                itemBuilder: (_, i) => _PurchaseRow(
                  index: i + 1,
                  purchase: prov.purchases[i],
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => _PurchaseDetailScreen(
                              purchaseId: prov.purchases[i].id))),
                ),
              ),
            ),

            // ── Bottom summary bar ────────────────────────────────────────
            _PurchaseBottomBar(purchases: prov.purchases),
          ]);
        },
      ),
    );
  }
}

const _hdrStyle = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textDark);

// ── Striped purchase row (invoice-style) ──────────────────────────────────────
class _PurchaseRow extends StatelessWidget {
  final int index;
  final PurchaseModel purchase;
  final VoidCallback onTap;
  const _PurchaseRow({
    required this.index,
    required this.purchase,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: index.isOdd ? Colors.white : const Color(0xFFFAF0F4),
          border: const Border(
              bottom: BorderSide(color: AppTheme.border, width: 0.5)),
        ),
        child: Row(children: [
          // Index
          SizedBox(
            width: 32,
            child: Text('$index',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppTheme.textGrey)),
          ),
          const SizedBox(width: 10),
          // Purchase number
          Expanded(
            flex: 4,
            child: Text(
              purchase.purchaseNumber ?? '-',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark),
            ),
          ),
          // Date
          Expanded(
            flex: 4,
            child: Text(
              Formatter.date(purchase.createdAt),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
            ),
          ),
          // Amount
          Expanded(
            flex: 3,
            child: Text(
              Formatter.currency(purchase.totalAmount),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Bottom summary bar ────────────────────────────────────────────────────────
class _PurchaseBottomBar extends StatelessWidget {
  final List<PurchaseModel> purchases;
  const _PurchaseBottomBar({required this.purchases});

  double get _total =>
      purchases.fold(0.0, (s, p) => s + p.totalAmount);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text(
            'សរុបចំនួន : ${purchases.length}',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary),
          ),
          const Spacer(),
          const Text('តម្លៃសរុប  ',
              style: TextStyle(fontSize: 12, color: AppTheme.textGrey)),
          Text(
            Formatter.currency(_total),
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.download_outlined,
                color: AppTheme.primary, size: 18),
            label: const Text('ទាញយករបាយការណ៍',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const _PurchaseReportModal())),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PURCHASE DETAIL SCREEN  — invoice-detail card style
// ══════════════════════════════════════════════════════════════════════════════
class _PurchaseDetailScreen extends StatefulWidget {
  final String purchaseId;
  const _PurchaseDetailScreen({required this.purchaseId});
  @override
  State<_PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<_PurchaseDetailScreen> {
  PurchaseModel? _purchase;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final detail = await context
          .read<PurchaseProvider>()
          .fetchDetail(widget.purchaseId);
      if (mounted) setState(() { _purchase = detail; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(_purchase != null ? '#${_purchase!.id}' : 'ព័ត៌មានការទិញ'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_outlined), onPressed: _fetch),
        ],
      ),
      body: _loading
          ? const AppLoading()
          : _error != null
          ? _ErrorView(error: _error!, onRetry: _fetch)
          : _PurchaseDetailBody(purchase: _purchase!),
    );
  }
}

// ── Detail body — card-based layout matching invoice detail ──────────────────
class _PurchaseDetailBody extends StatelessWidget {
  final PurchaseModel purchase;
  const _PurchaseDetailBody({required this.purchase});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          12, 14, 12, MediaQuery.of(context).padding.bottom + 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── CARD 1: Purchase header info ─────────────────────────────────
        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Card title row
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: AppTheme.primaryLt,
                  borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.shopping_bag_outlined,
                  color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('ព័ត៌មានការទិញ',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark)),
          ]),
          const _Div(),
          _DR(label: 'លេខការទិញ', value: '#${purchase.id}', bold: true),
          const _Div(),
          _DR(
            label: 'ថ្ងៃទិញ',
            value:
            '${Formatter.date(purchase.createdAt)}  ${Formatter.time(purchase.createdAt)}',
          ),
          if ((purchase.note ?? '').trim().isNotEmpty) ...[
            const _Div(),
            _DR(label: 'កំណត់ចំណាំ', value: purchase.note!.trim()),
          ],
        ])),
        const SizedBox(height: 12),

        // ── CARD 2: Items table ──────────────────────────────────────────
        _Card(
          padding: EdgeInsets.zero,
          child: Column(children: [
            // Table header — primaryLt bg matching invoice style
            Container(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              decoration: const BoxDecoration(
                color: AppTheme.primaryLt,
                borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Row(children: const [
                Expanded(flex: 4, child: Text('ទំនិញ', style: _thStyle)),
                SizedBox(
                    width: 36,
                    child: Text('ចំ', style: _thStyle, textAlign: TextAlign.center)),
                SizedBox(
                    width: 64,
                    child: Text('តម្លៃទិញ', style: _thStyle, textAlign: TextAlign.right)),
                SizedBox(
                    width: 64,
                    child: Text('សរុប', style: _thStyle, textAlign: TextAlign.right)),
              ]),
            ),
            if (purchase.items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text('មិនមានទំនិញ',
                      style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                ),
              )
            else
              ...purchase.items.asMap().entries.map((e) => _PurchaseItemRow(
                item: e.value,
                isLast: e.key == purchase.items.length - 1,
              )),
          ]),
        ),
        const SizedBox(height: 12),

        // ── CARD 3: Totals ───────────────────────────────────────────────
        _Card(child: Column(children: [
          _SR(
            label: 'ចំនួនទំនិញ',
            value: '${purchase.items.fold(0, (s, i) => s + i.quantity)} ធាតុ',
          ),
          const _Div(),
          Row(children: [
            const Expanded(
              child: Text('តម្លៃសរុប',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark)),
            ),
            Text(
              Formatter.currency(purchase.totalAmount),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary),
            ),
          ]),
        ])),
      ]),
    );
  }
}

const _thStyle = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary);

// ── Purchase item row ─────────────────────────────────────────────────────────
class _PurchaseItemRow extends StatelessWidget {
  final PurchaseItemModel item;
  final bool isLast;
  const _PurchaseItemRow({required this.item, required this.isLast});

  static const _ph = ColoredBox(
    color: Color(0xFFF2F2F2),
    child: Center(
        child: Icon(Icons.inventory_2_outlined,
            color: Color(0xFFCCCCCC), size: 18)),
  );

  Widget _img(String? url) {
    final r = ImageHelper.resolve(url);
    if (r.isEmpty) return _ph;
    return Image.network(r,
        fit: BoxFit.cover, errorBuilder: (_, __, ___) => _ph);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Image + name + spec + code
          Expanded(
            flex: 4,
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(width: 42, height: 42, child: _img(item.imageUrl)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.productName,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (item.specLabel.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(item.specLabel,
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.primary)),
                      ],
                      if (item.productCode.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(item.productCode,
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textGrey,
                                fontFamily: 'monospace')),
                      ],
                    ]),
              ),
            ]),
          ),
          // Qty
          SizedBox(
            width: 36,
            child: Text('×${item.quantity}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppTheme.textGrey)),
          ),
          // Unit cost
          SizedBox(
            width: 64,
            child: Text(Formatter.currency(item.unitCost),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, color: AppTheme.textGrey)),
          ),
          // Line total
          SizedBox(
            width: 64,
            child: Text(Formatter.currency(item.unitCost * item.quantity),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark)),
          ),
        ]),
      ),
      if (!isLast) const Divider(height: 1, color: AppTheme.border),
    ]);
  }
}

// ── Error view ────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 52, color: AppTheme.danger),
        const SizedBox(height: 14),
        Text(error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textGrey)),
        const SizedBox(height: 20),
        ElevatedButton(
            onPressed: onRetry,
            child: const Text('ព្យាយាមម្ដងទៀត')),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  CREATE PURCHASE — unchanged layout
// ══════════════════════════════════════════════════════════════════════════════
class _CreatePurchaseScreen extends StatefulWidget {
  const _CreatePurchaseScreen();
  @override
  State<_CreatePurchaseScreen> createState() => _CreatePurchaseState();
}

class _CreatePurchaseState extends State<_CreatePurchaseScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedCategory = 'All';
  final Map<String, Map<String, dynamic>> _cart = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierProvider>().load();
      context.read<ProductProvider>().loadAll();
    });
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  int get _cartCount =>
      _cart.values.fold(0, (sum, i) => sum + (i['quantity'] as int));

  List<ProductModel> _filteredProducts(List<ProductModel> all) {
    return all.where((p) {
      final catMatch =
          _selectedCategory == 'All' || p.category == _selectedCategory;
      final qMatch = _query.isEmpty ||
          p.name.toLowerCase().contains(_query.toLowerCase()) ||
          p.options.any((o) =>
              o.productCode.toLowerCase().contains(_query.toLowerCase()));
      return catMatch && qMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('ការទិញថ្មី'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer2<ProductProvider, SupplierProvider>(
        builder: (_, prodProv, supProv, __) {
          final products = _filteredProducts(prodProv.products);
          final categories = <String>{
            'All',
            ...prodProv.categories.map((c) => c.name),
          }.toList();

          return Column(children: [
            _PurchaseHeader(
              searchCtrl: _searchCtrl,
              onSearchChanged: (v) => setState(() => _query = v),
              onScan: () => _scanToSearch(context),
            ),
            _CategoryChipRow(
              categories: categories,
              selected: _selectedCategory,
              onSelect: (c) => setState(() => _selectedCategory = c),
            ),
            Expanded(
              child: prodProv.isLoading
                  ? const AppLoading()
                  : products.isEmpty
                  ? const EmptyState(
                  message: 'រកមិនឃើញផលិតផល',
                  icon: Icons.inventory_2_outlined)
                  : GridView.builder(
                padding:
                const EdgeInsets.fromLTRB(12, 12, 12, 90),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.72,
                ),
                itemCount: products.length,
                itemBuilder: (_, i) => _ProductPickCard(
                  product: products[i],
                  qtyInCart: _qtyForProduct(products[i]),
                  onTap: () => _onProductTap(context, products[i]),
                ),
              ),
            ),
          ]);
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: const Color(0xFFEEEEEE),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            _CartFab(count: _cartCount, onTap: () => _openCart(context)),
            const Spacer(),
            GestureDetector(
              onTap: _cart.isEmpty ? null : () => _openCart(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: _cart.isEmpty
                      ? const Color(0xFFCCCCCC)
                      : const Color(0xFFAAAAAA),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'Go to Cart',
                  style: TextStyle(
                      color: _cart.isEmpty
                          ? const Color(0xFF888888)
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _scanToSearch(BuildContext context) async {
    final code = await scanBarcode(context);
    if (code != null && code.isNotEmpty) {
      setState(() { _searchCtrl.text = code; _query = code; });
    }
  }

  int _qtyForProduct(ProductModel p) {
    return _cart.values
        .where((i) => i['productId'] == p.id)
        .fold(0, (sum, i) => sum + (i['quantity'] as int));
  }

  Future<void> _onProductTap(BuildContext context, ProductModel p) async {
    if (p.options.isEmpty) {
      showSnack(context, 'ផលិតផលនេះមិនមានជម្រើស', error: true);
      return;
    }
    if (p.options.length == 1) {
      _addOptionToCart(p, p.options.first);
      return;
    }
    final opt = await Navigator.push<ProductOptionModel>(
      context,
      MaterialPageRoute(builder: (_) => _OptionPickerScreen(product: p)),
    );
    if (opt != null) _addOptionToCart(p, opt);
  }

  void _addOptionToCart(ProductModel p, ProductOptionModel opt) {
    setState(() {
      final key = opt.id.isNotEmpty ? opt.id : p.id;
      final existing = _cart[key];
      _cart[key] = {
        'productId': p.id,
        'optionId': opt.id,
        'name': p.options.length > 1 ? '${p.name} (${opt.specLabel})' : p.name,
        'productCode': opt.productCode,
        'imageUrl': opt.imageUrl ?? p.imageUrl,
        'quantity': (existing?['quantity'] as int? ?? 0) + 1,
        'unitCost': opt.unitCost ?? opt.price,
        'price': opt.price,
      };
    });
    showSnack(context, '${p.name} ត្រូវបានបញ្ចូល');
  }

  Future<void> _openCart(BuildContext context) async {
    final note = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) => _CartScreen(
            cart: _cart,
            onUpdate: (id, qty) => setState(() {
              if (qty <= 0) _cart.remove(id);
              else _cart[id]!['quantity'] = qty;
            }),
          )),
    );
    if (note != null) await _submit(context, note);
  }

  Future<void> _submit(BuildContext context, String note) async {
    if (_cart.isEmpty) {
      showSnack(context, 'សូមបញ្ចូលធាតុមួយយ៉ាងហោចណាស់', error: true);
      return;
    }
    setState(() => _submitting = true);
    final supProv = context.read<SupplierProvider>();
    final supplierId = supProv.suppliers.isNotEmpty ? supProv.suppliers.first.id : "1";
    final body = {
      'supplierId': supplierId,
      if (note.trim().isNotEmpty) 'note': note.trim(),
      'items': _cart.values.map((i) => {
        'productCode': i['productCode'],
        'quantity': i['quantity'],
        'unitCost': i['unitCost'],
        'unitPrice': (i['price'] as num?) ?? i['unitCost'],
      }).toList(),
    };
    final ok = await context.read<PurchaseProvider>().create(body);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      setState(() => _cart.clear());
      Navigator.pop(context);
      showSnack(context, 'បង្កើតការទិញដោយជោគជ័យ');
    } else {
      showSnack(context, 'មានបញ្ហា — សូមព្យាយាមម្ដងទៀត', error: true);
    }
  }
}

// ── Purchase header (primary-bg strip) ────────────────────────────────────────
class _PurchaseHeader extends StatelessWidget {
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onScan;

  const _PurchaseHeader({
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.primary,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(children: [
        // Search row
        Row(children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10)),
              child: TextField(
                controller: searchCtrl,
                onChanged: onSearchChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'ស្វែងរកផលិតផល...',
                  hintStyle: const TextStyle(color: AppTheme.textGrey),
                  border: InputBorder.none,
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner,
                        color: AppTheme.primary),
                    tooltip: 'ស្កេនកូដ',
                    onPressed: onScan,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10)),
            child: IconButton(
              icon: const Icon(Icons.search, color: AppTheme.primary),
              tooltip: 'ស្វែងរក',
              onPressed: () => FocusScope.of(context).unfocus(),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Category chips ────────────────────────────────────────────────────────────
class _CategoryChipRow extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;
  const _CategoryChipRow({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: categories.length,
          itemBuilder: (_, i) {
            final c = categories[i];
            final sel = selected == c;
            return GestureDetector(
              onTap: () => onSelect(c),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.primary : const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(c,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : AppTheme.textDark)),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Product pick card ─────────────────────────────────────────────────────────
class _ProductPickCard extends StatelessWidget {
  final ProductModel product;
  final int qtyInCart;
  final VoidCallback onTap;
  const _ProductPickCard({
    required this.product,
    required this.qtyInCart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cost = product.unitCost ?? product.price;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primary.withOpacity(0.35)),
        ),
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(9)),
                child: SizedBox.expand(
                    child: _PurchaseProdImg(url: product.imageUrl)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text('តម្លៃ:  ${Formatter.currency(cost)}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary)),
                  ]),
            ),
          ]),
          if (qtyInCart > 0)
            Positioned(
              top: 6, right: 6,
              child: Container(
                width: 20, height: 20,
                decoration: const BoxDecoration(
                    color: AppTheme.primary, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('$qtyInCart',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          if (product.options.length > 1)
            Positioned(
              top: 6, left: 6,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(5)),
                child: Text('${product.options.length} opts',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Option picker screen ───────────────────────────────────────────────────────
class _OptionPickerScreen extends StatelessWidget {
  final ProductModel product;
  const _OptionPickerScreen({required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(product.name),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text('ជ្រើសរើសជម្រើស (${product.options.length})',
              style:
              const TextStyle(fontSize: 13, color: AppTheme.textGrey)),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: product.options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final opt = product.options[i];
              final cost = opt.unitCost ?? opt.price;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.pop(context, opt),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                          width: 58,
                          height: 58,
                          child: _PurchaseProdImg(
                              url: opt.imageUrl ?? product.imageUrl)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(opt.specLabel,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                            const SizedBox(height: 3),
                            Text(opt.productCode,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textGrey)),
                          ]),
                    ),
                    const SizedBox(width: 8),
                    Text('Cost: ${Formatter.currency(cost)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.primary)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: AppTheme.textGrey),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ── Image loader ──────────────────────────────────────────────────────────────
class _PurchaseProdImg extends StatelessWidget {
  final String? url;
  const _PurchaseProdImg({this.url});

  static const _ph = ColoredBox(
    color: Color(0xFFF7F7F7),
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.image_not_supported_outlined,
            color: Color(0xFFBBBBBB), size: 30),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final resolved = ImageHelper.resolve(url);
    if (resolved.isEmpty) return _ph;
    return Image.network(
      resolved,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _ph,
      loadingBuilder: (_, child, prog) =>
      prog == null ? child : const ColoredBox(color: Color(0xFFF7F7F7)),
    );
  }
}

// ── Cart FAB ──────────────────────────────────────────────────────────────────
class _CartFab extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _CartFab({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF9E9E9E),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
        ),
        if (count > 0)
          Positioned(
            top: -4, right: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: AppTheme.danger, shape: BoxShape.circle),
              constraints:
              const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text('$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CART SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class _CartScreen extends StatefulWidget {
  final Map<String, Map<String, dynamic>> cart;
  final void Function(String id, int qty) onUpdate;
  const _CartScreen({required this.cart, required this.onUpdate});
  @override
  State<_CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<_CartScreen> {
  bool _generating = false;
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  double _lineCost(Map<String, dynamic> i) =>
      (i['unitCost'] as num).toDouble() * (i['quantity'] as int);

  double _linePrice(Map<String, dynamic> i) =>
      ((i['price'] as num?) ?? (i['unitCost'] as num)).toDouble() *
          (i['quantity'] as int);

  double get _totalCost =>
      widget.cart.values.fold(0.0, (sum, i) => sum + _lineCost(i));

  double get _totalPrice =>
      widget.cart.values.fold(0.0, (sum, i) => sum + _linePrice(i));

  int get _totalItems =>
      widget.cart.values.fold(0, (sum, i) => sum + (i['quantity'] as int));

  Future<void> _editQuantity(String id, int currentQty) async {
    final ctrl = TextEditingController(text: '$currentQty');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('កែចំនួន',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
              labelText: 'ចំនួន', border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('បោះបង់')),
          ElevatedButton(
            style:
            ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('យល់ព្រម',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      setState(() => widget.onUpdate(id, result));
    } else if (result == 0) {
      setState(() => widget.onUpdate(id, 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.cart.entries.toList();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('រទេះ'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _generating
                ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.download_outlined, color: Colors.white),
            tooltip: 'ទាញយករបាយការណ៍',
            onPressed: entries.isEmpty || _generating
                ? null
                : () => _downloadReport(context),
          ),
        ],
      ),
      body: entries.isEmpty
          ? const EmptyState(
          message: 'រទេះទទេ', icon: Icons.shopping_cart_outlined)
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
        itemCount: entries.length,
        itemBuilder: (_, i) {
          final id   = entries[i].key;
          final item = entries[i].value;
          final qty       = item['quantity'] as int;
          final unitCost  = (item['unitCost'] as num).toDouble();
          final unitPrice =
          ((item['price'] as num?) ?? unitCost).toDouble();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                          width: 52, height: 52,
                          child: _PurchaseProdImg(
                              url: item['imageUrl']?.toString())),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['name']?.toString() ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            if ((item['productCode'] as String?)?.isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 2),
                              Text(item['productCode'].toString(),
                                  style: const TextStyle(
                                      fontSize: 11, color: AppTheme.textGrey)),
                            ],
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8, runSpacing: 4,
                              children: [
                                _PriceTag(
                                    label: 'Price',
                                    value: unitPrice,
                                    color: AppTheme.primary),
                                _PriceTag(
                                    label: 'Cost',
                                    value: unitCost,
                                    color: AppTheme.textGrey),
                              ],
                            ),
                          ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Row(children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove_circle_outline,
                              size: 20, color: AppTheme.primary),
                          onPressed: () =>
                              setState(() => widget.onUpdate(id, qty - 1)),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _editQuantity(id, qty),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            child: Text('$qty',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                    decorationStyle:
                                    TextDecorationStyle.dotted)),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_circle_outline,
                              size: 20, color: AppTheme.primary),
                          onPressed: () =>
                              setState(() => widget.onUpdate(id, qty + 1)),
                        ),
                      ]),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppTheme.danger),
                        tooltip: 'លុបចេញពីរទេះ',
                        onPressed: () =>
                            setState(() => widget.onUpdate(id, 0)),
                      ),
                    ]),
                  ]),
                  const Divider(height: 16),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('សរុបធាតុ',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textGrey)),
                        Text(Formatter.currency(unitCost * qty),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.primary)),
                      ]),
                ]),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2))
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppField(
                controller: _noteCtrl,
                label: 'កំណត់ចំណាំ (Note) — ស្រេចចិត្ត',
                icon: Icons.notes_outlined,
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('ចំនួនធាតុ ($_totalItems)',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textGrey)),
              Text('តម្លៃលក់: ${Formatter.currency(_totalPrice)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textGrey)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('តម្លៃទិញសរុប',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textGrey)),
                      Text(Formatter.currency(_totalCost),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary)),
                    ]),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: entries.isEmpty
                    ? null
                    : () => Navigator.pop(context, _noteCtrl.text),
                child: const Text('បញ្ជូន',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _downloadReport(BuildContext context) async {
    setState(() => _generating = true);
    try {
      final bytes = await _buildReportPdf();
      if (!mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename:
        'purchase_order_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (_) {
      if (mounted)
        showSnack(context, 'មិនអាចបង្កើតរបាយការណ៍បានទេ', error: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<Uint8List> _buildReportPdf() async {
    final font = await PdfGoogleFonts.nokoraRegular();
    final fontBold = await PdfGoogleFonts.nokoraBold();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
      ),
    );
    final entries = widget.cart.entries.toList();
    final now     = DateTime.now();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Text('Purchase Order Report',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Generated: ${Formatter.date(now)}',
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1.4),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1.4),
              4: pw.FlexColumnWidth(1.4),
              5: pw.FlexColumnWidth(1.6),
            },
            children: [
              pw.TableRow(
                decoration:
                const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfCell('Product', bold: true),
                  _pdfCell('Code', bold: true),
                  _pdfCell('Qty', bold: true),
                  _pdfCell('Cost', bold: true),
                  _pdfCell('Price', bold: true),
                  _pdfCell('Subtotal', bold: true),
                ],
              ),
              for (final e in entries)
                pw.TableRow(children: [
                  _pdfCell(e.value['name']?.toString() ?? ''),
                  _pdfCell(e.value['productCode']?.toString() ?? ''),
                  _pdfCell('${e.value['quantity']}'),
                  _pdfCell(Formatter.currency(
                      (e.value['unitCost'] as num).toDouble())),
                  _pdfCell(Formatter.currency(((e.value['price'] as num?) ??
                      (e.value['unitCost'] as num))
                      .toDouble())),
                  _pdfCell(Formatter.currency(_lineCost(e.value))),
                ]),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Total Items: $_totalItems',
                      style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 2),
                  pw.Text(
                      'Total Sale Value: ${Formatter.currency(_totalPrice)}',
                      style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 2),
                  pw.Text('Total Cost: ${Formatter.currency(_totalCost)}',
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ]),
          ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _pdfCell(String text, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text,
        style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight:
            bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
  );
}

// ── Small price/cost label chip ────────────────────────────────────────────────
class _PriceTag extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _PriceTag(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text('$label: ${Formatter.currency(value)}',
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PURCHASE REPORT MODAL
// ══════════════════════════════════════════════════════════════════════════════
class _PurchaseReportModal extends StatefulWidget {
  const _PurchaseReportModal({super.key});
  @override
  State<_PurchaseReportModal> createState() => _PurchaseReportModalState();
}

class _PurchaseReportModalState extends State<_PurchaseReportModal> {
  DateTime _from =
  DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to   = DateTime.now();
  bool _loading  = false;
  String? _activeReport;
  SupplierModel? _selectedSupplier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierProvider>().load();
    });
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020), lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() { _from = picked.start; _to = picked.end; });
  }

  Future<void> _download(String mode, String pageFormat) async {
    setState(() { _activeReport = mode; _loading = true; });
    try {
      final res     = await ApiService.getPurchases(page: 0, size: 200);
      final rawList = ApiService.extractList(res);
      var all       = rawList
          .map((e) => PurchaseModel.fromMap(e as Map<String, dynamic>))
          .where((p) =>
      !p.createdAt.isBefore(_from) &&
          !p.createdAt.isAfter(_to.add(const Duration(days: 1))))
          .toList();

      // Apply supplier filter
      if (_selectedSupplier != null) {
        all = all.where((p) => p.supplierName?.toLowerCase() == _selectedSupplier!.name.toLowerCase()).toList();
      }

      final withItems = <PurchaseModel>[];
      for (final p in all) {
        if (p.items.isEmpty) {
          final detail =
          await context.read<PurchaseProvider>().fetchDetail(p.id);
          withItems.add(detail ?? p);
        } else {
          withItems.add(p);
        }
      }
      if (!mounted) return;
      await printPurchaseReport(
        context: context,
        mode: mode,
        pageFormat: pageFormat,
        purchases: withItems,
        from: _from,
        to: _to,
        supplierFilter: _selectedSupplier?.name,
      );
    } catch (e) {
      if (mounted) showSnack(context, 'មិនអាចបង្កើត PDF: $e', error: true);
    } finally {
      if (mounted) setState(() { _activeReport = null; _loading = false; });
    }
  }

  Future<void> _showPrintOptions(String mode) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(title: 'ជ្រើសរើសទំហំរបាយការណ៍'),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.primary),
                title: const Text('របាយការណ៍ A4', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('សាកសមសម្រាប់ព្រីនលើក្រដាស A4 ឬទាញយក'),
                onTap: () {
                  Navigator.pop(ctx);
                  _download(mode, 'a4');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.print_outlined, color: AppTheme.primary),
                title: const Text('របាយការណ៍ 80mm (Compact)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('សាកសមសម្រាប់ម៉ាស៊ីនព្រីនវិក្កយបត្រ thermal'),
                onTap: () {
                  Navigator.pop(ctx);
                  _download(mode, 'compact');
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('បោះបង់', style: TextStyle(color: AppTheme.textDark)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('របាយការណ៍ការទិញ'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Date range
          GestureDetector(
            onTap: _loading ? null : _pickRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(children: [
                const Icon(Icons.date_range_outlined,
                    size: 18, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ជ្រើសរើសកាលបរិច្ឆេទ',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.textGrey)),
                        const SizedBox(height: 2),
                        Text(
                          '${_shortDate(_from)}  →  ${_shortDate(_to)}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark),
                        ),
                      ]),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textGrey),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Supplier filter
          Consumer<SupplierProvider>(
            builder: (context, provider, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(children: [
                  const Icon(Icons.local_shipping_outlined,
                      size: 18, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ជ្រើសរើសអ្នកផ្គត់ផ្គង់',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.textGrey)),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<SupplierModel?>(
                            value: _selectedSupplier,
                            isExpanded: true,
                            hint: const Text('អ្នកផ្គត់ផ្គង់ទាំងអស់ (All)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                            items: [
                              const DropdownMenuItem<SupplierModel?>(
                                value: null,
                                child: Text('អ្នកផ្គត់ផ្គង់ទាំងអស់ (All)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                              ),
                              ...provider.suppliers.map((s) => DropdownMenuItem<SupplierModel?>(
                                value: s,
                                child: Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                              )),
                            ],
                            onChanged: _loading ? null : (val) {
                              setState(() {
                                _selectedSupplier = val;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text('ជ្រើសរើសប្រភេទរបាយការណ៍',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark)),
          const SizedBox(height: 12),

          _ReportCard(
            icon: Icons.list_alt_outlined,
            title: 'បញ្ជីការទិញ',
            subtitle: 'ទំនិញទាំងអស់ក្នុងរបាយការណ៍ស្តុក',
            color: const Color(0xFF1565C0),
            isLoading: _activeReport == 'listing',
            disabled: _loading,
            onDownload: () => _showPrintOptions('listing'),
          ),
          const SizedBox(height: 10),
          _ReportCard(
            icon: Icons.receipt_long_outlined,
            title: 'តាមវិក្កយបត្រ',
            subtitle: 'ចាត់ក្រុមតាមលេខបញ្ជាទិញ',
            color: AppTheme.primary,
            isLoading: _activeReport == 'byInvoice',
            disabled: _loading,
            onDownload: () => _showPrintOptions('byInvoice'),
          ),
          const SizedBox(height: 10),
          _ReportCard(
            icon: Icons.calendar_today_outlined,
            title: 'តាមកាលបរិច្ឆេទ',
            subtitle: 'ចាត់ក្រុមតាមថ្ងៃទិញ',
            color: const Color(0xFF2E7D32),
            isLoading: _activeReport == 'byDate',
            disabled: _loading,
            onDownload: () => _showPrintOptions('byDate'),
          ),
          const SizedBox(height: 10),
          _ReportCard(
            icon: Icons.local_shipping_outlined,
            title: 'តាមអ្នកផ្គត់ផ្គង់',
            subtitle: 'ចាត់ក្រុមតាមឈ្មោះអ្នកផ្គត់ផ្គង់',
            color: const Color(0xFFE65100),
            isLoading: _activeReport == 'bySupplier',
            disabled: _loading,
            onDownload: () => _showPrintOptions('bySupplier'),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppTheme.infoLt,
                borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppTheme.info, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PDF នឹងត្រូវបង្ហាញក្នុង Print Dialog ។ ចុច Share ដើម្បីរក្សាទុក ឬផ្ញើ។',
                  style: TextStyle(fontSize: 11, color: AppTheme.info),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Report card ───────────────────────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isLoading;
  final bool disabled;
  final VoidCallback onDownload;

  const _ReportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isLoading,
    required this.disabled,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isLoading ? color : AppTheme.border,
            width: isLoading ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: disabled ? null : onDownload,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: color))
                    : Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: disabled
                                  ? AppTheme.textGrey
                                  : AppTheme.textDark)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textGrey)),
                    ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: disabled
                      ? const Color(0xFFF0F0F0)
                      : color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: disabled
                          ? AppTheme.border
                          : color.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    isLoading
                        ? Icons.hourglass_empty_rounded
                        : Icons.download_outlined,
                    size: 14,
                    color: disabled ? AppTheme.textGrey : color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isLoading ? 'កំពុង...' : 'PDF',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: disabled ? AppTheme.textGrey : color),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED CARD WIDGETS (mirrors invoice_screen.dart)
// ══════════════════════════════════════════════════════════════════════════════

/// White rounded card
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _Card({required this.child, this.padding});
  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.border),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 4,
            offset: const Offset(0, 2))
      ],
    ),
    child: child,
  );
}

/// Thin divider
class _Div extends StatelessWidget {
  const _Div();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 16, color: AppTheme.border);
}

/// Detail row: "Label : Value"
class _DR extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _DR({required this.label, required this.value, this.bold = false});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(
      child: Text(label,
          style:
          const TextStyle(fontSize: 13, color: AppTheme.textGrey)),
    ),
    const Text(': ',
        style: TextStyle(fontSize: 13, color: AppTheme.textGrey)),
    Expanded(
      flex: 2,
      child: Text(value,
          style: TextStyle(
              fontSize: 13,
              fontWeight:
              bold ? FontWeight.bold : FontWeight.w500,
              color: AppTheme.textDark)),
    ),
  ]);
}

/// Summary row: right-aligned value
class _SR extends StatelessWidget {
  final String label, value;
  final bool valueBold;
  final Color? valueColor;
  const _SR(
      {required this.label,
        required this.value,
        this.valueBold = false,
        this.valueColor});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(
      child: Text(label,
          style:
          const TextStyle(fontSize: 13, color: AppTheme.textGrey)),
    ),
    Text(value,
        style: TextStyle(
            fontSize: 13,
            fontWeight:
            valueBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? AppTheme.textDark)),
  ]);
}

// Kept for compat with report modal
class _HeroChip extends StatelessWidget {
  final String text;
  const _HeroChip(this.text);
  @override
  Widget build(_) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text,
        style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w600)),
  );
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatBox(
      {required this.label,
        required this.value,
        required this.icon,
        required this.color});
  @override
  Widget build(_) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textGrey)),
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color)),
      ]),
    ]),
  );
}