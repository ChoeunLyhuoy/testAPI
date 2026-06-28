// lib/screens/sale_screen.dart
//
// UI — mirrors purchase_screen.dart layout exactly:
//  • AppBar: primary bg, white centered title, report + clear icons
//  • Header strip (primary bg): search pill + QR icon inside + square search btn
//  • Category chips: white bg, rounded pill, primary fill when selected
//  • Product grid: white bg, subtle pink border, "N opts" badge, qty badge, "Cost: $X"
//  • Bottom nav: grey circle cart FAB (left) + grey "Go to Cart" pill (right)
//  • Cart sheet: Khmer labels throughout, clean rows, discount chips,
//    subtotal/total, payment chips, full-width checkout button
//  • All visible text is Khmer where appropriate
//  • Zero logic changes — all providers / models untouched

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/payment_provider.dart';
import '../services/api_service.dart';
import '../utils/pos_report_helper.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../utils/image_helper.dart';
import '../widgets/common_widgets.dart';
import '../providers/promotion_provider.dart';
import '../providers/order_provider.dart';
import 'product_screen.dart' show scanBarcode;

// ─────────────────────────────────────────────────────────────────────────────
//  SALE SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key});
  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final _searchCtrl = TextEditingController();
  final _scanFocus  = FocusNode();
  final _scanBuffer = StringBuffer();
  DateTime? _lastKeyTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadAll();
      context.read<PaymentProvider>().load();
      _scanFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scanFocus.dispose();
    super.dispose();
  }

  // ── USB / Bluetooth scanner ──────────────────────────────────────────────
  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final now = DateTime.now();
    if (_lastKeyTime != null &&
        now.difference(_lastKeyTime!).inMilliseconds > 300) {
      _scanBuffer.clear();
    }
    _lastKeyTime = now;
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final code = _scanBuffer.toString().trim();
      _scanBuffer.clear();
      if (code.isNotEmpty) _handleScan(code);
    } else {
      final char = event.character;
      if (char != null) _scanBuffer.write(char);
    }
  }

  // ── Camera scanner ───────────────────────────────────────────────────────
  Future<void> _openScanner() async {
    final code = await scanBarcode(context);
    if (code != null && code.isNotEmpty && mounted) await _handleScan(code);
  }

  // ── Scan handler ─────────────────────────────────────────────────────────
  Future<void> _handleScan(String code) async {
    if (!mounted) return;
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    final res  = await ApiService.getOptionByCode(trimmed);
    if (!mounted) return;
    final data = ApiService.extractData(res);
    if (data == null) {
      showSnack(context, 'រកមិនឃើញ "$trimmed"', error: true);
      return;
    }
    final optionModel  = ProductOptionModel.fromMap(data);
    final productModel = ProductModel.fromOptionLookup(data);
    context.read<CartProvider>().addItem(productModel, optionModel);
    showSnack(context,
        '${optionModel.productCode} បានបន្ថែម ✓  (ស្តុក: ${optionModel.quantity})');
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _scanFocus,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        // ── AppBar ────────────────────────────────────────────────────────
        appBar: AppBar(
          backgroundColor: AppTheme.primary,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'ការលក់',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
              tooltip: 'របាយការណ៍ការលក់',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const _SaleReportModal())),
            ),
            Consumer<CartProvider>(
              builder: (_, cart, __) => cart.isEmpty
                  ? const SizedBox()
                  : IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.white, size: 22),
                tooltip: 'លុបទំនិញទាំងអស់',
                onPressed: () => _confirmClear(context),
              ),
            ),
          ],
        ),

        body: Consumer<ProductProvider>(
          builder: (_, prod, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Primary-bg search strip (same as purchase header) ──────
              _SaleHeader(
                searchCtrl: _searchCtrl,
                onSearchChanged: prod.setQuery,
                onScan: _openScanner,
              ),

              // ── Category chips — white bg ──────────────────────────────
              if (prod.categories.isNotEmpty)
                _CategoryChipRow(
                  categories: prod.categories,
                  selectedId: prod.selectedCategoryId,
                  onSelect: prod.setCategory,
                ),

              // thin divider
              Container(height: 1, color: const Color(0xFFEEEEEE)),

              // ── Product grid ───────────────────────────────────────────
              Expanded(
                child: prod.isLoading
                    ? const AppLoading()
                    : prod.filtered.isEmpty
                    ? const EmptyState(
                    message: 'រកមិនឃើញផលិតផល',
                    icon: Icons.inventory_2_outlined)
                    : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 110),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: prod.filtered.length,
                  itemBuilder: (_, i) =>
                      _ProductCard(product: prod.filtered[i]),
                ),
              ),
            ],
          ),
        ),

        // ── Bottom cart bar ──────────────────────────────────────────────
        bottomNavigationBar: Consumer<CartProvider>(
          builder: (_, cart, __) => cart.isEmpty
              ? const SizedBox(height: 0)
              : SafeArea(
            child: Container(
              color: const Color(0xFFEEEEEE),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(children: [
                // Grey circle cart FAB with qty badge
                GestureDetector(
                  onTap: () => _openCart(context, cart),
                  child: Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 52, height: 52,
                      decoration: const BoxDecoration(
                          color: Color(0xFF9E9E9E), shape: BoxShape.circle),
                      child: const Icon(Icons.shopping_cart_outlined,
                          color: Colors.white, size: 26),
                    ),
                    Positioned(
                      top: -4, right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: AppTheme.danger, shape: BoxShape.circle),
                        constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          '${cart.totalQuantity}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ]),
                ),
                const Spacer(),
                // Grey "Go to Cart" pill
                GestureDetector(
                  onTap: () => _openCart(context, cart),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 36, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCCCCC),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'Go to Cart',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF555555)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _openCart(BuildContext context, CartProvider cart) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<CartProvider>()),
          ChangeNotifierProvider.value(value: context.read<PaymentProvider>()),
          ChangeNotifierProvider.value(value: context.read<PromotionProvider>()),
        ],
        child: const _CartSheet(),
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('លុបទំនិញ?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
            'តើអ្នកចង់លុបទំនិញទាំងអស់ក្នុងកន្ត្រកចេញទេ?',
            style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('បោះបង់', style: TextStyle(fontSize: 14))),
          ElevatedButton(
            onPressed: () {
              context.read<CartProvider>().clear();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            child: const Text('លុប', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

// ── Sale header — mirrors _PurchaseHeader exactly (no supplier row) ───────────
class _SaleHeader extends StatelessWidget {
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onScan;
  const _SaleHeader({
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
      child: Row(children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'ស្វែងរកផលិតផល...',
                hintStyle: const TextStyle(color: AppTheme.textGrey, fontSize: 14),
                border: InputBorder.none,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primary),
                  tooltip: 'ស្កេនបាកូដ',
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
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.search, color: AppTheme.primary),
            tooltip: 'ស្វែងរក',
            onPressed: () => FocusScope.of(context).unfocus(),
          ),
        ),
      ]),
    );
  }
}

// ── Category chip row — mirrors _CategoryChipRow from purchase_screen ─────────
class _CategoryChipRow extends StatelessWidget {
  final List<CategoryModel> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelect;
  const _CategoryChipRow({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            _Chip(
              label: 'ទាំងអស់',
              selected: selectedId == null,
              onTap: () => onSelect(null),
            ),
            ...categories.map((c) {
              final catId = int.tryParse(c.id);
              return _Chip(
                label: c.name,
                selected: selectedId == catId,
                onTap: () => onSelect(catId),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.textDark),
        ),
      ),
    );
  }
}

// ── Product card — mirrors _ProductPickCard from purchase_screen ──────────────
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final cart      = context.watch<CartProvider>();
    final opt       = product.firstOption;
    final qtyInCart = opt != null
        ? cart.quantityOf('${product.id}_${opt.id}')
        : 0;

    return GestureDetector(
      onTap: () async {
        if (opt == null) {
          showSnack(context, 'មិនមានជម្រើសសម្រាប់ផលិតផលនេះ', error: true);
          return;
        }
        if (product.options.length == 1) {
          cart.addItem(product, opt);
        } else {
          final chosen = await Navigator.push<ProductOptionModel>(
            context,
            MaterialPageRoute(
                builder: (_) => _OptionPickerScreen(product: product)),
          );
          if (chosen != null && context.mounted) {
            context.read<CartProvider>().addItem(product, chosen);
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.primary.withOpacity(qtyInCart > 0 ? 0.6 : 0.30),
            width: qtyInCart > 0 ? 1.5 : 1.0,
          ),
        ),
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(9)),
                child: SizedBox.expand(
                  child: _SaleProdImg(url: product.imageUrl ?? opt?.imageUrl),
                ),
              ),
            ),
            // Name + cost
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'តម្លៃ:  ${opt != null ? Formatter.currency(opt.price) : '--'}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary),
                    ),
                  ]),
            ),
          ]),

          // qty badge — top right
          if (qtyInCart > 0)
            Positioned(
              top: 6, right: 6,
              child: Container(
                width: 22, height: 22,
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

          // opts badge — top left
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
              style: const TextStyle(fontSize: 13, color: AppTheme.textGrey)),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: product.options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final opt = product.options[i];
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
                        width: 58, height: 58,
                        child: _SaleProdImg(
                            url: opt.imageUrl ?? product.imageUrl),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opt.specLabel,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 3),
                          Text(opt.productCode,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textGrey)),
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.inventory_2_outlined,
                                size: 12, color: AppTheme.textGrey),
                            const SizedBox(width: 4),
                            Text('ស្តុក: ${opt.stock}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textGrey)),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('តម្លៃ: ${Formatter.currency(opt.price)}',
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

// ─────────────────────────────────────────────────────────────────────────────
//  CART SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _CartSheet extends StatefulWidget {
  const _CartSheet();
  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  PaymentModel? _selectedPayment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CartProvider>().syncPreview();
        context.read<PromotionProvider>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart     = context.watch<CartProvider>();
    final payments = context.watch<PaymentProvider>().payments;

    return Container(
      height: MediaQuery.of(context).size.height * .92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        // drag handle
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
        ),

        // ── Header ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            const Icon(Icons.shopping_cart_outlined,
                color: AppTheme.primary, size: 22),
            const SizedBox(width: 8),
            const Text('កន្ត្រក',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary)),
            const Spacer(),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                  color: AppTheme.primaryLt,
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${cart.totalQuantity} ទំនិញ',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary)),
            ),
          ]),
        ),
        Container(height: 1, color: const Color(0xFFEEEEEE)),

        // ── Cart item list ──────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            children:
            cart.items.map((item) => _CartItemRow(item: item)).toList(),
          ),
        ),

        // ── Summary + checkout ──────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [

                // Discount row
                Row(children: [
                  const Text('បញ្ចុះ:',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [0.0, 1.0, 2.0, 5.0, 10.0].map((pct) {
                          final base = cart.hasServerPricing
                              ? cart.effectiveSubtotal
                              : cart.subtotal;
                          final amount = base * pct / 100;
                          final sel = pct == 0
                              ? cart.discount == 0
                              : (cart.discount - amount).abs() < 0.005;
                          return GestureDetector(
                            onTap: () => cart.setDiscount(amount),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppTheme.primary
                                    : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: sel
                                        ? AppTheme.primary
                                        : const Color(0xFFDDDDDD)),
                              ),
                              child: Text(
                                pct == 0 ? 'គ្មាន' : '${pct.toInt()}%',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: sel
                                        ? Colors.white
                                        : const Color(0xFF666666)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),

                // Subtotal
                _SummaryRow(
                  label: 'សរុប',
                  value: Formatter.currency(cart.hasServerPricing
                      ? cart.effectiveSubtotal
                      : cart.subtotal),
                  trailing: cart.previewSyncing
                      ? const SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.6, color: AppTheme.primary))
                      : null,
                ),

                if (cart.hasAnyPromotion) ...[
                  const SizedBox(height: 4),
                  Row(children: const [
                    Icon(Icons.check_circle, size: 12, color: AppTheme.success),
                    SizedBox(width: 4),
                    Text('ការផ្តល់ជូនត្រូវបានអនុវត្ត',
                        style: TextStyle(fontSize: 11, color: AppTheme.success)),
                  ]),
                ],
                if (cart.discount > 0) ...[
                  const SizedBox(height: 4),
                  _SummaryRow(
                    label: 'បញ្ចុះតម្លៃ',
                    value: '-${Formatter.currency(cart.discountAmount)}',
                    valueColor: AppTheme.success,
                  ),
                ],

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                ),

                // Grand total
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('សរុបសុទ្ធ',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark)),
                  Text(
                    Formatter.currency(cart.hasServerPricing
                        ? cart.effectiveTotal
                        : cart.total),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary),
                  ),
                ]),
                const SizedBox(height: 14),

                // Payment methods
                if (payments.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppTheme.warningLt,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Row(children: [
                      Icon(Icons.warning_amber_outlined,
                          size: 16, color: AppTheme.warning),
                      SizedBox(width: 8),
                      Text('គ្មានវិធីទូទាត់',
                          style: TextStyle(fontSize: 13, color: AppTheme.warning)),
                    ]),
                  )
                else ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('វិធីទូទាត់',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textGrey)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: payments.map((p) {
                      final sel = _selectedPayment?.id == p.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedPayment = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? AppTheme.primaryLt : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                sel ? AppTheme.primary : AppTheme.border,
                                width: sel ? 2 : 1),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            NetImage(
                                url: p.imageUrl,
                                size: 22,
                                radius: BorderRadius.circular(4),
                                fallback: Icons.payment),
                            const SizedBox(width: 6),
                            Text(p.name,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: sel
                                        ? AppTheme.primary
                                        : AppTheme.textDark)),
                            if (sel) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.check_circle,
                                  size: 14, color: AppTheme.primary),
                            ],
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 14),

                // Checkout button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _selectedPayment == null
                        ? null
                        : () => _checkout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedPayment == null
                          ? const Color(0xFFDDDDDD)
                          : AppTheme.primary,
                      foregroundColor: _selectedPayment == null
                          ? const Color(0xFF888888)
                          : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      cart.syncing
                          ? 'កំពុងដំណើរការ...'
                          : _selectedPayment == null
                          ? 'ជ្រើសរើសវិធីទូទាត់'
                          : 'ទូទាត់  ${Formatter.currency(cart.hasServerPricing ? cart.effectiveTotal : cart.total)}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _checkout(BuildContext context) async {
    if (_selectedPayment == null) return;
    final paymentId = int.tryParse(_selectedPayment!.id);
    if (paymentId == null) {
      showSnack(context,
          'វិធីទូទាត់មិនត្រឹមត្រូវ (id: "${_selectedPayment!.id}")',
          error: true);
      return;
    }
    final order =
    await context.read<CartProvider>().checkout(paymentId: paymentId);
    if (!mounted) return;
    if (order != null) {
      Navigator.pop(context); // Pops the cart/checkout bottom sheet
      showSnack(context, 'បញ្ជាទិញបានជោគជ័យ 🎉');
      
      // Show loading spinner while fetching the full order details (with items)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
      
      try {
        final orderId = int.tryParse(order.id);
        OrderModel fullOrder = order;
        if (orderId != null) {
          fullOrder = await context.read<OrderProvider>().fetchById(orderId);
        }
        if (!mounted) return;
        Navigator.pop(context); // Pop loading dialog
        _showReceiptDialog(context, fullOrder);
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Pop loading dialog
        _showReceiptDialog(context, order); // Fallback to partial order
      }
    } else {
      showSnack(context, 'ការទូទាត់បានបរាជ័យ — សូមព្យាយាមម្តងទៀត',
          error: true);
    }
  }

  void _showReceiptDialog(BuildContext context, OrderModel order) {
    final discount = order.discountTotal;
    final khrTotal = (order.totalAmount * 4100.0).round();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(20),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success Header
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: AppTheme.successLt,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 36),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ការទូទាត់ជោគជ័យ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'វិក្កយបត្រ #: ${order.transactionRef}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
                  ),
                  const SizedBox(height: 16),

                  // Ticket Number Card
                  if (order.id.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'លេខរង់ចាំ / Ticket Number',
                            style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.id,
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Details Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Items List
                        if (order.items.isNotEmpty) ...[
                          const Text(
                            'ទំនិញ / Items',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                          const SizedBox(height: 6),
                          ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.productName,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  'x${item.quantity}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  Formatter.currency(item.subTotal),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                ),
                              ],
                            ),
                          )),
                          const Divider(height: 16, thickness: 0.5),
                        ],

                        // Summary Info
                        _rowInfo('សរុបរង:', Formatter.currency(order.subtotalAmount)),
                        if (discount > 0)
                          _rowInfo('បញ្ចុះតម្លៃ:', '-${Formatter.currency(discount)}', valueColor: AppTheme.success),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('សរុប (USD):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            Text(Formatter.currency(order.totalAmount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('សរុប (KHR):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textGrey)),
                            Text('៛ ${_fmtKhr(khrTotal)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          ],
                        ),
                        if (order.paymentName != null) ...[
                          const Divider(height: 16, thickness: 0.5),
                          _rowInfo('ទូទាត់តាម:', order.paymentName!, valueBold: true),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  ElevatedButton.icon(
                    onPressed: () {
                      printSaleInvoice(
                        context: context,
                        mode: 'compact',
                        order: order,
                        storeName: 'Smart Mart Phnom Penh',
                      );
                    },
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('ព្រីនវិក្កយបត្រ (Receipt)', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      printSaleInvoice(
                        context: context,
                        mode: 'a4',
                        order: order,
                        storeName: 'Smart Mart Phnom Penh',
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('ព្រីនវិក្កយបត្រ A4', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('លក់បន្ត / New Sale', style: TextStyle(fontSize: 13, color: AppTheme.textGrey, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _rowInfo(String label, String value, {bool valueBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: valueBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtKhr(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CART ITEM ROW
// ─────────────────────────────────────────────────────────────────────────────
class _CartItemRow extends StatelessWidget {
  final CartItemModel item;
  const _CartItemRow({required this.item});

  Future<void> _editQty(BuildContext context, CartProvider cart) async {
    final ctrl = TextEditingController(text: '${item.quantity}');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('កែចំនួន',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
              child:
              const Text('បោះបង់', style: TextStyle(fontSize: 14))),
          ElevatedButton(
            style:
            ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('យល់ព្រម',
                style: TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) {
      cart.setQuantity(item.key, result);
      cart.syncPreview();
    }
  }

  Future<void> _pickPromotion(BuildContext context, CartProvider cart) async {
    final promoProv = context.read<PromotionProvider>();
    if (promoProv.promotions.isEmpty) await promoProv.load();
    if (!context.mounted) return;

    final applicable = promoProv.promotions.where((promo) {
      final match = promo.products
          .where((p) => p.productCode == item.option.productCode);
      return match.isNotEmpty && match.first.quantity > 0 && promo.isActive;
    }).toList();

    final selected = await showModalBottomSheet<_PromoSelection?>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SheetHandle(title: 'ការផ្តល់ជូន'),
            ListTile(
              leading: const Icon(Icons.cancel_outlined,
                  color: AppTheme.textGrey),
              title: const Text('គ្មានការផ្តល់ជូន',
                  style: TextStyle(fontSize: 14)),
              onTap: () =>
                  Navigator.pop(context, _PromoSelection.remove()),
            ),
            const Divider(height: 1),
            if (applicable.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: EmptyState(
                    message: 'មិនមានការផ្តល់ជូនសម្រាប់ option នេះ',
                    icon: Icons.local_offer_outlined),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight:
                    MediaQuery.of(context).size.height * 0.4),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: applicable.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final promo = applicable[i];
                    final pp = promo.products.firstWhere(
                            (p) => p.productCode == item.option.productCode);
                    final isCurrent =
                        item.promotionId == int.tryParse(promo.id);
                    return ListTile(
                      leading: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                            color: AppTheme.primaryLt,
                            borderRadius: BorderRadius.circular(8)),
                        child: Center(
                          child: Text(promo.discountLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary)),
                        ),
                      ),
                      title: Row(children: [
                        Expanded(
                          child: Text(promo.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                        ),
                        if (isCurrent)
                          const Icon(Icons.check_circle,
                              color: AppTheme.success, size: 16),
                      ]),
                      subtitle: Row(children: [
                        if (promo.description?.isNotEmpty == true)
                          Expanded(
                            child: Text(promo.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12)),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppTheme.successLt,
                              borderRadius: BorderRadius.circular(4)),
                          child: Text('ចំនួន: ${pp.quantity}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ]),
                      trailing:
                      const Icon(Icons.chevron_right, size: 18),
                      onTap: () => Navigator.pop(
                          context, _PromoSelection.pick(promo)),
                    );
                  },
                ),
              ),
          ]),
        ),
      ),
    );

    if (selected == null) return;
    if (selected.remove) {
      cart.setPromotion(item.key, null);
    } else if (selected.promo != null) {
      cart.setPromotion(item.key, int.tryParse(selected.promo!.id),
          promotionName: selected.promo!.name);
    }
    cart.syncPreview();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 54, height: 54,
              child: _SaleProdImg(
                  url: item.option.imageUrl ?? item.product.imageUrl),
            ),
          ),
          const SizedBox(width: 10),
          // Name + code + unit price
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark)),
                  const SizedBox(height: 2),
                  Text(
                    '${item.option.productCode}  ·  ${Formatter.currency(item.effectiveUnitPrice)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textGrey),
                  ),
                ]),
          ),
          const SizedBox(width: 8),
          // − qty + stepper
          Row(mainAxisSize: MainAxisSize.min, children: [
            _QBtn(
                icon: Icons.remove,
                onTap: () {
                  cart.decrement(item.key);
                  cart.syncPreview();
                }),
            GestureDetector(
              onTap: () => _editQty(context, cart),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('${item.quantity}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dotted)),
              ),
            ),
            _QBtn(
                icon: Icons.add,
                onTap: () {
                  cart.increment(item.key);
                  cart.syncPreview();
                }),
          ]),
          const SizedBox(width: 10),
          // Line subtotal
          Text(
            Formatter.currency(item.effectiveSubtotal),
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.textDark),
          ),
        ]),

        // Delete + promotion row
        const SizedBox(height: 8),
        Row(children: [
          // Promotion tag
          Expanded(
            child: GestureDetector(
              onTap: () => _pickPromotion(context, cart),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: item.hasPromotion
                      ? AppTheme.successLt
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: item.hasPromotion
                          ? AppTheme.success
                          : const Color(0xFFDDDDDD)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    item.hasPromotion
                        ? Icons.local_offer
                        : Icons.local_offer_outlined,
                    size: 12,
                    color: item.hasPromotion
                        ? AppTheme.success
                        : AppTheme.textGrey,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      item.hasPromotion
                          ? (item.promotionName ??
                          'ការផ្តល់ជូនត្រូវបានអនុវត្ត')
                          : 'អនុវត្តការផ្តល់ជូន',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: item.hasPromotion
                              ? AppTheme.success
                              : AppTheme.textGrey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Delete button
          GestureDetector(
            onTap: () {
              cart.remove(item.key);
              cart.syncPreview();
            },
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.dangerLt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline,
                  size: 16, color: AppTheme.danger),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SMALL HELPERS
// ─────────────────────────────────────────────────────────────────────────────
class _QBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: AppTheme.primaryLt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: AppTheme.primary),
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;
  const _SummaryRow(
      {required this.label,
        required this.value,
        this.valueColor,
        this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14, color: AppTheme.textGrey)),
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppTheme.textDark)),
        ]),
      ],
    ),
  );
}

/// Product image with placeholder — same as purchase_screen._PurchaseProdImg
class _SaleProdImg extends StatelessWidget {
  final String? url;
  const _SaleProdImg({this.url});

  static const _ph = ColoredBox(
    color: Color(0xFFF7F7F7),
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.image_not_supported_outlined,
            color: Color(0xFFBBBBBB), size: 28),
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

class _PromoSelection {
  final bool remove;
  final PromotionModel? promo;
  const _PromoSelection._({required this.remove, this.promo});
  factory _PromoSelection.remove() => const _PromoSelection._(remove: true);
  factory _PromoSelection.pick(PromotionModel p) =>
      _PromoSelection._(remove: false, promo: p);
}

// ─────────────────────────────────────────────────────────────────────────────
//  SALE REPORT MODAL
// ─────────────────────────────────────────────────────────────────────────────
class _SaleReportModal extends StatefulWidget {
  const _SaleReportModal({super.key});
  @override
  State<_SaleReportModal> createState() => _SaleReportModalState();
}

class _SaleReportModalState extends State<_SaleReportModal> {
  DateTime _from =
  DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to   = DateTime.now();

  Map<String, dynamic>? _summary;
  List<dynamic> _daily = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _printRecent(BuildContext ctx, String mode) async {
    final orders = context.read<OrderProvider>().orders;
    if (orders.isEmpty) {
      showSnack(ctx, 'មិនមានការបញ្ជាទិញ', error: true);
      return;
    }
    await printSaleInvoice(
      context: ctx,
      mode: mode,
      order: orders.first,
      storeName: 'Smart Mart Phnom Penh',
    );
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final results = await Future.wait([
      ApiService.getSalesReport(from: _fmt(_from), to: _fmt(_to)),
      ApiService.getSalesDaily(from: _fmt(_from),  to: _fmt(_to)),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _summary = ApiService.extractData(results[0]);
      _daily   = ApiService.extractList(results[1]);
      if (_daily.isEmpty && results[0]?['error'] != null)
        _error = results[0]!['error']!.toString();
    });
  }

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
    if (picked != null) {
      setState(() { _from = picked.start; _to = picked.end; });
      _load();
    }
  }

  double get _totalRevenue =>
      (_summary?['totalRevenue'] as num?)?.toDouble() ??
          _daily.fold(
              0.0, (s, r) => s + ((r['totalRevenue'] as num?)?.toDouble() ?? 0));

  int get _totalOrders =>
      (_summary?['totalOrders'] as num?)?.toInt() ??
          _daily.fold(
              0, (s, r) => s + ((r['totalOrders'] as num?)?.toInt() ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('របាយការណ៍ការលក់'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Date range picker card
            GestureDetector(
              onTap: _pickRange,
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
            const SizedBox(height: 14),

            if (_loading)
              const SizedBox(
                height: 120,
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primary, strokeWidth: 2),
                ),
              )
            else ...[
              // Revenue hero
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryDk],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ចំណូលសរុប',
                          style: TextStyle(
                              fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 6),
                      Text(Formatter.currency(_totalRevenue),
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(height: 10),
                      Text('$_totalOrders ការបញ្ជាទិញ',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white70)),
                    ]),
              ),
              const SizedBox(height: 14),

              // Print card
              _SalePrintCard(
                onPrintA4: () => _printRecent(context, 'a4'),
                onPrintCompact: () => _printRecent(context, 'compact'),
              ),
              const SizedBox(height: 14),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: AppTheme.dangerLt,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppTheme.danger, fontSize: 13)),
                )
              else if (_daily.isEmpty)
                const SizedBox(
                  height: 80,
                  child: Center(
                    child: Text('មិនមានទិន្នន័យ',
                        style: TextStyle(
                            color: AppTheme.textGrey, fontSize: 14)),
                  ),
                )
              else ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('ប្រចាំថ្ងៃ',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark)),
                  ),
                  ..._daily.map((d) {
                    final date =
                        d['date']?.toString() ?? d['period']?.toString() ?? '—';
                    final orders =
                        (d['totalOrders'] as num?)?.toInt() ?? 0;
                    final revenue =
                        (d['totalRevenue'] as num?)?.toDouble() ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Text(date,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDark)),
                        ),
                        Text('$orders ការបញ្ជា',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textGrey)),
                        const SizedBox(width: 12),
                        Text(Formatter.currency(revenue),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary)),
                      ]),
                    );
                  }).toList(),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SalePrintCard extends StatelessWidget {
  final VoidCallback onPrintA4;
  final VoidCallback onPrintCompact;
  const _SalePrintCard(
      {required this.onPrintA4, required this.onPrintCompact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.print_outlined, color: AppTheme.primary, size: 18),
          SizedBox(width: 8),
          Text('ព្រីន / ទាញយកវិក្កយបត្រ',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark)),
        ]),
        const SizedBox(height: 4),
        const Text(
          'ចុចខាងក្រោមដើម្បីព្រីនវិក្កយបត្រការលក់ចុងក្រោយ',
          style: TextStyle(fontSize: 12, color: AppTheme.textGrey),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.print_outlined, size: 16),
              label: const Text('A4 Invoice',
                  style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onPrintA4,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.download_outlined,
                  size: 16, color: AppTheme.primary),
              label: const Text('Compact',
                  style: TextStyle(fontSize: 13, color: AppTheme.primary)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onPrintCompact,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: AppTheme.infoLt,
              borderRadius: BorderRadius.circular(8)),
          child: const Row(children: [
            Icon(Icons.info_outline, size: 12, color: AppTheme.info),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'ដើម្បីព្រីនវិក្កយបត្រជាក់លាក់ ចូលទំព័រ "វិក្កយបត្រ" ហើយចុចលើការបញ្ជាទិញ',
                style: TextStyle(fontSize: 11, color: AppTheme.info),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}