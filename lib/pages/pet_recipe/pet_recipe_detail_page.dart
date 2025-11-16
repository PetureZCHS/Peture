import 'package:flutter/material.dart';
import '../../models/pet_recipe.dart';

// 使用与主页面一致的颜色方案
class RecipeDetailColors {
  static const Color background = Color(0xFFF8F8F8);
  static const Color primaryBlue = Color(0xFF5A8EFA);
  static const Color primaryPurple = Color(0xFF8B77FF);
  static const Color darkText = Color(0xFF1E1E1E);
  static const Color mediumText = Color(0xFF424242);
  static const Color lightGrey = Color(0xFFF0F2F5);
  static const Color cardBackground = Colors.white;
  static const Color accentOrange = Color(0xFFFFB74D);
}

/// 宠物食谱详情页面
class PetRecipeDetailPage extends StatelessWidget {
  final PetRecipe recipe;

  const PetRecipeDetailPage({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RecipeDetailColors.background,
      appBar: AppBar(
        backgroundColor: RecipeDetailColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: RecipeDetailColors.darkText,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          recipe.name,
          style: const TextStyle(
            color: RecipeDetailColors.darkText,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部食物图片和信息卡片
              _buildHeaderCard(),
              const SizedBox(height: 24),
              // 营养信息
              _buildInfoSection(
                title: '营养成分',
                icon: Icons.eco_outlined,
                content: _buildNutritionContent(),
                gradient: const LinearGradient(
                  colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
                ),
              ),
              const SizedBox(height: 16),
              // 食材
              _buildInfoSection(
                title: '所需食材',
                icon: Icons.shopping_basket_outlined,
                content: _buildIngredientsContent(),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
                ),
              ),
              const SizedBox(height: 16),
              // 做法
              _buildInfoSection(
                title: '制作步骤',
                icon: Icons.menu_book_outlined,
                content: _buildInstructionsContent(),
                gradient: const LinearGradient(
                  colors: [
                    RecipeDetailColors.primaryBlue,
                    RecipeDetailColors.primaryPurple,
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 适合
              _buildInfoSection(
                title: '适用对象',
                icon: Icons.pets_outlined,
                content: _buildSuitableForContent(),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8A80), Color(0xFFFF5252)],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 食谱名称
          Text(
            recipe.name,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: RecipeDetailColors.darkText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // 描述标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  RecipeDetailColors.primaryBlue,
                  RecipeDetailColors.primaryPurple,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              recipe.description,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 热量和脂肪信息
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildInfoChip(
                icon: Icons.local_fire_department,
                label: recipe.calories,
                color: RecipeDetailColors.accentOrange,
              ),
              const SizedBox(width: 12),
              _buildInfoChip(
                icon: Icons.water_drop_outlined,
                label: recipe.fat,
                color: RecipeDetailColors.primaryBlue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required Widget content,
    required Gradient gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // 内容区域
          Padding(padding: const EdgeInsets.all(16), child: content),
        ],
      ),
    );
  }

  Widget _buildNutritionContent() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: recipe.nutrition.entries.map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: RecipeDetailColors.lightGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${entry.key}: ${entry.value}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: RecipeDetailColors.darkText,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIngredientsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: recipe.ingredients.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: RecipeDetailColors.accentOrange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: RecipeDetailColors.darkText,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                entry.value,
                style: TextStyle(
                  fontSize: 15,
                  color: RecipeDetailColors.mediumText.withOpacity(0.8),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInstructionsContent() {
    return Text(
      recipe.instructions,
      style: const TextStyle(
        fontSize: 15,
        color: RecipeDetailColors.darkText,
        height: 1.6,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildSuitableForContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RecipeDetailColors.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        recipe.suitableFor,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: RecipeDetailColors.darkText,
        ),
      ),
    );
  }
}
