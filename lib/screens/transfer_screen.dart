// lib/screens/transfer_screen.dart

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('ផ្ទេរទំនិញ')),
      body: const EmptyState(
        message: 'មុខងារផ្ទេរទំនិញនឹងមានឆាប់ៗ',
        icon: Icons.swap_horiz_outlined,
      ),
    );
  }
}
