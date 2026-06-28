// lib/screens/stock_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/common_widgets.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<dynamic> _items = [];
  bool _loading = false;
  String _filter = 'All';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.getStockReport();
    setState(() {
      _items = ApiService.extractList(res);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.toLowerCase();
    final shown = _items.where((i) {
      final name = (i['productName'] ?? '').toString().toLowerCase();
      final code = (i['productCode'] ?? '').toString().toLowerCase();
      final qty = (i['quantity'] as num?)?.toInt() ?? 0;
      final matchSearch = q.isEmpty || name.contains(q) || code.contains(q);
      final matchFilter = _filter == 'All' ||
          (_filter == 'Low' && qty > 0 && qty < 10) ||
          (_filter == 'Out' && qty == 0);
      return matchSearch && matchFilter;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('ស្តុក / សារពើភ័ណ្ឌ'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            AppSearchBar(
              hint: 'ស្វែងរកស្តុក…',
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              onClear: () { _searchCtrl.clear(); setState(() {}); },
            ),
            const SizedBox(height: 8),
            Row(children: [
              _FChip('ទាំងអស់', 'All', _filter, () => setState(() => _filter = 'All')),
              const SizedBox(width: 8),
              _FChip('ស្តុកទាប', 'Low', _filter, () => setState(() => _filter = 'Low'),
                  color: AppTheme.warning),
              const SizedBox(width: 8),
              _FChip('អស់ស្តុក', 'Out', _filter, () => setState(() => _filter = 'Out'),
                  color: AppTheme.danger),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(children: [
            _SBadge('ទាំងអស់ ${_items.length}', Colors.blue),
            const SizedBox(width: 8),
            _SBadge('ទាប ${_items.where((i) => (i['quantity'] as num? ?? 0) > 0 && (i['quantity'] as num? ?? 0) < 10).length}', AppTheme.warning),
            const SizedBox(width: 8),
            _SBadge('អស់ ${_items.where((i) => (i['quantity'] as num? ?? 0) == 0).length}', AppTheme.danger),
          ]),
        ),
        Expanded(
          child: _loading
              ? const AppLoading()
              : shown.isEmpty
                  ? const EmptyState(message: 'រកមិនឃើញ', icon: Icons.warehouse_outlined)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: shown.length,
                      itemBuilder: (_, i) => _StockRow(item: shown[i]),
                    ),
        ),
      ]),
    );
  }
}

class _FChip extends StatelessWidget {
  final String label; final String val; final String cur;
  final VoidCallback onTap; final Color? color;
  const _FChip(this.label, this.val, this.cur, this.onTap, {this.color});
  @override
  Widget build(BuildContext context) {
    final sel = cur == val;
    final c = color ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? c.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? c : AppTheme.border),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: sel ? c : AppTheme.textGrey)),
      ),
    );
  }
}

class _SBadge extends StatelessWidget {
  final String label; final Color color;
  const _SBadge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
  );
}

class _StockRow extends StatelessWidget {
  final dynamic item;
  const _StockRow({required this.item});
  @override
  Widget build(BuildContext context) {
    final qty = (item['quantity'] as num?)?.toInt() ?? 0;
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final stockVal = (item['stockValue'] as num?)?.toDouble() ?? 0;
    final color = qty == 0 ? AppTheme.danger : qty < 10 ? AppTheme.warning : AppTheme.success;
    final lbl = qty == 0 ? 'អស់' : qty < 10 ? 'ទាប' : 'ល្អ';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: AppTheme.primaryLt, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['productName']?.toString() ?? '',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
          const SizedBox(height: 2),
          Text('${item['productCode'] ?? ''}  ·  ${item['categoryName'] ?? ''}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
          const SizedBox(height: 4),
          // Stock bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: qty == 0 ? 0 : (qty / 100).clamp(0, 1),
              minHeight: 4,
              backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ])),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$qty',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          StatusBadge(label: lbl, color: color),
          const SizedBox(height: 2),
          Text(Formatter.currency(price),
              style: const TextStyle(fontSize: 10, color: AppTheme.textGrey)),
        ]),
      ]),
    );
  }
}
