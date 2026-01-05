#!/bin/bash

# gitback.sh - 回滚Vivado生成的文件但保留源代码变化
# 作者: Albert
# 日期: 2025-07-25

echo "=== FPGA项目回滚脚本 ==="
echo "此脚本将回滚以下Vivado生成的文件夹："
echo "  - Tiny_FPGA.cache"
echo "  - Tiny_FPGA.hw" 
echo "  - Tiny_FPGA.ip_user_files"
echo "  - Tiny_FPGA.runs"
echo "  - Tiny_FPGA.sim"
echo "  - Tiny_FPGA.xpr"
echo ""
echo "但会保留 Tiny_FPGA.srcs 文件夹的变化"
echo ""

# 检查是否在git仓库中
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "错误: 当前目录不是git仓库！"
    exit 1
fi

echo "当前工作目录: $(pwd)"
echo ""

# 显示当前git状态
echo "=== 当前git状态 ==="
git status --porcelain | grep -E "(Tiny_FPGA\.(cache|hw|ip_user_files|runs|sim|xpr)|Tiny_FPGA\.srcs)" || echo "没有相关文件的变化"
echo ""

# 显示未跟踪的文件
echo "=== 未跟踪的文件 ==="
untracked_files=$(git status --porcelain | grep "^??" | grep -E "Tiny_FPGA\.(cache|hw|ip_user_files|runs|sim|xpr)" | cut -c4-)
if [ -n "$untracked_files" ]; then
    echo "以下未跟踪的文件将被删除："
    echo "$untracked_files" | sed 's/^/  - /'
else
    echo "没有需要删除的未跟踪文件"
fi
echo ""

# 确认操作
read -p "确认要回滚这些文件夹吗？(包括删除未跟踪的文件) (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "操作已取消。"
    exit 0
fi

echo ""
echo "开始回滚操作..."

# 定义要回滚的文件夹列表
folders_to_rollback=(
    "Tiny_FPGA.cache"
    "Tiny_FPGA.hw"
    "Tiny_FPGA.ip_user_files"
    "Tiny_FPGA.runs"
    "Tiny_FPGA.sim"
    "Tiny_FPGA.xpr"
)

# 回滚每个文件夹
for folder in "${folders_to_rollback[@]}"; do
    if [ -e "$folder" ]; then
        echo "回滚文件夹: $folder"
        git checkout -- "$folder"
        if [ $? -eq 0 ]; then
            echo "  ✓ 成功回滚 $folder"
        else
            echo "  ✗ 回滚 $folder 失败"
        fi
    else
        echo "跳过不存在的文件夹: $folder"
    fi
done

# 删除未跟踪的文件
echo ""
echo "删除未跟踪的文件..."
for folder in "${folders_to_rollback[@]}"; do
    if [ -d "$folder" ]; then
        # 使用git clean删除未跟踪的文件和目录
        echo "清理未跟踪文件: $folder"
        git clean -fd "$folder" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "  ✓ 成功清理 $folder"
        else
            echo "  - $folder 无需清理"
        fi
    fi
done

echo ""
echo "=== 回滚完成 ==="

# 显示回滚后的状态
echo "=== 回滚后的git状态 ==="
git status --porcelain | grep -E "(Tiny_FPGA\.(cache|hw|ip_user_files|runs|sim|xpr)|Tiny_FPGA\.srcs)" || echo "没有相关文件的变化"

echo ""
echo "注意: Tiny_FPGA.srcs 文件夹的变化已被保留"
echo "如果需要查看完整的git状态，请运行: git status" 