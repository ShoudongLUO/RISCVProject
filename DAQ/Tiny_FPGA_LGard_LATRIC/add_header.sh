#!/usr/bin/env bash
# add_header.sh
# 在指定源文件开头插入统一版权/说明头。
# chmod +x add_header.sh && ./add_header.sh

#------------- 配置区 -------------#
HEADER='
/* ===========================================================
 *  Project      : Tiny_FPGA
 *  Unique Tag   : Auto‑generated header (do not remove this line!!!)
 *  Log（开发日志）:
    1. 2025-07-25 Created header by Albert
    2. ...
 * =========================================================== */'

# 扩展名列表，空格分隔
EXTENSIONS=("v" "sv" "svh")
#---------------------------------#

# 将扩展名拼成 find 的 -name 组合
build_find_expr () {
  local expr=""
  for ext in "${EXTENSIONS[@]}"; do
    expr+="-name '*.${ext}' -o "
  done
  # 删除最后一个 -o 和空格
  echo "${expr::-4}"
}

insert_header () {
  local file="$1"

  # 如果文件已经包含 Unique Tag，则跳过
  if grep -q "Auto‑generated header" "$file"; then
    printf "skip %s (header exists)\n" "$file"
    return
  fi

  # 创建临时文件，先写入头部，再写入原文件内容
  local temp_file=$(mktemp)
  echo "$HEADER" > "$temp_file"
  cat "$file" >> "$temp_file"
  mv "$temp_file" "$file"
  printf "added %s\n" "$file"
}

export HEADER
export -f insert_header      # 让子 shell 识别函数

# 直接使用硬编码的表达式
find . \( -name '*.v' -o -name '*.sv' -o -name '*.svh' \) -type f -print0 | xargs -0 -I{} bash -c 'insert_header "$@"' _ {}

echo "=== Done ==="
