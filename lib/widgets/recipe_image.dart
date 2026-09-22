import 'dart:io';

import 'package:flutter/material.dart';

import '../data/models/recipe.dart';
import '../theme/app_theme.dart';

class RecipeImage extends StatelessWidget {
  final Recipe recipe;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final IconData fallbackIcon;
  final BoxFit fit;

  const RecipeImage({
    super.key,
    required this.recipe,
    required this.width,
    required this.height,
    required this.borderRadius,
    this.fallbackIcon = Icons.ramen_dining_outlined,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final source = _thumbnailSource();
    if (source == null || source.isEmpty) return _fallback();

    return ClipRRect(
      borderRadius: borderRadius,
      child: _isRemote(source)
          ? Image.network(
              source,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) => _fallback(),
            )
          : Image.file(
              File(source),
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) => _fallback(),
            ),
    );
  }

  String? _thumbnailSource() {
    if (recipe.photoSources.isNotEmpty) {
      final firstPhoto = recipe.photoSources.first;
      if (_isRemote(firstPhoto) || File(firstPhoto).existsSync()) {
        return firstPhoto;
      }
    }

    final imageUrl = recipe.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
    return null;
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: borderRadius,
      ),
      child: Icon(fallbackIcon, color: AppColors.primary),
    );
  }

  bool _isRemote(String source) {
    final uri = Uri.tryParse(source);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
