// lib/models/dashboard_model.dart
// Matches DashboardReportResponse: { totalProducts, totalProductOptions,
//   totalCustomers, totalOrders, totalSales, lowStockItems, outOfStockItems }

class DashboardModel {
  final int totalProducts;
  final int totalProductOptions;
  final int totalCustomers;
  final int totalOrders;
  final double totalSales;
  final int lowStockItems;
  final int outOfStockItems;

  const DashboardModel({
    required this.totalProducts,
    required this.totalProductOptions,
    required this.totalCustomers,
    required this.totalOrders,
    required this.totalSales,
    required this.lowStockItems,
    required this.outOfStockItems,
  });

  factory DashboardModel.fromMap(Map<String, dynamic> m) => DashboardModel(
        totalProducts: (m['totalProducts'] as num?)?.toInt() ?? 0,
        totalProductOptions: (m['totalProductOptions'] as num?)?.toInt() ?? 0,
        totalCustomers: (m['totalCustomers'] as num?)?.toInt() ?? 0,
        totalOrders: (m['totalOrders'] as num?)?.toInt() ?? 0,
        totalSales: (m['totalSales'] as num?)?.toDouble() ?? 0,
        lowStockItems: (m['lowStockItems'] as num?)?.toInt() ?? 0,
        outOfStockItems: (m['outOfStockItems'] as num?)?.toInt() ?? 0,
      );

  factory DashboardModel.empty() => const DashboardModel(
        totalProducts: 0,
        totalProductOptions: 0,
        totalCustomers: 0,
        totalOrders: 0,
        totalSales: 0,
        lowStockItems: 0,
        outOfStockItems: 0,
      );
}
