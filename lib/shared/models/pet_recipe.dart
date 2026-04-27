/// 宠物食谱模型
class PetRecipe {
  final String id;
  final String name; // 食谱名称
  final String calories; // 热量
  final String fat; // 脂肪含量
  final String description; // 简短描述
  final String imageUrl; // 图片路径
  final RecipeType type; // 猫猫食谱或狗狗食谱

  // 详细信息
  final Map<String, String> nutrition; // 营养成分
  final Map<String, String> ingredients; // 食材
  final String instructions; // 做法
  final String suitableFor; // 适合

  PetRecipe({
    required this.id,
    required this.name,
    required this.calories,
    required this.fat,
    required this.description,
    required this.imageUrl,
    required this.type,
    required this.nutrition,
    required this.ingredients,
    required this.instructions,
    required this.suitableFor,
  });
}

enum RecipeType {
  cat, // 猫猫食谱
  dog, // 狗狗食谱
}

/// 示例数据
class RecipeData {
  static List<PetRecipe> getCatRecipes() {
    return [
      PetRecipe(
        id: 'cat_1',
        name: '猪肝菠菜泥',
        calories: '45kcal',
        fat: '约0.4g',
        description: '补血营养素组合',
        imageUrl: 'assets/recipes/cat_liver_spinach.png',
        type: RecipeType.cat,
        nutrition: {'热量': '45kcal', '铁': '4mg'},
        ingredients: {'猪肝': '10g', '菠菜': '10g'},
        instructions: '猪肝煮熟切小块，菠菜烫水挤干水分，两者放入搅拌机，加适量高汤打成顺滑肝泥',
        suitableFor: '孕产期母猫、贫血恢复期',
      ),
      PetRecipe(
        id: 'cat_2',
        name: '虾肉西兰花泥',
        calories: '50kcal',
        fat: '约0.3g',
        description: '高蛋白低脂 促进消化',
        imageUrl: 'assets/recipes/cat_shrimp_broccoli.png',
        type: RecipeType.cat,
        nutrition: {'热量': '50kcal', '蛋白质': '8g'},
        ingredients: {'虾肉': '15g', '西兰花': '10g'},
        instructions: '虾肉去壳煮熟，西兰花蒸熟，两者放入搅拌机打成泥状',
        suitableFor: '幼猫、需要补充蛋白质的猫',
      ),
      PetRecipe(
        id: 'cat_3',
        name: '蛋黄鸡丝罐头',
        calories: '120kcal',
        fat: '约5g',
        description: '优质蛋白 支持幼猫猛长',
        imageUrl: 'assets/recipes/cat_egg_chicken.png',
        type: RecipeType.cat,
        nutrition: {'热量': '120kcal', '蛋白质': '15g'},
        ingredients: {'鸡胸肉': '30g', '蛋黄': '1个'},
        instructions: '鸡胸肉煮熟撕成丝，蛋黄煮熟碾碎，混合均匀即可',
        suitableFor: '幼猫、孕期母猫',
      ),
      PetRecipe(
        id: 'cat_4',
        name: '鸡肉豆腐营养餐',
        calories: '180kcal',
        fat: '约6g',
        description: '高蛋白低脂 柔软易消化',
        imageUrl: 'assets/recipes/cat_chicken_tofu.png',
        type: RecipeType.cat,
        nutrition: {'热量': '180kcal', '蛋白质': '20g'},
        ingredients: {'鸡胸肉': '40g', '豆腐': '20g', '胡萝卜': '5g'},
        instructions: '鸡胸肉煮熟切丁，豆腐蒸熟压碎，胡萝卜煮软切碎，混合均匀',
        suitableFor: '成猫、老年猫',
      ),
      PetRecipe(
        id: 'cat_5',
        name: '鱼肉土豆羹',
        calories: '80kcal',
        fat: '约2g',
        description: '低致敏性 易消化',
        imageUrl: 'assets/recipes/cat_fish_potato.png',
        type: RecipeType.cat,
        nutrition: {'热量': '80kcal', '蛋白质': '10g'},
        ingredients: {'鱼肉': '25g', '土豆': '15g'},
        instructions: '鱼肉去刺煮熟，土豆蒸熟，一起打成羹状',
        suitableFor: '肠胃敏感的猫',
      ),
      PetRecipe(
        id: 'cat_6',
        name: '兔肉苹果泥',
        calories: '60kcal',
        fat: '约1.5g',
        description: '高消化 低负担',
        imageUrl: 'assets/recipes/cat_rabbit_apple.png',
        type: RecipeType.cat,
        nutrition: {'热量': '60kcal', '蛋白质': '9g'},
        ingredients: {'兔肉': '20g', '苹果': '10g'},
        instructions: '兔肉煮熟切碎，苹果去皮蒸软，一起打成泥',
        suitableFor: '减肥期猫咪、易过敏体质',
      ),
    ];
  }

  static List<PetRecipe> getDogRecipes() {
    return [
      PetRecipe(
        id: 'dog_1',
        name: '牛肉胡萝卜饭',
        calories: '150kcal',
        fat: '约5g',
        description: '高蛋白 补充体力',
        imageUrl: 'assets/recipes/dog_beef_carrot.png',
        type: RecipeType.dog,
        nutrition: {'热量': '150kcal', '蛋白质': '18g'},
        ingredients: {'牛肉': '50g', '胡萝卜': '20g', '米饭': '30g'},
        instructions: '牛肉切块煮熟，胡萝卜切丁煮软，与米饭混合即可',
        suitableFor: '活跃期狗狗、需要补充体力',
      ),
      PetRecipe(
        id: 'dog_2',
        name: '鸡肉南瓜粥',
        calories: '100kcal',
        fat: '约3g',
        description: '养胃易消化',
        imageUrl: 'assets/recipes/dog_chicken_pumpkin.png',
        type: RecipeType.dog,
        nutrition: {'热量': '100kcal', '蛋白质': '12g'},
        ingredients: {'鸡胸肉': '40g', '南瓜': '30g', '大米': '20g'},
        instructions: '鸡胸肉煮熟撕碎，南瓜蒸熟压成泥，与煮好的大米粥混合',
        suitableFor: '肠胃不适的狗狗、老年犬',
      ),
      PetRecipe(
        id: 'dog_3',
        name: '三文鱼甘薯餐',
        calories: '130kcal',
        fat: '约6g',
        description: '美毛护肤 营养均衡',
        imageUrl: 'assets/recipes/dog_salmon_sweet_potato.png',
        type: RecipeType.dog,
        nutrition: {'热量': '130kcal', '蛋白质': '15g', 'Omega-3': '丰富'},
        ingredients: {'三文鱼': '45g', '甘薯': '25g', '西兰花': '10g'},
        instructions: '三文鱼蒸熟去骨，甘薯蒸熟切块，西兰花焯水，混合即可',
        suitableFor: '需要美毛的狗狗、皮肤敏感犬',
      ),
      PetRecipe(
        id: 'dog_4',
        name: '羊肉蔬菜煲',
        calories: '160kcal',
        fat: '约7g',
        description: '温补暖身 增强免疫',
        imageUrl: 'assets/recipes/dog_lamb_vegetables.png',
        type: RecipeType.dog,
        nutrition: {'热量': '160kcal', '蛋白质': '16g'},
        ingredients: {'羊肉': '50g', '胡萝卜': '15g', '白菜': '15g'},
        instructions: '羊肉切块煮熟，胡萝卜和白菜切碎煮软，一起炖煮即可',
        suitableFor: '冬季进补、体质虚弱的狗狗',
      ),
      PetRecipe(
        id: 'dog_5',
        name: '火鸡肉藜麦饭',
        calories: '140kcal',
        fat: '约4g',
        description: '低脂高营养 控制体重',
        imageUrl: 'assets/recipes/dog_turkey_quinoa.png',
        type: RecipeType.dog,
        nutrition: {'热量': '140kcal', '蛋白质': '17g'},
        ingredients: {'火鸡肉': '45g', '藜麦': '25g', '豌豆': '10g'},
        instructions: '火鸡肉煮熟切丁，藜麦煮熟，豌豆煮软，混合均匀',
        suitableFor: '需要减肥的狗狗、糖尿病犬',
      ),
      PetRecipe(
        id: 'dog_6',
        name: '鸭肉土豆泥',
        calories: '120kcal',
        fat: '约5g',
        description: '降火滋阴 清热解毒',
        imageUrl: 'assets/recipes/dog_duck_potato.png',
        type: RecipeType.dog,
        nutrition: {'热量': '120kcal', '蛋白质': '14g'},
        ingredients: {'鸭肉': '40g', '土豆': '30g'},
        instructions: '鸭肉煮熟切碎，土豆蒸熟压成泥，混合均匀',
        suitableFor: '上火体质的狗狗、夏季食用',
      ),
    ];
  }

  static List<PetRecipe> getAllRecipes() {
    return [...getCatRecipes(), ...getDogRecipes()];
  }
}
