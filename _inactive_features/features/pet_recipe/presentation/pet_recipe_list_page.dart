import 'package:flutter/material.dart';
import '../../../shared/models/pet_recipe.dart';
import 'pet_recipe_detail_page.dart';

// 使用与主页面一致的颜色方案
class RecipeColors {
  static const Color background = Color(0xFFF8F8F8);
  static const Color primaryBlue = Color(0xFF5A8EFA);
  static const Color primaryPurple = Color(0xFF8B77FF);
  static const Color darkText = Color(0xFF1E1E1E);
  static const Color mediumText = Color(0xFF424242);
  static const Color lightGrey = Color(0xFFF0F2F5);
  static const Color cardBackground = Colors.white;
  static const Color accentOrange = Color(0xFFFFB74D);
  static const Color accentPink = Color(0xFFFF8A80);
}

/// 宠物食谱列表页面
class PetRecipeListPage extends StatefulWidget {
  const PetRecipeListPage({super.key});

  @override
  State<PetRecipeListPage> createState() => _PetRecipeListPageState();
}

class _PetRecipeListPageState extends State<PetRecipeListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RecipeColors.background,
      appBar: AppBar(
        backgroundColor: RecipeColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: RecipeColors.darkText,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '宠物食谱',
          style: TextStyle(
            color: RecipeColors.darkText,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          // 标签栏
          _buildTabBar(),
          const SizedBox(height: 20),
          // 食谱列表
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecipeList(RecipeData.getCatRecipes()),
                _buildRecipeList(RecipeData.getDogRecipes()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 60),
      height: 50,
      decoration: BoxDecoration(
        color: RecipeColors.lightGrey,
        borderRadius: BorderRadius.circular(25),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [RecipeColors.primaryBlue, RecipeColors.primaryPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: RecipeColors.primaryBlue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: RecipeColors.mediumText,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: '猫咪食谱'),
          Tab(text: '狗狗食谱'),
        ],
      ),
    );
  }

  Widget _buildRecipeList(List<PetRecipe> recipes) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        // 顶部介绍卡片
        _buildHeaderCard(),
        const SizedBox(height: 24),
        // 食谱网格
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            return _buildRecipeCard(recipes[index]);
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB74D), Color(0xFFFF8A80)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB74D).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(Icons.restaurant_menu, size: 32, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '健康减脂食谱',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '科学配比 营养均衡',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(PetRecipe recipe) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PetRecipeDetailPage(recipe: recipe),
          ),
        );
      },
      child: Container(
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 热量标签
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: RecipeColors.accentOrange,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: RecipeColors.accentOrange.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    recipe.calories,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              // 食谱信息
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: RecipeColors.darkText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recipe.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: RecipeColors.mediumText.withOpacity(0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // 脂肪信息
                  Row(
                    children: [
                      Icon(
                        Icons.water_drop_outlined,
                        size: 14,
                        color: RecipeColors.primaryBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        recipe.fat,
                        style: TextStyle(
                          fontSize: 12,
                          color: RecipeColors.mediumText.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
