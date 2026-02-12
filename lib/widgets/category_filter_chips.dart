import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable horizontal scrollable category filter chips.
///
/// Displays a list of categories as filter chips with highlighting
/// for the selected category. Eliminates duplicate category filtering
/// UI across zen_vault_screen.dart and saved_rituals_screen.dart.
class CategoryFilterChips extends StatelessWidget {
  /// Currently selected category
  final String selectedCategory;

  /// List of available categories to display
  final List<String> categories;

  /// Callback when a category is selected
  final ValueChanged<String> onCategorySelected;

  /// Optional chip height
  final double chipHeight;

  /// Optional horizontal padding between chips
  final double chipSpacing;

  const CategoryFilterChips({
    super.key,
    required this.selectedCategory,
    required this.categories,
    required this.onCategorySelected,
    this.chipHeight = 40,
    this.chipSpacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final isSelected = selectedCategory == category;

          return Padding(
            padding: EdgeInsets.only(right: chipSpacing),
            child: GestureDetector(
              onTap: () => onCategorySelected(category),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.getPrimary(context)
                      : AppTheme.getCardColor(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.getPrimary(context)
                        : AppTheme.getBorderColor(context),
                  ),
                ),
                child: Center(
                  child: category == 'Saved'
                      ? Icon(
                          Icons.bookmark,
                          size: 16,
                          color: isSelected
                              ? (AppTheme.isDark(context)
                                    ? AppTheme.whiteText
                                    : AppTheme.darkText)
                              : AppTheme.getMutedColor(context),
                        )
                      : Text(
                          category,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? (AppTheme.isDark(context)
                                      ? AppTheme.whiteText
                                      : AppTheme.darkText)
                                : AppTheme.getMutedColor(context),
                          ),
                        ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
