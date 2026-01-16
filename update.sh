#!/bin/bash

# ================= 配置区域 (Config) =================
# 这里定义源的元数据，显示在 Cydia/Sileo 的源详情页中
ORIGIN="YHX Source"
LABEL="YHX Repo"
SUITE="stable"
VERSION="1.0"
CODENAME="yhx"
# 关键修改：明确列出支持的所有架构，包括 arm64 (无根) 和 arm64e (隐根)
ARCHITECTURES="iphoneos-arm iphoneos-arm64 iphoneos-arm64e"
COMPONENTS="main"
DESCRIPTION="YHX.CH - Metal & Water Energy Source"
# ====================================================

# 1. 清理旧索引文件
# 删除旧的 Packages 和 Release 文件，防止残留数据干扰
echo "[-] Cleaning up old files..."
rm -f Packages Packages.bz2 Packages.gz Release

# 2. 生成 Packages 索引 (核心步骤)
# -m : 允许“多版本/多架构”共存。如果不加这个，同包名的 arm64e 可能会被忽略。
echo "[-] Scanning debs (Multiversion Mode)..."
dpkg-scanpackages -m debs > Packages

# 3. 压缩索引文件
# 生成 .bz2 (Cydia 标准) 和 .gz (Sileo/APT 兼容)
echo "[-] Compressing Packages..."
bzip2 -f -k Packages
gzip -f -k Packages

# 4. 生成 Release 文件头
# 写入源的基本描述信息
echo "[-] Generating Release header..."
cat <<EOF > Release
Origin: $ORIGIN
Label: $LABEL
Suite: $SUITE
Version: $VERSION
Codename: $CODENAME
Architectures: $ARCHITECTURES
Components: $COMPONENTS
Description: $DESCRIPTION
EOF

# 5. 计算并追加哈希校验和 (MD5, SHA1, SHA256)
# 现代包管理器 (Sileo/Zebra) 强制要求 SHA256，否则会报错或无法刷新
echo "[-] Calculating Hashes..."

# 定义哈希生成函数
generate_hash() {
    HASH_NAME=$1
    HASH_CMD=$2
    
    echo "$HASH_NAME:" >> Release
    # 遍历生成的三个索引文件
    for file in Packages Packages.bz2 Packages.gz; do
        if [ -f "$file" ]; then
            # 计算哈希值 (使用 awk 提取第一列的 hash 字符串)
            HASH=$($HASH_CMD "$file" | awk '{print $1}')
            # 获取文件大小 (字节)
            SIZE=$(stat -f%z "$file")
            # 格式： <哈希> <大小> <文件名> (注意前面有个空格)
            echo " $HASH $SIZE $file" >> Release
        fi
    done
}

# 执行哈希计算
generate_hash "MD5Sum" "md5 -q"
generate_hash "SHA1" "shasum -a 1"
generate_hash "SHA256" "shasum -a 256"

# 6. Git 提交与推送
echo "[-] Pushing to GitHub..."
git add .
git commit -m "Repo Update: $(date +'%Y-%m-%d %H:%M:%S')"
git push

echo "[ok] Done! Repo updated successfully."
echo "[!] Please wait 1-2 minutes for GitHub Pages to deploy."
