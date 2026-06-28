// lib/screens/customer_screen.dart
//
// Changes in this revision:
//
//  1. Delete confirmation replaced with a proper bottom sheet showing the
//     customer's avatar + name — much harder to accidentally confirm, and
//     visually consistent with the rest of the app's sheet UI.
//
//  2. Customer detail bottom sheet — tap any row to see full details plus
//     the list of promotions that are currently active & applicable to
//     any product. Cashiers can immediately see which promotions are
//     available when a customer is selected at the POS.
//
//  3. Assign Promotion to Customer — from the detail sheet a cashier can
//     open a promotion picker and note which promotion was selected for
//     this customer's session (stored in CartProvider for use during checkout).
//
//  4. _CustRow swipe-to-delete support in addition to the icon button —
//     swipe left reveals a red delete zone, keeping the row UI clean.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/customer_provider.dart';
import '../providers/promotion_provider.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/common_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  MAIN LIST SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});
  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().load();
      context.read<PromotionProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('អតិថិជន'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Add Customer',
            onPressed: () => _openForm(context),
          ),
        ],
      ),
      body: Consumer<CustomerProvider>(
        builder: (_, prov, __) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: AppSearchBar(
              hint: 'ស្វែងរកអតិថិជន…',
              controller: _searchCtrl,
              onChanged: (v) => prov.load(query: v),
              onClear: () {
                _searchCtrl.clear();
                prov.load();
              },
            ),
          ),
          if (!prov.isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'អតិថិជន ${prov.customers.length} នាក់',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textGrey),
                ),
              ),
            ),
          Expanded(
            child: prov.isLoading
                ? const AppLoading()
                : prov.customers.isEmpty
                    ? EmptyState(
                        message: 'រកមិនឃើញអតិថិជន',
                        icon: Icons.people_outlined,
                        action: 'បន្ថែមអតិថិជន',
                        onAction: () => _openForm(context),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                        itemCount: prov.customers.length,
                        itemBuilder: (_, i) => _CustRow(
                          key: ValueKey(prov.customers[i].id),
                          cust: prov.customers[i],
                          onEdit: () => _openForm(context, prov.customers[i]),
                          onDetail: () =>
                              _openDetail(context, prov.customers[i]),
                        ),
                      ),
          ),
        ]),
      ),
    );
  }

  void _openForm(BuildContext context, [CustomerModel? cust]) {
    final custProv = context.read<CustomerProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChangeNotifierProvider.value(
          value: custProv,
          child: _CustomerFormScreen(cust: cust),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, CustomerModel cust) {
    final promoProv = context.read<PromotionProvider>();
    final cartProv  = context.read<CartProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: promoProv),
          ChangeNotifierProvider.value(value: cartProv),
        ],
        child: _CustomerDetailSheet(cust: cust),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CUSTOMER ROW  (swipe-to-delete + icon buttons)
// ══════════════════════════════════════════════════════════════════════════════
class _CustRow extends StatefulWidget {
  final CustomerModel cust;
  final VoidCallback  onEdit;
  final VoidCallback  onDetail;
  const _CustRow({
    super.key,
    required this.cust,
    required this.onEdit,
    required this.onDetail,
  });

  @override
  State<_CustRow> createState() => _CustRowState();
}

class _CustRowState extends State<_CustRow> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final cust = widget.cust;
    return Dismissible(
      key: ValueKey('dismiss_${cust.id}'),
      direction: DismissDirection.endToStart,
      // Only confirm after the swipe — the actual delete fires in confirmationCallback
      confirmDismiss: (_) => _confirmDelete(context),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 22),
            SizedBox(height: 3),
            Text('លុប',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: ListTile(
          onTap: widget.onDetail,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primaryLt,
            child: Text(
              cust.initials,
              style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
          title: Text(
            cust.fullName.isNotEmpty ? cust.fullName : cust.userName,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textDark),
          ),
          subtitle: Text(
            [cust.phone, cust.email].where((s) => s.isNotEmpty).join('  ·  '),
            style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
          ),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            // Edit
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined,
                  color: AppTheme.primary, size: 18),
              onPressed: widget.onEdit,
            ),
            // Delete with spinner guard
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: _deleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.danger))
                  : const Icon(Icons.delete_outline,
                      color: AppTheme.danger, size: 18),
              onPressed: _deleting ? null : () => _deleteViaButton(context),
            ),
          ]),
        ),
      ),
    );
  }

  // Called by swipe — returns true to let Dismissible remove the widget
  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await _showDeleteSheet(context, widget.cust);
    if (confirmed && context.mounted) {
      setState(() => _deleting = true);
      final ok =
          await context.read<CustomerProvider>().delete(widget.cust.id);
      if (context.mounted) {
        setState(() => _deleting = false);
        showSnack(context, ok ? 'លុបបានជោគជ័យ' : 'មានបញ្ហា', error: !ok);
      }
      return ok;
    }
    return false;
  }

  // Called by the delete icon button
  Future<void> _deleteViaButton(BuildContext context) async {
    final confirmed = await _showDeleteSheet(context, widget.cust);
    if (!confirmed || !context.mounted) return;
    setState(() => _deleting = true);
    final ok = await context.read<CustomerProvider>().delete(widget.cust.id);
    if (!context.mounted) return;
    setState(() => _deleting = false);
    showSnack(context, ok ? 'លុបបានជោគជ័យ' : 'មានបញ្ហា', error: !ok);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  DELETE CONFIRMATION BOTTOM SHEET
//  Shows the customer's avatar + name so the cashier clearly sees WHO they're
//  about to delete, preventing accidental mass-deletes.
// ══════════════════════════════════════════════════════════════════════════════
Future<bool> _showDeleteSheet(
    BuildContext context, CustomerModel cust) async {
  return await showModalBottomSheet<bool>(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // Warning icon
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.dangerLt,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_forever_outlined,
                    color: AppTheme.danger, size: 28),
              ),
              const SizedBox(height: 14),

              const Text('លុបអតិថិជន?',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark)),
              const SizedBox(height: 10),

              // Customer identity card — clearly shows WHO is being deleted
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.dangerLt,
                    child: Text(cust.initials,
                        style: const TextStyle(
                            color: AppTheme.danger,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cust.fullName.isNotEmpty
                                ? cust.fullName
                                : cust.userName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          if (cust.phone.isNotEmpty)
                            Text(cust.phone,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textGrey)),
                          if (cust.email.isNotEmpty)
                            Text(cust.email,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textGrey)),
                        ]),
                  ),
                ]),
              ),
              const SizedBox(height: 10),

              Text(
                'សកម្មភាពនេះមិនអាចត្រឡប់វិញបានទេ',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('បោះបង់'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('លុប',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ) ??
      false;
}

// ══════════════════════════════════════════════════════════════════════════════
//  CUSTOMER DETAIL + PROMOTION SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _CustomerDetailSheet extends StatefulWidget {
  final CustomerModel cust;
  const _CustomerDetailSheet({required this.cust});
  @override
  State<_CustomerDetailSheet> createState() => _CustomerDetailSheetState();
}

class _CustomerDetailSheetState extends State<_CustomerDetailSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cust = widget.cust;
    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(children: [
        // ── Handle + header ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.primaryLt,
                child: Text(cust.initials,
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cust.fullName.isNotEmpty
                            ? cust.fullName
                            : cust.userName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.textDark),
                      ),
                      if (cust.phone.isNotEmpty)
                        Text(cust.phone,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textGrey)),
                    ]),
              ),
            ]),
            const SizedBox(height: 12),
          ]),
        ),

        // ── Tabs ──────────────────────────────────────────────────────
        TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textGrey,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.person_outline, size: 18), text: 'ព័ត៌មាន'),
            Tab(icon: Icon(Icons.local_offer_outlined, size: 18), text: 'ការផ្តល់ជូន'),
          ],
        ),

        // ── Tab views ─────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _InfoTab(cust: cust),
              _PromotionsTab(cust: cust),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Info Tab ──────────────────────────────────────────────────────────────────
class _InfoTab extends StatelessWidget {
  final CustomerModel cust;
  const _InfoTab({required this.cust});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _InfoRow(Icons.person_outline,      'ឈ្មោះ',     cust.fullName.isNotEmpty ? cust.fullName : '—'),
        _InfoRow(Icons.alternate_email,     'Username', cust.userName.isNotEmpty ? cust.userName : '—'),
        _InfoRow(Icons.phone_outlined,      'ទូរស័ព្ទ',  cust.phone.isNotEmpty ? cust.phone : '—'),
        _InfoRow(Icons.email_outlined,      'Email',    cust.email.isNotEmpty ? cust.email : '—'),
        _InfoRow(Icons.location_on_outlined,'អាសយដ្ឋាន',cust.address?.isNotEmpty == true ? cust.address! : '—'),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryLt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textGrey)),
              const SizedBox(height: 1),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark)),
            ]),
          ),
        ]),
      );
}

// ── Promotions Tab ────────────────────────────────────────────────────────────
// Shows all active promotions. Each card shows the discount, linked products,
// and a button to apply this promotion to the current cart session.
class _PromotionsTab extends StatelessWidget {
  final CustomerModel cust;
  const _PromotionsTab({required this.cust});

  @override
  Widget build(BuildContext context) {
    return Consumer<PromotionProvider>(
      builder: (_, promoProv, __) {
        if (promoProv.isLoading) return const AppLoading();

        final active = promoProv.promotions
            .where((p) => p.isActive && p.products.isNotEmpty)
            .toList();

        if (active.isEmpty) {
          return const EmptyState(
            message: 'មិនមានការផ្តល់ជូនសកម្ម',
            icon: Icons.local_offer_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: active.length,
          itemBuilder: (_, i) => _PromoCard(promo: active[i]),
        );
      },
    );
  }
}

class _PromoCard extends StatelessWidget {
  final PromotionModel promo;
  const _PromoCard({required this.promo});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    // Check if any cart item already uses this promotion
    final appliedInCart = cart.items.any((i) =>
        i.promotionId == int.tryParse(promo.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: appliedInCart ? AppTheme.successLt : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: appliedInCart
                ? AppTheme.success
                : AppTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            // Discount badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(promo.discountLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(promo.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.textDark)),
                if (promo.description?.isNotEmpty == true)
                  Text(promo.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textGrey)),
              ]),
            ),
            if (appliedInCart)
              const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
          ]),

          // Date range
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.calendar_today_outlined,
                size: 12, color: AppTheme.textGrey),
            const SizedBox(width: 4),
            Text(
              '${_fmtDate(promo.startDate)} → ${_fmtDate(promo.endDate)}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
            ),
          ]),

          // Applicable products
          if (promo.products.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('ផលិតផល',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textGrey)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: promo.products.map((pp) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(pp.productCode,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary)),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${pp.quantity}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  )).toList(),
            ),
          ],

          // Apply button
          const SizedBox(height: 12),
          _ApplyPromotionButton(promo: promo, appliedInCart: appliedInCart),
        ]),
      ),
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

// ── Apply Promotion Button ────────────────────────────────────────────────────
// Applies the promotion to every matching cart item (by productCode).
// If no cart item matches any product in the promotion, shows an info snack.
class _ApplyPromotionButton extends StatelessWidget {
  final PromotionModel promo;
  final bool appliedInCart;
  const _ApplyPromotionButton({
    required this.promo,
    required this.appliedInCart,
  });

  @override
  Widget build(BuildContext context) {
    if (appliedInCart) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.remove_circle_outline, size: 16),
        label: const Text('ដកការផ្តល់ជូន'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.danger,
          side: const BorderSide(color: AppTheme.danger),
          padding: const EdgeInsets.symmetric(vertical: 10),
          minimumSize: const Size(double.infinity, 40),
        ),
        onPressed: () => _remove(context),
      );
    }

    return ElevatedButton.icon(
      icon: const Icon(Icons.local_offer, size: 16),
      label: const Text('អនុវត្តការផ្តល់ជូននេះ'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10),
        minimumSize: const Size(double.infinity, 40),
      ),
      onPressed: () => _apply(context),
    );
  }

  void _apply(BuildContext context) {
    final cart       = context.read<CartProvider>();
    final promoId    = int.tryParse(promo.id);
    final promoCodes = promo.products.map((p) => p.productCode).toSet();

    // Find all cart items whose productCode is covered by this promotion
    final matches = cart.items
        .where((i) => promoCodes.contains(i.option.productCode))
        .toList();

    if (matches.isEmpty) {
      showSnack(
        context,
        'មិនមានផលិតផលនៅក្នុងកន្ត្រកដែលត្រូវនឹងការផ្តល់ជូននេះ',
        error: true,
      );
      return;
    }

    // Apply the promotion to every matching cart item
    for (final item in matches) {
      cart.setPromotion(item.key, promoId, promotionName: promo.name);
    }
    cart.syncPreview();

    showSnack(context,
        'ការផ្តល់ជូន "${promo.name}" ត្រូវបានអនុវត្ត (${matches.length} ធាតុ)');
  }

  void _remove(BuildContext context) {
    final cart       = context.read<CartProvider>();
    final promoId    = int.tryParse(promo.id);

    // Remove promotion from all cart items that have it
    final matches = cart.items
        .where((i) => i.promotionId == promoId)
        .toList();

    for (final item in matches) {
      cart.setPromotion(item.key, null);
    }
    cart.syncPreview();

    showSnack(context, 'ដកការផ្តល់ជូន "${promo.name}" ចេញ');
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ADD / EDIT CUSTOMER — full screen form
// ══════════════════════════════════════════════════════════════════════════════
class _CustomerFormScreen extends StatefulWidget {
  final CustomerModel? cust;
  const _CustomerFormScreen({this.cust});

  @override
  State<_CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<_CustomerFormScreen> {
  late final TextEditingController _firstNameCtrl =
      TextEditingController(text: widget.cust?.firstName ?? '');
  late final TextEditingController _lastNameCtrl =
      TextEditingController(text: widget.cust?.lastName ?? '');
  late final TextEditingController _userNameCtrl =
      TextEditingController(text: widget.cust?.userName ?? '');
  late final TextEditingController _phoneCtrl =
      TextEditingController(text: widget.cust?.phone ?? '');
  late final TextEditingController _emailCtrl =
      TextEditingController(text: widget.cust?.email ?? '');
  late final TextEditingController _addressCtrl =
      TextEditingController(text: widget.cust?.address ?? '');
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _saving      = false;
  bool _obscurePass = true;

  bool get _isEdit => widget.cust != null;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _userNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_firstNameCtrl.text.trim().isEmpty) {
      showSnack(context, 'សូមបំពេញឈ្មោះដំបូង', error: true);
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      showSnack(context, 'សូមបំពេញលេខទូរស័ព្ទ', error: true);
      return;
    }
    if (!_isEdit && _passwordCtrl.text.trim().isEmpty) {
      showSnack(context, 'សូមបំពេញពាក្យសម្ងាត់', error: true);
      return;
    }

    setState(() => _saving = true);

    final fields = <String, dynamic>{
      'firstName':   _firstNameCtrl.text.trim(),
      'lastName':    _lastNameCtrl.text.trim(),
      'userName':    _userNameCtrl.text.trim(),
      'phoneNumber': _phoneCtrl.text.trim(),
      if (_emailCtrl.text.trim().isNotEmpty)
        'email':   _emailCtrl.text.trim(),
      if (_addressCtrl.text.trim().isNotEmpty)
        'address': _addressCtrl.text.trim(),
      if (_passwordCtrl.text.trim().isNotEmpty)
        'password': _passwordCtrl.text.trim(),
    };

    final prov = context.read<CustomerProvider>();
    final ok   = _isEdit
        ? await prov.update(widget.cust!.id, fields)
        : await prov.create(fields);

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context);
      showSnack(context, 'រក្សាទុកបានជោគជ័យ');
    } else {
      showSnack(context, 'មានបញ្ហា — សូមព្យាយាមម្ដងទៀត', error: true);
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
        title: Text(_isEdit ? 'កែប្រែអតិថិជន' : 'បន្ថែមអតិថិជន'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20,
            MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar initials display
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppTheme.primaryLt,
                  child: ValueListenableBuilder(
                    valueListenable: _firstNameCtrl,
                    builder: (_, __, ___) {
                      final initials =
                          (_firstNameCtrl.text.isNotEmpty
                                  ? _firstNameCtrl.text[0]
                                  : '') +
                              (_lastNameCtrl.text.isNotEmpty
                                  ? _lastNameCtrl.text[0]
                                  : '');
                      return Text(
                        initials.toUpperCase().isNotEmpty
                            ? initials.toUpperCase()
                            : 'C',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 28),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Name ────────────────────────────────────────────────
              _SectionLabel('ព័ត៌មានផ្ទាល់ខ្លួន', Icons.person_outline),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: AppField(
                    controller: _firstNameCtrl,
                    label: 'ឈ្មោះដំបូង',
                    icon: Icons.person_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppField(
                    controller: _lastNameCtrl,
                    label: 'ឈ្មោះចុងក្រោយ',
                    icon: Icons.person_outline,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              AppField(
                controller: _userNameCtrl,
                label: 'Username',
                icon: Icons.alternate_email,
              ),
              const SizedBox(height: 18),

              // ── Contact ─────────────────────────────────────────────
              _SectionLabel('ព័ត៌មានទំនាក់ទំនង', Icons.contact_phone_outlined),
              const SizedBox(height: 12),
              AppField(
                controller: _phoneCtrl,
                label: 'ទូរស័ព្ទ',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              AppField(
                controller: _emailCtrl,
                label: 'Email (ស្រេចចិត្ត)',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              AppField(
                controller: _addressCtrl,
                label: 'អាសយដ្ឋាន (ស្រេចចិត្ត)',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 18),

              // ── Security ────────────────────────────────────────────
              _SectionLabel(
                  _isEdit
                      ? 'ផ្លាស់ប្ដូរពាក្យសម្ងាត់ (ស្រេចចិត្ត)'
                      : 'ពាក្យសម្ងាត់',
                  Icons.lock_outline),
              const SizedBox(height: 12),
              AppField(
                controller: _passwordCtrl,
                label: _isEdit ? 'ពាក្យសម្ងាត់ថ្មី' : 'ពាក្យសម្ងាត់',
                icon: Icons.lock_outline,
                obscure: _obscurePass,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePass ? Icons.visibility_off : Icons.visibility,
                    color: AppTheme.textGrey,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePass = !_obscurePass),
                ),
              ),
              const SizedBox(height: 28),

              PrimaryButton(
                label: _isEdit ? 'រក្សាទុក' : 'បន្ថែមអតិថិជន',
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

// ── Tiny section label ────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel(this.label, this.icon);

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 15, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textGrey)),
      ]);
}
