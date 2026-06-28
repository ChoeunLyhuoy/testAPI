// lib/widgets/common_widgets.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/image_helper.dart';
import '../theme/app_theme.dart';

// ── App Search Bar ────────────────────────────────────────────────────────────
class AppSearchBar extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onScan;

  const AppSearchBar({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onClear,
    this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        const SizedBox(width: 12),
        const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              filled: false,
            ),
          ),
        ),
        if (onClear != null && (controller?.text.isNotEmpty ?? false))
          GestureDetector(
            onTap: onClear,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.close, color: AppTheme.primary, size: 18),
            ),
          ),
        if (onScan != null)
          GestureDetector(
            onTap: onScan,
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
            ),
          ),
      ]),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    this.message = 'No data',
    this.icon = Icons.folder_off_outlined,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryLt,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 40, color: AppTheme.primary.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(fontSize: 15, color: AppTheme.textGrey),
              textAlign: TextAlign.center),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onAction, child: Text(action!)),
          ],
        ]),
      ),
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────
class AppLoading extends StatelessWidget {
  final String? message;
  const AppLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 3),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(message!, style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
        ],
      ]),
    );
  }
}

// ── Primary Button ─────────────────────────────────────────────────────────────
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Color? color;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: color != null
            ? ElevatedButton.styleFrom(backgroundColor: color)
            : null,
        child: loading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                Text(label),
              ]),
      ),
    );
  }
}

// ── App Field ──────────────────────────────────────────────────────────────────
class AppField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final int maxLines;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final bool readOnly;

  const AppField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.maxLines = 1,
    this.hint,
    this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      maxLines: maxLines,
      onChanged: onChanged,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, color: AppTheme.primary, size: 18)
            : null,
        suffixIcon: suffix,
      ),
    );
  }
}

// ── Status Badge ───────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

// ── Image Picker Box ──────────────────────────────────────────────────────────
class ImagePickerBox extends StatelessWidget {
  final File? imageFile;
  final String? networkUrl;
  final VoidCallback onTap;
  final double size;
  final bool circle;

  const ImagePickerBox({
    super.key,
    this.imageFile,
    this.networkUrl,
    required this.onTap,
    this.size = 110,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve URL — handles localhost replacement
    final resolvedUrl = ImageHelper.resolve(networkUrl);

    Widget inner;
    if (imageFile != null) {
      inner = Image.file(imageFile!, fit: BoxFit.cover);
    } else if (resolvedUrl.isNotEmpty) {
      inner = Image.network(
        resolvedUrl,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, p) =>
            p == null ? child : _loadingPlaceholder(),
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else {
      inner = _placeholder();
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(alignment: Alignment.bottomRight, children: [
        Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circle ? null : BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: circle
              ? ClipOval(child: SizedBox.expand(child: inner))
              : ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: SizedBox.expand(child: inner)),
        ),
        Positioned(
          bottom: 2, right: 2,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppTheme.primary),
            child: const Icon(Icons.camera_alt, color: Colors.white, size: 13),
          ),
        ),
      ]),
    );
  }

  Widget _placeholder() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 28, color: Colors.grey[400]),
          const SizedBox(height: 4),
          Text('Image',
              style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        ],
      );

  Widget _loadingPlaceholder() => Center(
        child: SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppTheme.primary),
        ),
      );
}

// ── Net Image ─────────────────────────────────────────────────────────────────
// ── Net Image ─────────────────────────────────────────────────────────────────
// Loads any URL from the API. Handles:
//  • http://localhost/... → replaces with real server IP
//  • null / empty / "null" → shows placeholder
//  • size: double.infinity → fills parent (never passed to Image.network)
//  • load error → shows icon placeholder (never broken image icon)
class NetImage extends StatelessWidget {
  final String? url;
  final double size;
  final BorderRadius? radius;
  final IconData fallback;

  const NetImage({
    super.key,
    this.url,
    this.size = 48,
    this.radius,
    this.fallback = Icons.image_outlined,
  });

  bool get _isInfinite => size == double.infinity || size > 9000;
  double? get _sz => _isInfinite ? null : size;
  double get _iconSz => _isInfinite ? 32 : (size * 0.42).clamp(12, 48);

  @override
  Widget build(BuildContext context) {
    final resolved = ImageHelper.resolve(url);
    final br = radius ?? BorderRadius.circular(8);

    if (resolved.isEmpty) return _placeholder(br);

    return ClipRRect(
      borderRadius: br,
      child: Image.network(
        resolved,
        width:  _sz,
        height: _sz,
        fit:    BoxFit.cover,
        loadingBuilder: (_, child, prog) {
          if (prog == null) return child;
          return _loadBox(
            br,
            child: Center(
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                  value: prog.expectedTotalBytes != null
                      ? prog.cumulativeBytesLoaded / prog.expectedTotalBytes!
                      : null,
                ),
              ),
            ),
          );
        },
        errorBuilder: (_, err, __) {
          debugPrint('[NetImage] ✗ $resolved');
          return _placeholder(br);
        },
      ),
    );
  }

  Widget _loadBox(BorderRadius br, {required Widget child}) => Container(
        width: _sz, height: _sz,
        decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2), borderRadius: br),
        child: child,
      );

  Widget _placeholder(BorderRadius br) => Container(
        width: _sz, height: _sz,
        decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2), borderRadius: br),
        child: Center(
          child: Icon(fallback,
              color: const Color(0xFFCCCCCC), size: _iconSz),
        ),
      );
}

// ── Card Row ──────────────────────────────────────────────────────────────────
class CardRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const CardRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        leading: leading,
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textDark)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: const TextStyle(fontSize: 12, color: AppTheme.textGrey))
            : null,
        trailing: trailing,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

// ── Sheet Handle ──────────────────────────────────────────────────────────────
class SheetHandle extends StatelessWidget {
  final String? title;
  const SheetHandle({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Center(
        child: Container(
          width: 40, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        ),
      ),
      if (title != null) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(title!,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary)),
        ),
      ],
    ]);
  }
}

// ── Confirm Delete ────────────────────────────────────────────────────────────
Future<bool> confirmDelete(BuildContext context, String message) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirm Delete',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 36)),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}

// ── Snack helper ──────────────────────────────────────────────────────────────
void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? AppTheme.danger : AppTheme.success,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    margin: const EdgeInsets.all(12),
  ));
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textGrey)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ]),
        ),
      ]),
    );
  }
}
