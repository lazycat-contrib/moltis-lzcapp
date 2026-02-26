#!/bin/bash
set -e

# ============================================================
# Moltis - 懒猫应用构建发布脚本
# ============================================================

APP_NAME="moltis"
VERSION="1.0.0"
LPK_FILE="${APP_NAME}-${VERSION}.lpk"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查必要文件
check_files() {
    local missing=0
    for f in lzc-manifest.yml lzc-build.yml icon.png; do
        if [ ! -f "$f" ]; then
            print_error "缺少文件: $f"
            missing=1
        fi
    done
    if [ $missing -eq 1 ]; then
        print_error "请确保所有必要文件存在"
        exit 1
    fi
    print_success "所有必要文件已就绪"
}

# 检查登录状态
check_login() {
    if ! lzc-cli appstore my-images &> /dev/null 2>&1; then
        print_warning "未登录懒猫应用商店"
        print_info "请先执行: lzc-cli appstore login"
        return 1
    fi
    print_success "已登录懒猫应用商店"
    return 0
}

# 构建应用
build_app() {
    print_info "正在构建 ${LPK_FILE} ..."
    check_files
    lzc-cli project build -o "${LPK_FILE}"
    print_success "构建完成: ${LPK_FILE}"
}

# 复制镜像到懒猫仓库
copy_image() {
    check_login || return 1

    local original_image="ghcr.io/moltis-org/moltis:latest"
    print_info "正在复制镜像: ${original_image}"

    local result
    result=$(lzc-cli appstore copy-image "${original_image}" 2>&1)
    echo "$result"

    local new_image
    new_image=$(echo "$result" | grep "^uploaded:" | awk '{print $2}')

    if [ -z "$new_image" ]; then
        print_error "未能获取新镜像地址"
        return 1
    fi

    print_success "镜像已上传: ${new_image}"

    # 更新 manifest 文件
    update_manifest_image "$new_image" "$original_image"
}

# 更新 manifest 中的镜像
update_manifest_image() {
    local new_image="$1"
    local original_image="$2"

    for manifest in lzc-manifest.yml manifest.yml; do
        if [ -f "$manifest" ]; then
            print_info "正在更新 ${manifest} ..."
            sed -i "s|image: ${original_image}|# ${original_image}\n    image: ${new_image}|g" "$manifest"
            sed -i "s|image: registry\.lazycat\.cloud/[^ ]*|image: ${new_image}|g" "$manifest"
            print_success "${manifest} 已更新"
        fi
    done
}

# 发布到应用商店
publish_app() {
    check_login || return 1

    if [ ! -f "${LPK_FILE}" ]; then
        print_error "未找到 ${LPK_FILE}，请先构建"
        return 1
    fi

    print_info "正在发布 ${LPK_FILE} ..."
    lzc-cli appstore publish "${LPK_FILE}"
    print_success "发布完成！请等待审核 (1-3 天)"
}

# 一键构建+镜像复制+发布
one_click_publish() {
    echo ""
    print_info "======== 阶段 1: 初始构建（原始镜像）========"
    build_app

    echo ""
    print_info "======== 阶段 2: 镜像复制 + 更新 manifest ========"
    copy_image || return 1

    echo ""
    print_info "======== 阶段 3: 重新构建（新镜像）========"
    build_app

    echo ""
    print_info "======== 阶段 4: 发布到应用商店 ========"
    publish_app
}

# 查看应用信息
show_info() {
    echo ""
    echo "============================================"
    echo "  应用名称: Moltis"
    echo "  包名:     cloud.lazycat.app.moltis"
    echo "  版本:     ${VERSION}"
    echo "  镜像:     ghcr.io/moltis-org/moltis:latest"
    echo "  端口:     13131"
    echo "  子域名:   moltis"
    echo "============================================"
    echo ""
    echo "文件列表:"
    ls -la lzc-manifest.yml lzc-build.yml icon.png 2>/dev/null || true
    echo ""
}

# 主菜单
show_menu() {
    echo ""
    echo "=========================================="
    echo "  Moltis 懒猫应用发布工具"
    echo "=========================================="
    echo "  1. 📦 构建应用 (Build)"
    echo "  2. 🔧 镜像复制到懒猫仓库 (Copy Image)"
    echo "  3. 📤 发布到应用商店 (Publish)"
    echo "  4. 🚀 一键构建+镜像复制+发布 (One-Click)"
    echo "  5. 📋 查看应用信息 (Info)"
    echo "  6. ❌ 退出"
    echo "=========================================="
    echo -n "请选择 [1-6]: "
}

# 主循环
main() {
    cd "$(dirname "$0")"

    while true; do
        show_menu
        read -r choice
        case $choice in
            1) build_app ;;
            2) copy_image ;;
            3) publish_app ;;
            4) one_click_publish ;;
            5) show_info ;;
            6) echo "再见！"; exit 0 ;;
            *) print_error "无效选择" ;;
        esac
    done
}

main "$@"
