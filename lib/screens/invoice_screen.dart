// lib/screens/invoice_screen.dart
// UI rebuilt to match reference screenshots exactly.
// No logic changes — same providers, same API calls, same models.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/order_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../utils/image_helper.dart';
import '../utils/pos_report_helper.dart';
import '../widgets/common_widgets.dart';
import 'product_screen.dart' show scanBarcode;

const double _khrRate = 4100.0;

// ══════════════════════════════════════════════════════════════════════════════
//  INVOICE LIST SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});
  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to   = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() { _tabCtrl.dispose(); _searchCtrl.dispose(); super.dispose(); }

  void _reload({String? query}) =>
      context.read<OrderProvider>().load(query: query, from: _from, to: _to);

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020), lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(
          primary: AppTheme.primary, onPrimary: Colors.white, surface: Colors.white)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { _from = picked.start; _to = picked.end; });
      _reload();
    }
  }

  String get _dateRangeLabel {
    String f(DateTime d) =>
        '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year.toString().substring(2)}';
    return '${f(_from)} - ${f(_to)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('វិក្កយបត្រ'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'បានលក់'), Tab(text: 'របាយការណ៍លក់ប្រចាំថ្ងៃ')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _SoldTab(
            searchCtrl: _searchCtrl,
            dateRangeLabel: _dateRangeLabel,
            onPickDate: _pickDateRange,
            onSearch: (v) => _reload(query: v),
            onClear: () { _searchCtrl.clear(); _reload(); },
          ),
          const _DailyReportTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TAB 1 — បានលក់  (Screenshot 1)
// ══════════════════════════════════════════════════════════════════════════════
class _SoldTab extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String dateRangeLabel;
  final VoidCallback onPickDate;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  const _SoldTab({
    required this.searchCtrl, required this.dateRangeLabel,
    required this.onPickDate, required this.onSearch, required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(builder: (_, prov, __) => Column(children: [

      // ── Search + count badge ─────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
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
                controller: searchCtrl,
                onChanged: onSearch,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'ស្វែងរកវិក្កយបត្រ…',
                  hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textGrey, size: 20),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppTheme.textGrey),
                          onPressed: onClear)
                      : IconButton(
                          icon: const Icon(Icons.qr_code_scanner, size: 18, color: AppTheme.primary),
                          onPressed: () => _scanAndOpenInvoice(context)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.people_alt_outlined, size: 18, color: AppTheme.primary),
              const SizedBox(width: 5),
              Text('${prov.orders.length}',
                  style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.bold, color: AppTheme.primary)),
            ]),
          ),
        ]),
      ),

      // ── Date range + Sort ────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: onPickDate,
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 15, color: AppTheme.textGrey),
                  const SizedBox(width: 8),
                  Expanded(child: Text(dateRangeLabel,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textDark))),
                  const Icon(Icons.arrow_drop_down, color: AppTheme.textGrey),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.sort, size: 16, color: AppTheme.textGrey),
              SizedBox(width: 5),
              Text('សកម្ម', style: TextStyle(fontSize: 13, color: AppTheme.textGrey)),
              Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.textGrey),
            ]),
          ),
        ]),
      ),

      // ── Table header ─────────────────────────────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: const [
          SizedBox(width: 28, child: Text('ល.រ', style: _hdr, textAlign: TextAlign.center)),
          SizedBox(width: 10),
          Expanded(flex: 4, child: Text('វិក្កយបត្រ', style: _hdr)),
          Expanded(flex: 3, child: Text('កាលបរិច្ឆេទ', style: _hdr, textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('សរុប', style: _hdr, textAlign: TextAlign.right)),
        ]),
      ),
      const Divider(height: 1, color: AppTheme.border),

      // ── Rows ─────────────────────────────────────────────────────────────
      Expanded(
        child: prov.isLoading
            ? const AppLoading()
            : prov.orders.isEmpty
                ? const EmptyState(message: 'រកមិនឃើញវិក្កយបត្រ',
                    icon: Icons.receipt_long_outlined)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 4),
                    itemCount: prov.orders.length,
                    itemBuilder: (ctx, i) {
                      final order = prov.orders[i];
                      final id = int.tryParse(order.id) ?? 0;
                      return _InvoiceRow(
                        index: i + 1, order: order,
                        onTap: () => Navigator.push(ctx, MaterialPageRoute(
                            builder: (_) => InvoiceDetailScreen(orderId: id))),
                      );
                    },
                  ),
      ),

      // ── Bottom bar ────────────────────────────────────────────────────────
      if (!prov.isLoading && prov.orders.isNotEmpty)
        _SoldBottomBar(count: prov.orders.length, total: prov.totalRevenue),
    ]));
  }

  Future<void> _scanAndOpenInvoice(BuildContext context) async {
    final code = await scanBarcode(context);
    if (code == null || code.trim().isEmpty) return;

    if (!context.mounted) return;
    showSnack(context, 'កំពុងស្វែងរកវិក្កយបត្រ...');
    final res = await ApiService.getOrders(query: code.trim());
    final list = ApiService.extractList(res);
    if (list.isEmpty) {
      showSnack(context, 'រកមិនឃើញវិក្កយបត្រឡើយ', error: true);
      return;
    }
    final first = list.first;
    final idStr = first['id']?.toString();
    if (idStr == null) {
      showSnack(context, 'លេខសំគាល់វិក្កយបត្រមិនត្រឹមត្រូវ', error: true);
      return;
    }
    final id = int.tryParse(idStr);
    if (id == null) {
      showSnack(context, 'លេខសំគាល់វិក្កយបត្រមិនត្រឹមត្រូវ', error: true);
      return;
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvoiceDetailScreen(orderId: id)),
    );
  }
}

const _hdr = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textDark);

// ── Striped invoice row ────────────────────────────────────────────────────────
class _InvoiceRow extends StatelessWidget {
  final int index;
  final OrderModel order;
  final VoidCallback onTap;
  const _InvoiceRow({required this.index, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: index.isOdd ? Colors.white : const Color(0xFFFAF0F4),
        border: const Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(children: [
        SizedBox(width: 28,
            child: Text('$index',
                style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
                textAlign: TextAlign.center)),
        const SizedBox(width: 10),
        Expanded(flex: 4, child: Text(order.transactionRef,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: AppTheme.textDark),
            overflow: TextOverflow.ellipsis)),
        Expanded(flex: 3, child: Text(
            order.createdAt != null ? Formatter.date(order.createdAt!) : '—',
            style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
            textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text(Formatter.currency(order.totalAmount),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: AppTheme.textDark),
            textAlign: TextAlign.right)),
      ]),
    ),
  );
}

// ── Bottom bar ─────────────────────────────────────────────────────────────────
class _SoldBottomBar extends StatelessWidget {
  final int count;
  final double total;
  const _SoldBottomBar({required this.count, required this.total});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppTheme.border)),
    ),
    padding: EdgeInsets.fromLTRB(
        16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Text('សរុបចំនួន : $count',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                color: AppTheme.primary)),
        const Spacer(),
        const Text('វីករ្រូត  ',
            style: TextStyle(fontSize: 12, color: AppTheme.textGrey)),
        Text(Formatter.currency(total),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                color: AppTheme.primary)),
      ]),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity, height: 46,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.download_outlined, color: AppTheme.primary, size: 18),
          label: const Text('ទាញយករបាយការណ៍',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppTheme.primary)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.primary, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (_) => const _PrintSheet(),
          ),
        ),
      ),
    ]),
  );
}

class _PrintSheet extends StatelessWidget {
  const _PrintSheet();
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SheetHandle(title: 'ទាញយករបាយការណ៍'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.infoLt, borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [
            Icon(Icons.info_outline, color: AppTheme.info, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text(
              'សូមចុចលើវិក្កយបត្រ ដើម្បីមើលលម្អិត រួចចុចប៊ូតុង Print ឬ Download ។',
              style: TextStyle(fontSize: 12, color: AppTheme.info),
            )),
          ]),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('បិទ',
                style: TextStyle(color: AppTheme.textGrey)),
          ),
        ),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  TAB 2 — Daily Sales Report
// ══════════════════════════════════════════════════════════════════════════════
class _DailyReportTab extends StatefulWidget {
  const _DailyReportTab();
  @override
  State<_DailyReportTab> createState() => _DailyReportTabState();
}

class _DailyReportTabState extends State<_DailyReportTab> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to   = DateTime.now();
  List<dynamic>         _rows    = [];
  Map<String, dynamic>? _summary;
  bool                  _loading = false;
  String?               _error;

  @override
  void initState() { super.initState(); _load(); }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final results = await Future.wait([
      ApiService.getSalesReport(from: _fmt(_from), to: _fmt(_to)),
      ApiService.getSalesDaily(from: _fmt(_from), to: _fmt(_to)),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _summary = ApiService.extractData(results[0]) ??
                 results[0]?['data'] as Map<String, dynamic>?;
      _rows    = ApiService.extractList(results[1]);
      if (_rows.isEmpty && results[0]?['error'] != null)
        _error = results[0]!['error']!.toString();
    });
  }

  Future<void> _pick() async {
    final p = await showDateRangePicker(
      context: context, firstDate: DateTime(2020), lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(
          primary: AppTheme.primary, onPrimary: Colors.white, surface: Colors.white)),
        child: child!,
      ),
    );
    if (p != null) { setState(() { _from = p.start; _to = p.end; }); _load(); }
  }

  double get _rev => _rows.fold(0.0,
      (s, r) => s + ((r['totalRevenue'] as num?)?.toDouble() ?? 0));
  int get _ord => _rows.fold(0,
      (s, r) => s + ((r['totalOrders'] as num?)?.toInt() ?? 0));

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: Column(children: [
        GestureDetector(
          onTap: _pick,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border)),
            child: Row(children: [
              const Icon(Icons.date_range_outlined, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '${_from.day.toString().padLeft(2,'0')}/${_from.month.toString().padLeft(2,'0')}/${_from.year}'
                '  →  '
                '${_to.day.toString().padLeft(2,'0')}/${_to.month.toString().padLeft(2,'0')}/${_to.year}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textGrey),
            ]),
          ),
        ),
        if (_summary != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppTheme.primaryLt,
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ចំណូលសរុប',
                    style: TextStyle(fontSize: 11, color: AppTheme.textGrey)),
                Text(Formatter.currency(_rev),
                    style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w800, color: AppTheme.primary)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('ការបញ្ជា',
                    style: TextStyle(fontSize: 11, color: AppTheme.textGrey)),
                Text('$_ord', style: const TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w700, color: AppTheme.primary)),
              ]),
            ]),
          ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
          child: Row(children: const [
            Expanded(flex: 3, child: Text('កាលបរិច្ឆេទ', style: _hdr)),
            SizedBox(width: 44,
                child: Text('ការបញ្ជា', style: _hdr, textAlign: TextAlign.center)),
            SizedBox(width: 8),
            Expanded(flex: 2, child: Text('ចំនួន', style: _hdr, textAlign: TextAlign.right)),
            SizedBox(width: 8),
            Expanded(flex: 3, child: Text('ចំណូល',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppTheme.primary),
                textAlign: TextAlign.right)),
          ]),
        ),
        const Divider(height: 1, color: AppTheme.border),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(
              color: AppTheme.primary, strokeWidth: 2)))
        else if (_error != null)
          Expanded(child: Center(
              child: EmptyState(message: _error!, icon: Icons.error_outline)))
        else if (_rows.isEmpty)
          const Expanded(child: EmptyState(message: 'មិនមានទិន្នន័យ',
              icon: Icons.bar_chart_outlined))
        else
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _rows.length,
            itemBuilder: (_, i) {
              final r       = _rows[i];
              final date    = r['date']?.toString() ?? r['period']?.toString() ?? '—';
              final orders  = (r['totalOrders']  as num?)?.toInt()    ?? 0;
              final qty     = (r['totalQuantity'] as num?)?.toInt()    ?? 0;
              final revenue = (r['totalRevenue']  as num?)?.toDouble() ?? 0;
              return Container(
                color: i.isOdd ? const Color(0xFFFAF0F4) : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(children: [
                  Expanded(flex: 3, child: Text(date, style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark))),
                  SizedBox(width: 44, child: Text('$orders',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textGrey))),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: Text('$qty',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textGrey))),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: Text(Formatter.currency(revenue),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.bold, color: AppTheme.primary))),
                ]),
              );
            },
          )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  INVOICE DETAIL SCREEN  (Screenshot 2)
// ══════════════════════════════════════════════════════════════════════════════
class InvoiceDetailScreen extends StatefulWidget {
  final int orderId;
  const InvoiceDetailScreen({super.key, required this.orderId});
  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  OrderModel? _order;
  bool        _loading = true;
  String?     _error;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final o = await context.read<OrderProvider>().fetchById(widget.orderId);
      if (mounted) setState(() { _order = o; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('ព័ត៌មានវិក្កយបត្រ'),
        actions: [
          if (_order != null) ...[
            IconButton(
              tooltip: 'Print A4',
              icon: const Icon(Icons.print_outlined),
              onPressed: () => printSaleInvoice(
                context: context, mode: 'a4',
                order: _order!, storeName: 'Smart Mart Phnom Penh'),
            ),
            IconButton(
              tooltip: 'Download',
              icon: const Icon(Icons.download_outlined),
              onPressed: () => printSaleInvoice(
                context: context, mode: 'compact',
                order: _order!, storeName: 'Smart Mart Phnom Penh'),
            ),
          ],
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _fetch),
        ],
      ),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _fetch)
              : _DetailBody(order: _order!),
      bottomNavigationBar: _order != null ? _DetailBottomBar(order: _order!) : null,
    );
  }
}

class _DetailBottomBar extends StatelessWidget {
  final OrderModel order;
  const _DetailBottomBar({required this.order});
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: EdgeInsets.fromLTRB(
        16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
    child: Row(children: [
      Expanded(child: ElevatedButton.icon(
        icon: const Icon(Icons.print_outlined, size: 16),
        label: const Text('Print A4',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13), elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () => printSaleInvoice(
          context: context, mode: 'a4',
          order: order, storeName: 'Smart Mart Phnom Penh'),
      )),
      const SizedBox(width: 10),
      Expanded(child: OutlinedButton.icon(
        icon: const Icon(Icons.download_outlined, size: 16, color: AppTheme.primary),
        label: const Text('Download',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: AppTheme.primary)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () => printSaleInvoice(
          context: context, mode: 'compact',
          order: order, storeName: 'Smart Mart Phnom Penh'),
      )),
    ]),
  );
}

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
        Text(error, textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textGrey)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: onRetry, child: const Text('ព្យាយាមម្ដងទៀត')),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  DETAIL BODY  (Screenshot 2 — exact layout)
// ══════════════════════════════════════════════════════════════════════════════
class _DetailBody extends StatelessWidget {
  final OrderModel order;
  const _DetailBody({required this.order});

  @override
  Widget build(BuildContext context) {
    final discount = order.discountTotal;
    final khrTotal = (order.totalAmount * _khrRate).round();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          12, 14, 12, MediaQuery.of(context).padding.bottom + 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── CARD 1: Invoice header info ───────────────────────────────────
        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Card title
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: AppTheme.primaryLt,
                  borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.receipt_outlined,
                  color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('ព័ត៌មានអំពីវិក្កយបត្រ',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                    color: AppTheme.textDark)),
          ]),
          const _Div(),

          // លេខវិក្កយបត្រ
          _DR(label: 'លេខវិក្កយបត្រ', value: order.transactionRef, bold: true),
          const _Div(),
          // ថ្ងៃចេញ
          _DR(label: 'ថ្ងៃចេញវិក្កយបត្រ',
              value: order.createdAt != null
                  ? '${Formatter.date(order.createdAt!)} ${Formatter.time(order.createdAt!)}'
                  : '—'),
          const _Div(),
          // អ្នកលក់
          _DR(label: 'អ្នកលក់', value: 'Admin Testing'),
          const _Div(),
          // កូដអតិថិជន
          _DR(label: 'កូដអតិថិជន',
              value: order.userId != null ? '${order.userId}' : '—'),
          const _Div(),
          // ឈ្មោះអតិថិជន
          _DR(label: 'ឈ្មោះអតិថិជន', value: 'អតិថិជនទូទៅ'),
          const _Div(),
          // លេខអតិថិជន
          _DR(label: 'លេខអតិថិជន', value: order.id),
          const _Div(),
          // ទីតាំង
          _DR(label: 'ទីតាំងអតិថិជន', value: 'Default Address'),
        ])),
        const SizedBox(height: 12),

        // ── CARD 2: Items table ───────────────────────────────────────────
        _Card(
          padding: EdgeInsets.zero,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              decoration: const BoxDecoration(
                color: AppTheme.primaryLt,
                borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Row(children: const [
                Expanded(flex: 4, child: Text('ទំនិញ',     style: _th)),
                SizedBox(width: 40, child: Text('ចំនួន',   style: _th, textAlign: TextAlign.center)),
                SizedBox(width: 58, child: Text('តម្លៃ',    style: _th, textAlign: TextAlign.right)),
                SizedBox(width: 58, child: Text('បញ្ចុះតម្លៃ', style: _th, textAlign: TextAlign.right)),
                SizedBox(width: 58, child: Text('សរុប',    style: _th, textAlign: TextAlign.right)),
              ]),
            ),
            if (order.items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('មិនមានទំនិញ',
                    style: TextStyle(color: AppTheme.textGrey))),
              )
            else
              ...order.items.asMap().entries.map((e) => _ItemRow(
                  item: e.value, isLast: e.key == order.items.length - 1)),
          ]),
        ),
        const SizedBox(height: 12),

        // ── CARD 3: Payment method ────────────────────────────────────────
        _Card(child: _SR(
          label: 'វិធីសាស្ត្រទូទាត់',
          value: order.paymentName ?? 'CASH_USD',
          valueBold: true,
        )),
        const SizedBox(height: 8),

        // ── CARD 4: Exchange / VAT ────────────────────────────────────────
        _Card(child: Column(children: [
          _SR(label: 'អត្រាប្ដូរប្រាក់',
              value: '\$ 1.0 / ៛ ${_fmtKhr(_khrRate.toInt())}'),
          const _Div(),
          _SR(label: 'VAT / Tax', value: '% 0.0'),
          const _Div(),
          _SR(label: 'Vat (\$)', value: '\$ 0.00'),
        ])),
        const SizedBox(height: 8),

        // ── CARD 5: Totals ────────────────────────────────────────────────
        _Card(child: Column(children: [
          _SR(label: 'សរុបរង', value: Formatter.currency(order.subtotalAmount)),

          if (discount > 0) ...[
            const _Div(),
            _SR(label: 'បញ្ចុះតម្លៃ',
                value: Formatter.currency(discount),
                valueColor: AppTheme.success),
          ],
          const _Div(),

          // Total USD — big & primary colour
          Row(children: [
            const Expanded(child: Text('សរុប',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                    color: AppTheme.textDark))),
            Text(Formatter.currency(order.totalAmount),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: AppTheme.primary)),
          ]),
          // Total KHR — also primary colour, right-aligned
          Align(
            alignment: Alignment.centerRight,
            child: Text('៛ ${_fmtKhr(khrTotal)}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                    color: AppTheme.primary)),
          ),
          const _Div(),
          // ប្រាក់ទទួល
          _SR(label: 'ប្រាក់ទទួល', value: Formatter.currency(order.totalAmount)),
        ])),
      ]),
    );
  }
}

const _th = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary);

// ── Item table row ─────────────────────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final OrderItemModel item;
  final bool           isLast;
  const _ItemRow({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final pct = item.unitPrice > 0
        ? (item.unitPrice - item.discountedUnitPrice) / item.unitPrice * 100
        : 0.0;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Image + name
          Expanded(flex: 4, child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(width: 38, height: 38,
                  child: _img(item.imageUrl)),
            ),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.productName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppTheme.textDark),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(item.productCode,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textGrey,
                      fontFamily: 'monospace')),
            ])),
          ])),
          // Qty
          SizedBox(width: 40, child: Text('${item.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textGrey))),
          // Unit price
          SizedBox(width: 58, child: Text(Formatter.currency(item.unitPrice),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: AppTheme.textGrey))),
          // Discount %
          SizedBox(width: 58, child: Text('${pct.toStringAsFixed(2)}%',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12,
                  color: pct > 0 ? AppTheme.success : AppTheme.textGrey))),
          // Subtotal
          SizedBox(width: 58, child: Text(Formatter.currency(item.subTotal),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                  color: AppTheme.textDark))),
        ]),
      ),
      if (!isLast) const Divider(height: 1, color: AppTheme.border),
    ]);
  }

  static const _ph = ColoredBox(
    color: Color(0xFFF2F2F2),
    child: Center(child: Icon(Icons.inventory_2_outlined,
        color: Color(0xFFCCCCCC), size: 18)),
  );

  Widget _img(String? url) {
    final r = ImageHelper.resolve(url);
    if (r.isEmpty) return _ph;
    return Image.network(r, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _ph);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TINY SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

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
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.025),
          blurRadius: 4, offset: const Offset(0, 2))],
    ),
    child: child,
  );
}

/// Thin divider with spacing
class _Div extends StatelessWidget {
  const _Div();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 16, color: AppTheme.border);
}

/// Detail row: "Label : Value" (used in header card)
class _DR extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _DR({required this.label, required this.value, this.bold = false});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(label,
        style: const TextStyle(fontSize: 13, color: AppTheme.textGrey))),
    const Text(': ', style: TextStyle(fontSize: 13, color: AppTheme.textGrey)),
    Expanded(flex: 2, child: Text(value,
        style: TextStyle(fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: AppTheme.textDark))),
  ]);
}

/// Summary row: "Label  ............  Value" (right-aligned value)
class _SR extends StatelessWidget {
  final String label, value;
  final bool   valueBold;
  final Color? valueColor;
  const _SR({required this.label, required this.value,
      this.valueBold = false, this.valueColor});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(label,
        style: const TextStyle(fontSize: 13, color: AppTheme.textGrey))),
    Text(value, style: TextStyle(
        fontSize: 13,
        fontWeight: valueBold ? FontWeight.bold : FontWeight.w600,
        color: valueColor ?? AppTheme.textDark)),
  ]);
}

/// KHR thousands formatter
String _fmtKhr(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
