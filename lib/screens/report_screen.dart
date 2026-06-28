// lib/screens/report_screen.dart
//
// REBUILT: Full report screen with 3 tabs:
//   1. ការលក់   — Sales overview + daily breakdown + category breakdown
//   2. ការទិញ  — Purchase summary (cost, items, suppliers)
//   3. ស្តុក    — Stock status (low stock, out of stock)
// No logic changes — only uses existing ApiService report endpoints.

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/common_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ROOT
// ══════════════════════════════════════════════════════════════════════════════
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('របាយការណ៍'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'ការលក់'),
            Tab(text: 'ការទិញ'),
            Tab(text: 'ស្តុក'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _SalesReportTab(),
          _PurchaseReportTab(),
          _StockReportTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TAB 1 — ការលក់  (Sales)
// ══════════════════════════════════════════════════════════════════════════════
class _SalesReportTab extends StatefulWidget {
  const _SalesReportTab();
  @override
  State<_SalesReportTab> createState() => _SalesReportTabState();
}

class _SalesReportTabState extends State<_SalesReportTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to   = DateTime.now();

  Map<String, dynamic>? _summary;
  List<dynamic> _daily    = [];
  List<dynamic> _byCat    = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final from = _fmt(_from);
    final to   = _fmt(_to);
    final results = await Future.wait([
      ApiService.getSalesReport(from: from, to: to),
      ApiService.getSalesDaily(from: from, to: to),
      ApiService.getSalesByCategory(from: from, to: to),
    ]);
    if (!mounted) return;
    final sumRes = results[0];
    final dayRes = results[1];
    final catRes = results[2];

    String? errMsg;
    if (sumRes?['error'] != null) {
      errMsg = sumRes!['error'].toString();
    } else if (dayRes?['error'] != null) {
      errMsg = dayRes!['error'].toString();
    } else if (catRes?['error'] != null) {
      errMsg = catRes!['error'].toString();
    } else if (sumRes?['status'] != null && (sumRes!['status'] as int) >= 400) {
      errMsg = 'Server returned status ${sumRes['status']}';
    }

    setState(() {
      _loading = false;
      _error = errMsg;
      _summary = ApiService.extractData(sumRes) ?? sumRes?['data'] as Map<String, dynamic>?;
      _daily   = ApiService.extractList(dayRes);
      _byCat   = ApiService.extractList(catRes);
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ── Date picker bar ───────────────────────────────────────────
          _DateBar(from: _from, to: _to, onTap: _pickRange),
          const SizedBox(height: 14),

          if (_loading)
            const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)),
            )
          else if (_error != null)
            _ErrCard(message: _error!, onRetry: _load)
          else ...[
            // ── Summary banner ─────────────────────────────────────────
            _SalesBanner(summary: _summary),
            const SizedBox(height: 14),

            // ── Daily breakdown ─────────────────────────────────────────
            if (_daily.isNotEmpty) ...[
              _SectionHeader(label: 'ប្រចាំថ្ងៃ', icon: Icons.calendar_today_outlined),
              const SizedBox(height: 8),
              ..._daily.map((d) => _DailyRow(data: d)).toList(),
              const SizedBox(height: 14),
            ],

            // ── Category breakdown ──────────────────────────────────────
            if (_byCat.isNotEmpty) ...[
              _SectionHeader(label: 'តាមប្រភេទ', icon: Icons.category_outlined),
              const SizedBox(height: 8),
              ..._byCat.map((c) => _CatRow(data: c)).toList(),
            ],

            if (_daily.isEmpty && _byCat.isEmpty && _summary == null)
              const EmptyState(
                message: 'មិនមានទិន្នន័យ',
                icon: Icons.bar_chart_outlined,
              ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TAB 2 — ការទិញ  (Purchases)
// ══════════════════════════════════════════════════════════════════════════════
class _PurchaseReportTab extends StatefulWidget {
  const _PurchaseReportTab();
  @override
  State<_PurchaseReportTab> createState() => _PurchaseReportTabState();
}

class _PurchaseReportTabState extends State<_PurchaseReportTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to   = DateTime.now();

  Map<String, dynamic>? _data;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final res = await ApiService.getPurchasesReport(
      from: _fmt(_from), to: _fmt(_to));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = ApiService.extractData(res) ?? res?['data'] as Map<String, dynamic>?;
      if (_data == null) _error = res?['error']?.toString() ?? 'Error loading';
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _DateBar(from: _from, to: _to, onTap: _pickRange),
          const SizedBox(height: 14),

          if (_loading)
            const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)),
            )
          else if (_error != null)
            _ErrCard(message: _error!, onRetry: _load)
          else if (_data == null)
            const EmptyState(message: 'មិនមានទិន្នន័យ', icon: Icons.shopping_bag_outlined)
          else
            _PurchaseSummaryCard(data: _data!),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TAB 3 — ស្តុក  (Stock)
// ══════════════════════════════════════════════════════════════════════════════
class _StockReportTab extends StatefulWidget {
  const _StockReportTab();
  @override
  State<_StockReportTab> createState() => _StockReportTabState();
}

class _StockReportTabState extends State<_StockReportTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<dynamic> _all      = [];
  List<dynamic> _lowStock = [];
  bool _showLowOnly = false;
  bool _loading     = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final res = await ApiService.getStockReport(lowStockOnly: false);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _all = ApiService.extractList(res);
      _lowStock = _all.where((item) {
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
        return qty <= 5;
      }).toList();
      if (_all.isEmpty) _error = res?['error']?.toString();
    });
  }

  List<dynamic> get _displayed => _showLowOnly ? _lowStock : _all;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: Column(
        children: [
          // ── Filter bar ───────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                // Summary chips
                _StockChip(
                  label: 'សរុប ${_all.length}',
                  color: AppTheme.info,
                  active: !_showLowOnly,
                  onTap: () => setState(() => _showLowOnly = false),
                ),
                const SizedBox(width: 8),
                _StockChip(
                  label: 'ទាប ${_lowStock.length}',
                  color: AppTheme.warning,
                  active: _showLowOnly,
                  onTap: () => setState(() => _showLowOnly = true),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _load,
                  child: const Icon(Icons.refresh, color: AppTheme.primary, size: 22),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)),
            )
          else if (_error != null)
            Expanded(child: _ErrCard(message: _error!, onRetry: _load))
          else if (_displayed.isEmpty)
            const Expanded(
              child: EmptyState(message: 'មិនមានទិន្នន័យ', icon: Icons.inventory_2_outlined),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: _displayed.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _StockRow(data: _displayed[i]),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SALES WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _SalesBanner extends StatelessWidget {
  final Map<String, dynamic>? summary;
  const _SalesBanner({required this.summary});

  double _num(String k) => (summary?[k] as num?)?.toDouble() ?? 0;
  int    _int(String k) => (summary?[k] as num?)?.toInt()    ?? 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Revenue hero card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDk],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.25),
                blurRadius: 12, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ចំណូលសរុប',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 6),
            Text(
              Formatter.currency(_num('totalRevenue')),
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5),
            ),
            const SizedBox(height: 14),
            Row(children: [
              _HeroStat(value: '${_int('totalOrders')}',   label: 'ការបញ្ជាទិញ'),
              _Divider(),
              _HeroStat(value: '${_int('totalQuantity')}', label: 'ចំណាប់'),
              _Divider(),
              _HeroStat(
                value: Formatter.currency(_num('totalDiscount')),
                label: 'បញ្ចុះ',
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 12),

        // Net profit row
        if ((summary?['netProfit'] ?? summary?['profit']) != null)
          Row(children: [
            Expanded(child: _MetricTile(
              label: 'ប្រាក់ចំណេញ',
              value: Formatter.currency(_num('netProfit')),
              icon: Icons.trending_up_rounded,
              iconColor: AppTheme.success,
              bg: AppTheme.successLt,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MetricTile(
              label: 'ដៃ​គូ',
              value: '${_int('totalCustomers')}',
              icon: Icons.people_alt_outlined,
              iconColor: AppTheme.info,
              bg: AppTheme.infoLt,
            )),
          ]),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value, label;
  const _HeroStat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
      Text(label,
          style: const TextStyle(fontSize: 10, color: Colors.white60)),
    ],
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 30, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 14),
  );
}

class _MetricTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color iconColor;
  final Color bg;
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bg,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icon, size: 22, color: iconColor),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
        ]),
      ]),
    );
  }
}

class _DailyRow extends StatelessWidget {
  final dynamic data;
  const _DailyRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final date    = data['date']?.toString() ?? data['period']?.toString() ?? '—';
    final orders  = (data['totalOrders']   as num?)?.toInt()    ?? 0;
    final revenue = (data['totalRevenue']  as num?)?.toDouble() ?? 0;
    final qty     = (data['totalQuantity'] as num?)?.toInt()    ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        // Date
        SizedBox(
          width: 80,
          child: Text(date,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        ),
        // Orders badge
        Container(
          width: 32, height: 20,
          decoration: BoxDecoration(
            color: AppTheme.infoLt,
            borderRadius: BorderRadius.circular(5),
          ),
          alignment: Alignment.center,
          child: Text('$orders',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.info)),
        ),
        const SizedBox(width: 6),
        Text('$qty ចំណាប់',
            style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
        const Spacer(),
        Text(Formatter.currency(revenue),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
      ]),
    );
  }
}

class _CatRow extends StatelessWidget {
  final dynamic data;
  const _CatRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final name    = data['categoryName']?.toString() ?? '—';
    final orders  = (data['totalOrders']  as num?)?.toInt()    ?? 0;
    final revenue = (data['totalRevenue'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primaryLt,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.category_outlined, color: AppTheme.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
            Text('$orders ការបញ្ជាទិញ',
                style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
          ]),
        ),
        Text(Formatter.currency(revenue),
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PURCHASE WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _PurchaseSummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PurchaseSummaryCard({required this.data});

  double _num(String k) => (data[k] as num?)?.toDouble() ?? 0;
  int    _int(String k) => (data[k] as num?)?.toInt()    ?? 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total cost hero
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withOpacity(0.25),
                blurRadius: 12, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ថ្លៃដើមសរុប',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 6),
            Text(Formatter.currency(_num('totalCost')),
                style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5)),
            const SizedBox(height: 14),
            Row(children: [
              _HeroStat(value: '${_int('totalPurchases')}', label: 'ការទិញ'),
              Container(width: 1, height: 30, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 14)),
              _HeroStat(value: '${_int('totalItems')}', label: 'ចំណាប់'),
              Container(width: 1, height: 30, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 14)),
              _HeroStat(
                value: Formatter.currency(_num('averagePurchaseCost')),
                label: 'មធ្យម',
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 14),

        // Metric grid
        Row(children: [
          Expanded(child: _MetricTile(
            label: 'តម្លៃលក់សរុប',
            value: Formatter.currency(_num('totalRetailValue')),
            icon: Icons.sell_outlined,
            iconColor: AppTheme.success,
            bg: AppTheme.successLt,
          )),
          const SizedBox(width: 10),
          Expanded(child: _MetricTile(
            label: 'ចំណេញ',
            value: Formatter.currency(_num('totalRetailValue') - _num('totalCost')),
            icon: Icons.trending_up_rounded,
            iconColor: AppTheme.primary,
            bg: AppTheme.primaryLt,
          )),
        ]),

        if (data['suppliers'] != null && (data['suppliers'] as List).isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionHeader(label: 'អ្នកផ្គត់ផ្គង់', icon: Icons.local_shipping_outlined),
          const SizedBox(height: 8),
          ...(data['suppliers'] as List).map((s) => _SupplierRow(data: s)).toList(),
        ],
      ],
    );
  }
}

class _SupplierRow extends StatelessWidget {
  final dynamic data;
  const _SupplierRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final name  = data['supplierName']?.toString() ?? '—';
    final count = (data['purchaseCount'] as num?)?.toInt()    ?? 0;
    final cost  = (data['totalCost']     as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppTheme.infoLt,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.local_shipping_outlined, color: AppTheme.info, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
          Text('$count ការបញ្ជាទិញ',
              style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
        ])),
        Text(Formatter.currency(cost),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.info)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  STOCK WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _StockRow extends StatelessWidget {
  final dynamic data;
  const _StockRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final name     = data['productName']?.toString() ?? data['name']?.toString() ?? '—';
    final code     = data['productCode']?.toString() ?? '—';
    final qty      = (data['quantity'] as num?)?.toInt() ?? 0;
    final category = data['categoryName']?.toString() ?? '';

    Color qtyColor;
    Color qtyBg;
    if (qty <= 0) {
      qtyColor = AppTheme.danger;
      qtyBg    = AppTheme.dangerLt;
    } else if (qty <= 5) {
      qtyColor = AppTheme.warning;
      qtyBg    = AppTheme.warningLt;
    } else {
      qtyColor = AppTheme.success;
      qtyBg    = AppTheme.successLt;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryLt,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('$code${category.isNotEmpty ? "  ·  $category" : ""}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: qtyBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$qty',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: qtyColor)),
        ),
      ]),
    );
  }
}

class _StockChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _StockChip({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: active ? color : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppTheme.textGrey),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _DateBar extends StatelessWidget {
  final DateTime from, to;
  final VoidCallback onTap;
  const _DateBar({required this.from, required this.to, required this.onTap});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          const Icon(Icons.date_range_outlined, size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(
            '${_fmt(from)}  →  ${_fmt(to)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
          )),
          const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textGrey),
        ]),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 16, color: AppTheme.primary),
    const SizedBox(width: 8),
    Text(label,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
    const SizedBox(width: 10),
    Expanded(child: Container(height: 1, color: AppTheme.border)),
  ]);
}

class _ErrCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.dangerLt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
      ),
      child: Column(children: [
        const Icon(Icons.error_outline, color: AppTheme.danger, size: 36),
        const SizedBox(height: 10),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.danger)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('ព្យាយាមម្តងទៀត'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.danger,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        ),
      ]),
    );
  }
}
