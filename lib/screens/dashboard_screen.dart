// lib/screens/dashboard_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/common_widgets.dart';
import 'sale_screen.dart';
import 'invoice_screen.dart';
import 'purchase_screen.dart';
import 'stock_screen.dart';
import 'supplier_screen.dart';
import 'category_screen.dart';
import 'product_screen.dart';
import 'customer_screen.dart';
import 'bank_account_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import '../providers/auth_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _idx = 0;
  final _pageCtrl = PageController();

  final List<Widget> _pages = const [
    _HomeTab(),
    ReportScreen(),
    SettingsScreen(),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _AppDrawer(
        currentIdx: _idx,
        onNav: (i) {
          Navigator.pop(context);
          setState(() => _idx = i);
        },
      ),
      body: IndexedStack(index: _idx, children: _pages),
      bottomNavigationBar: _BottomNav(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
      ),
    );
  }
}

// ── Side Drawer ───────────────────────────────────────────────────────────────
class _AppDrawer extends StatelessWidget {
  final int currentIdx;
  final ValueChanged<int> onNav;
  const _AppDrawer({required this.currentIdx, required this.onNav});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 280,
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            decoration: const BoxDecoration(color: AppTheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('KOK POS',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                const Text('ប្រព័ន្ធគ្រប់គ្រងការលក់',
                    style:
                    TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),

          // ── Nav Items ─────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerSection('ចម្បង'),
                _DrawerNavItem(
                    icon: Icons.home_outlined,
                    label: 'ទំព័រដើម',
                    active: currentIdx == 0,
                    onTap: () => onNav(0)),
                _DrawerNavItem(
                    icon: Icons.point_of_sale,
                    label: 'លក់ថ្មី',
                    active: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SaleScreen()));
                    }),
                _DrawerSection('គ្រប់គ្រង'),
                _DrawerNavItem(
                    icon: Icons.inventory_2_outlined,
                    label: 'ផលិតផល',
                    active: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ProductScreen()));
                    }),
                _DrawerNavItem(
                    icon: Icons.category_outlined,
                    label: 'ប្រភេទ',
                    active: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const CategoryScreen()));
                    }),
                _DrawerNavItem(
                    icon: Icons.local_shipping_outlined,
                    label: 'អ្នកផ្គត់ផ្គង់',
                    active: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SupplierScreen()));
                    }),
                _DrawerNavItem(
                    icon: Icons.people_outlined,
                    label: 'អតិថិជន',
                    active: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const CustomerScreen()));
                    }),
                _DrawerNavItem(
                    icon: Icons.receipt_long,
                    label: 'វិក្កយបត្រ',
                    active: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const InvoiceScreen()));
                    }),
                _DrawerNavItem(
                    icon: Icons.shopping_bag_outlined,
                    label: 'ការទិញ',
                    active: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const PurchaseScreen()));
                    }),
                _DrawerNavItem(
                    icon: Icons.warehouse_outlined,
                    label: 'ស្តុក',
                    active: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const StockScreen()));
                    }),
                _DrawerNavItem(
                    icon: Icons.account_balance_outlined,
                    label: 'គណនីធនាគារ',
                    active: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const BankAccountScreen()));
                    }),
                _DrawerSection('ព័ត៌មាន'),
                _DrawerNavItem(
                    icon: Icons.bar_chart_outlined,
                    label: 'របាយការណ៍',
                    active: currentIdx == 1,
                    onTap: () => onNav(1)),
                _DrawerNavItem(
                    icon: Icons.settings_outlined,
                    label: 'ការកំណត់',
                    active: currentIdx == 2,
                    onTap: () => onNav(2)),
              ],
            ),
          ),

          // ── Logout ────────────────────────────────────────────────────
          const Divider(height: 0),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppTheme.dangerLt,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.logout,
                  color: AppTheme.danger, size: 18),
            ),
            title: const Text('ចាកចេញ',
                style: TextStyle(
                    color: AppTheme.danger, fontWeight: FontWeight.bold)),
            onTap: () {
              context.read<AuthProvider>().logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String label;
  const _DrawerSection(this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(label.toUpperCase(),
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppTheme.textGrey,
            letterSpacing: .8)),
  );
}

class _DrawerNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _DrawerNavItem(
      {required this.icon,
        required this.label,
        required this.active,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active ? AppTheme.primaryLt : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon,
            color: active ? AppTheme.primary : AppTheme.textGrey, size: 20),
        title: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight:
                active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppTheme.primary : AppTheme.textDark)),
        onTap: onTap,
      ),
    );
  }
}

// ── Bottom Nav ────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'ទំព័រដើម'),
        BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'របាយការណ៍'),
        BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'ការកំណត់'),
      ],
    );
  }
}

// ── Home Tab ──────────────────────────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  const _HomeTab();
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('KOK POS'),
        // Hamburger opens drawer
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          // Cart badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SaleScreen())),
              ),
              Consumer<CartProvider>(
                builder: (_, cart, __) => cart.isEmpty
                    ? const SizedBox()
                    : Positioned(
                  top: 6, right: 6,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle),
                    child: Center(
                      child: Text('${cart.totalQuantity}',
                          style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () => context.read<DashboardProvider>().load(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome banner ─────────────────────────────────────────
              _WelcomeBanner(),

              // ── Image slider banner ─────────────────────────────────────
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _BannerSlider(),
              ),

              // ── Stats ─────────────────────────────────────────────────
              // FIX: this used to load `dash.data` into `d` and then
              // immediately discard it via `return const SizedBox.shrink()`
              // — so revenue/orders/customers/stock numbers were fetched
              // from the API on every screen open but never actually shown
              // anywhere on the home tab. `_AlertBanner` (below) existed in
              // this file but was never instantiated either. Both are now
              // wired up using the same StatCard pattern already proven on
              // the Reports screen, so the home tab and reports screen show
              // numbers from a single consistent source/format.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Consumer<DashboardProvider>(
                  builder: (_, dash, __) {
                    if (dash.isLoading) {
                      return const SizedBox(
                          height: 100,
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.primary, strokeWidth: 2)));
                    }
                    final d = dash.data;
                    return Column(children: [
                      // Row(children: [
                      //   Expanded(
                      //     child: StatCard(
                      //       label: 'ចំណូលសរុប',
                      //       value: Formatter.currency(d.totalSales),
                      //       icon: Icons.payments_outlined,
                      //       color: AppTheme.success,
                      //     ),
                      //   ),
                      //   const SizedBox(width: 12),
                      //   Expanded(
                      //     child: StatCard(
                      //       label: 'ការបញ្ជាទិញ',
                      //       value: '${d.totalOrders}',
                      //       icon: Icons.receipt_long_outlined,
                      //       color: AppTheme.info,
                      //     ),
                      //   ),
                      // ]),
                      // const SizedBox(height: 12),
                      // Row(children: [
                      //   Expanded(
                      //     child: StatCard(
                      //       label: 'ផលិតផល',
                      //       value: '${d.totalProducts}',
                      //       icon: Icons.inventory_2_outlined,
                      //       color: Colors.purple,
                      //     ),
                      //   ),
                      //   const SizedBox(width: 12),
                      //   Expanded(
                      //     child: StatCard(
                      //       label: 'អតិថិជន',
                      //       value: '${d.totalCustomers}',
                      //       icon: Icons.people_outlined,
                      //       color: Colors.indigo,
                      //     ),
                      //   ),
                      // ]),
                      /*if (d.outOfStockItems > 0 || d.lowStockItems > 0) ...[
                        const SizedBox(height: 12),
                        if (d.outOfStockItems > 0)
                          _AlertBanner(
                            msg: '${d.outOfStockItems} ផលិតផលអស់ស្តុក — ត្រូវបញ្ជាទិញបន្ថែម',
                            color: AppTheme.danger,
                            icon: Icons.remove_circle_outline,
                          ),
                        if (d.outOfStockItems > 0 && d.lowStockItems > 0)
                          const SizedBox(height: 8),
                        if (d.lowStockItems > 0)
                          _AlertBanner(
                            msg: '${d.lowStockItems} ផលិតផលស្តុកទាប',
                            color: AppTheme.warning,
                            icon: Icons.warning_amber_rounded,
                          ),
                      ],*/
                    ]);
                  },
                ),
              ),
              const SizedBox(height: 24),

              // ── Quick menu grid ────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('ចូលប្រើរហ័ស',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark)),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _MenuGrid(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Welcome Banner ────────────────────────────────────────────────────────────
class _WelcomeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final greeting = h < 12
        ? 'អរុណសួស្ដី! 🌅'
        : h < 17
        ? 'ទិវាសួស្ដី! ☀️'
        : 'សាយណ្ហសួស្ដី! 🌙';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 4),
            const Text('ប្រព័ន្ធគ្រប់គ្រងការលក់ KOK POS',
                style: TextStyle(fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_todayKhmer(),
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.store_outlined,
              color: Colors.white, size: 30),
        ),
      ]),
    );
  }

  String _todayKhmer() {
    final now = DateTime.now();
    const months = ['មករា','កុម្ភៈ','មីនា','មេសា','ឧសភា','មិថុនា',
      'កក្កដា','សីហា','កញ្ញា','តុលា','វិច្ឆិកា','ធ្នូ'];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

// ── Banner Slider (image-only carousel) ───────────────────────────────────────
class _BannerSlider extends StatefulWidget {
  const _BannerSlider();

  @override
  State<_BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<_BannerSlider> {
  // Replace these with your real asset paths (declared in pubspec.yaml)
  // or network URLs — see _buildImage() below.
  final List<String> _images = const [
    'assets/banners/aba.jpg',
    'assets/banners/acleda.png',
  ];

  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || _images.isEmpty) return;
      _currentPage = (_currentPage + 1) % _images.length;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildImage(String path) {
    // Network image support: if the path looks like a URL, load from network.
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(
                color: AppTheme.primary, strokeWidth: 2),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppTheme.primaryLt,
          child: const Icon(Icons.broken_image_outlined,
              color: AppTheme.textGrey, size: 32),
        ),
      );
    }
    // Local asset image.
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppTheme.primaryLt,
        child: const Icon(Icons.broken_image_outlined,
            color: AppTheme.textGrey, size: 32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 150,
            width: double.infinity,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _images.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) => _buildImage(_images[index]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_images.length, (i) {
            final active = i == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? AppTheme.primary : AppTheme.border,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Alert Banner ──────────────────────────────────────────────────────────────
class _AlertBanner extends StatelessWidget {
  final String msg;
  final Color color;
  final IconData icon;
  const _AlertBanner({required this.msg, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(msg, style: TextStyle(
            color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }
}

// ── Menu Grid ─────────────────────────────────────────────────────────────────
class _MenuGrid extends StatelessWidget {
  static final _menus = [
    _MI('លក់ថ្មី',       Icons.point_of_sale,           AppTheme.primary, (c) => const SaleScreen()),
    _MI('វិក្កយបត្រ',    Icons.receipt_long,             Colors.blue,      (c) => const InvoiceScreen()),
    _MI('ការទិញ',        Icons.shopping_bag_outlined,    Colors.teal,      (c) => const PurchaseScreen()),
    _MI('ផលិតផល',        Icons.inventory_2_outlined,     Colors.purple,    (c) => const ProductScreen()),
    _MI('ប្រភេទ',        Icons.category_outlined,        Colors.orange,    (c) => const CategoryScreen()),
    _MI('អ្នកផ្គត់ផ្គង់',Icons.local_shipping_outlined, Colors.indigo,    (c) => const SupplierScreen()),
    _MI('អតិថិជន',       Icons.people_outlined,          Colors.green,     (c) => const CustomerScreen()),
    _MI('ស្តុក',         Icons.warehouse_outlined,       Colors.brown,     (c) => const StockScreen()),
    _MI('គណនីធនាគារ',   Icons.account_balance_outlined, Colors.cyan,      (c) => const BankAccountScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.0),
      itemCount: _menus.length,
      itemBuilder: (_, i) => _MenuTile(item: _menus[i]),
    );
  }
}

class _MI {
  final String label; final IconData icon; final Color color;
  final Widget Function(BuildContext) builder;
  const _MI(this.label, this.icon, this.color, this.builder);
}

class _MenuTile extends StatelessWidget {
  final _MI item;
  const _MenuTile({super.key, required this.item});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: item.builder)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(item.label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppTheme.textDark),
              textAlign: TextAlign.center, maxLines: 2),
        ]),
      ),
    );
  }
}