#!/bin/bash

# 训宠响片音效文件快速设置脚本
# 此脚本会将现有的 click.mp3 复制三份作为默认项目的音效

echo "🎵 开始设置训宠响片音效文件..."

# 检查源文件是否存在
if [ ! -f "assets/click.mp3" ]; then
    echo "❌ 错误: 找不到 assets/click.mp3 文件"
    echo "请确保您在项目根目录下执行此脚本"
    exit 1
fi

# 确保 mp3 目录存在
mkdir -p assets/mp3

# 复制音效文件
echo "📁 复制音效文件到 assets/mp3/ 目录..."
cp assets/click.mp3 assets/mp3/喂食.mp3
cp assets/click.mp3 assets/mp3/握手.mp3
cp assets/click.mp3 assets/mp3/坐下.mp3

echo "✅ 音效文件设置完成！"
echo ""
echo "已创建以下文件："
echo "  - assets/mp3/喂食.mp3"
echo "  - assets/mp3/握手.mp3"
echo "  - assets/mp3/坐下.mp3"
echo ""
echo "💡 提示："
echo "1. 您可以替换这些文件为不同的音效"
echo "2. 添加自定义训练项目时，请在 assets/mp3/ 目录下添加对应的音效文件"
echo "3. 文件名必须与训练项目名称完全一致"
echo ""
echo "🚀 下一步: 运行 'flutter run' 重新启动应用"
