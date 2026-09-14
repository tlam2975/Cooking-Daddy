import 'package:flutter/material.dart';

import '../services/shopping_cart.dart';
import '../theme/app_theme.dart';

class ShoppingCartScreen extends StatelessWidget {
  const ShoppingCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = ShoppingCart.instance;

    return SafeArea(
      child: AnimatedBuilder(
        animation: cart,
        builder: (context, _) {
          final items = cart.items;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Đi chợ', style: AppTextStyles.greeting),
                          const SizedBox(height: 4),
                          Text(
                            items.isEmpty
                                ? 'Chưa có nguyên liệu nào'
                                : '${cart.uncheckedCount} món chưa mua',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Xóa giỏ',
                      onPressed: items.isEmpty ? null : cart.clear,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? _EmptyCart()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Dismissible(
                            key: ValueKey(item.key),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => cart.removeItem(item),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red.shade100,
                              child: Icon(
                                Icons.delete_outline,
                                color: Colors.red.shade700,
                              ),
                            ),
                            child: CheckboxListTile(
                              value: item.isChecked,
                              onChanged: (value) =>
                                  cart.toggleItem(item, value ?? false),
                              title: Text(
                                cart.formatItem(item),
                                style: AppTextStyles.body.copyWith(
                                  decoration: item.isChecked
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: item.isChecked
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                ),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              tileColor: AppColors.surface,
                            ),
                          );
                        },
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemCount: items.length,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.shopping_basket_outlined,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text('Giỏ đi chợ trống', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 6),
            Text(
              'Mở một công thức và thêm nguyên liệu vào đây.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}
