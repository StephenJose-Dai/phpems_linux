#!/bin/bash

# ============================================================
#  phpems 一键部署脚本
#  支持系统：CentOS 7/8/9/10/Stream、Ubuntu、Alpine 等主流 Linux
# ============================================================

set -e

# ---------- 颜色定义 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
title()   { echo -e "\n${BOLD}${CYAN}========== $* ==========${NC}\n"; }

COMPOSE_URL="https://github.com/StephenJose-Dai/phpems_linux/releases/download/20260226_11/docker-compose.yml"
COMPOSE_FILE="/root/docker-compose.yml"

# ============================================================
# 第一步：检测系统版本与架构
# ============================================================
title "步骤 1/6  检测系统与架构"

ARCH=$(uname -m)
SUPPORTED_ARCH=("x86_64" "aarch64" "arm64")
ARCH_OK=false
for a in "${SUPPORTED_ARCH[@]}"; do
    [[ "$ARCH" == "$a" ]] && ARCH_OK=true && break
done

if ! $ARCH_OK; then
    error "当前架构 ${ARCH} 不在受支持的列表中（支持：x86_64 / aarch64 / arm64），脚本终止。"
    exit 1
fi

OS_ID=""
OS_VERSION=""
OS_NAME=""

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID,,}"
    OS_VERSION="${VERSION_ID}"
    OS_NAME="${PRETTY_NAME}"
elif [ -f /etc/alpine-release ]; then
    OS_ID="alpine"
    OS_VERSION=$(cat /etc/alpine-release)
    OS_NAME="Alpine Linux ${OS_VERSION}"
else
    error "无法识别当前操作系统，脚本终止。"
    exit 1
fi

SUPPORTED_OS=("centos" "rhel" "rocky" "almalinux" "fedora" "ubuntu" "debian" "alpine" "opensuse" "sles")
OS_OK=false
for s in "${SUPPORTED_OS[@]}"; do
    [[ "$OS_ID" == "$s" ]] && OS_OK=true && break
done

if ! $OS_OK; then
    error "当前系统 ${OS_NAME}（ID: ${OS_ID}）不在受支持的列表中，脚本终止。"
    error "支持的系统：CentOS 7/8/9/10/Stream、RHEL、Rocky、AlmaLinux、Fedora、Ubuntu、Debian、Alpine、openSUSE"
    exit 1
fi

success "系统检测通过：${OS_NAME}，架构：${ARCH}"

# ============================================================
# 第二步：检查依赖工具
# ============================================================
title "步骤 2/6  检查依赖工具"

REQUIRED_TOOLS=("docker" "curl" "git" "unzip" "zip" "wget")
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        MISSING_TOOLS+=("$tool")
    fi
done

DOCKER_COMPOSE_CMD=""
if docker compose version &>/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    MISSING_TOOLS+=("docker-compose")
fi

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    error "当前系统缺少以下工具，请手动安装后再重新执行脚本："
    for t in "${MISSING_TOOLS[@]}"; do
        echo -e "  ${RED}✗${NC} $t"
    done
    echo ""
    case "$OS_ID" in
        centos|rhel|rocky|almalinux|fedora)
            warn "安装参考命令：yum install -y ${MISSING_TOOLS[*]}"
            ;;
        ubuntu|debian)
            warn "安装参考命令：apt-get install -y ${MISSING_TOOLS[*]}"
            ;;
        alpine)
            warn "安装参考命令：apk add ${MISSING_TOOLS[*]}"
            ;;
    esac
    exit 1
fi

success "所有依赖工具检测通过"
info "使用 Docker Compose 命令：${DOCKER_COMPOSE_CMD}"

# ============================================================
# 第三步：检查并补全 /data 目录结构
# ============================================================
title "步骤 3/6  检查 /data 目录结构"

REQUIRED_DIRS=(
    "/data/mysql"
    "/data/nginx/logs"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        warn "目录 ${dir} 不存在，正在创建..."
        mkdir -p "$dir"
        success "已创建：${dir}"
    else
        success "目录已存在：${dir}"
    fi
done

# ============================================================
# 第四步：克隆 phpems11 仓库并修改配置
# ============================================================
title "步骤 4/6  部署 phpems11 源码"

if [ -d "/data/phpems" ] || [ -d "/data/phpems11" ]; then
    error "检测到 /data 目录下已存在 phpems 或 phpems11 文件夹！"
    error "请先将该文件夹重命名后，再重新执行此脚本。"
    error "例如：mv /data/phpems11 /data/phpems11_bak"
    exit 1
fi

info "正在克隆 phpems11 仓库到 /data/phpems11 ..."
git clone https://github.com/redrangon/phpems11.git /data/phpems11

if [ ! -d "/data/phpems11" ]; then
    error "克隆失败，请检查网络或 git 配置后重试。"
    exit 1
fi
success "仓库克隆完成"

# 赋予权限
chmod -R 777 /data/phpems11
success "已赋予 /data/phpems11 目录 777 权限"

CONFIG_FILE="/data/phpems11/lib/config.inc.php"
if [ -f "$CONFIG_FILE" ]; then
    sed -i "s/define('DH','127.0.0.1')/define('DH','phpems_mysql')/" "$CONFIG_FILE"
    success "已修改数据库连接地址：127.0.0.1 → phpems_mysql"
else
    warn "未找到配置文件 ${CONFIG_FILE}，请手动修改数据库连接地址。"
fi

# ============================================================
# 第五步：选择镜像来源
# ============================================================
title "步骤 5/6  选择镜像来源"

PHP_IMAGE="stephenjose/phpems_php:7.4"
NGINX_IMAGE="stephenjose/phpems_nginx:1.29.5"
MYSQL_IMAGE="stephenjose/phpems_mysql:8.4"

choose_image_source() {
    while true; do
        echo ""
        echo "请选择镜像来源："
        echo "  1) 在线拉取镜像（需要配置代理）"
        echo "  2) 本地导入镜像"
        echo ""
        read -rp "请输入选项 [1/2]：" SOURCE_CHOICE

        case "$SOURCE_CHOICE" in
            1)
                warn "【注意】在线拉取镜像需要配置代理，否则可能出现拉取失败的情况。"
                warn "代理配置文档请参考：https://mp.weixin.qq.com/s/LXal8PCCYHRPtFDxVmkOYw"
                echo ""
                read -rp "确认使用在线拉取方式？[y/N]：" CONFIRM
                case "$CONFIRM" in
                    y|Y)
                        info "开始在线拉取镜像..."
                        docker pull "$PHP_IMAGE"
                        docker pull "$NGINX_IMAGE"
                        docker pull "$MYSQL_IMAGE"
                        success "所有镜像拉取完成"
                        break
                        ;;
                    *)
                        warn "已取消，返回上一步重新选择..."
                        continue
                        ;;
                esac
                ;;
            2)
                echo ""
                read -rp "请输入镜像包所在目录的完整路径（例如 /opt/images）：" IMAGE_DIR

                if [ ! -d "$IMAGE_DIR" ]; then
                    error "目录 ${IMAGE_DIR} 不存在，请重新输入。"
                    continue
                fi

                mapfile -t IMAGE_FILES < <(find "$IMAGE_DIR" -maxdepth 1 -type f \( -name "*.tar" -o -name "*.tar.gz" -o -name "*.tgz" \))

                if [ ${#IMAGE_FILES[@]} -eq 0 ]; then
                    error "在 ${IMAGE_DIR} 目录下未找到任何镜像包（.tar / .tar.gz / .tgz），请重新输入。"
                    continue
                fi

                info "在 ${IMAGE_DIR} 下找到以下镜像包，共 ${#IMAGE_FILES[@]} 个："
                for f in "${IMAGE_FILES[@]}"; do
                    echo "  - $(basename "$f")"
                done
                echo ""

                for IMAGE_FILE in "${IMAGE_FILES[@]}"; do
                    info "正在导入：$(basename "$IMAGE_FILE") ..."
                    LOADED_OUTPUT=$(docker load -i "$IMAGE_FILE" 2>&1)
                    echo "$LOADED_OUTPUT"
                    LOADED_IMAGE=$(echo "$LOADED_OUTPUT" | grep -oP '(?<=Loaded image: )\S+' | head -1)
                    if [ -n "$LOADED_IMAGE" ]; then
                        success "已导入镜像：${LOADED_IMAGE}"
                    else
                        success "镜像文件 $(basename "$IMAGE_FILE") 导入完成"
                    fi
                done

                success "所有镜像导入完成"
                break
                ;;
            *)
                warn "无效选项，请输入 1 或 2。"
                ;;
        esac
    done
}

choose_image_source

# ============================================================
# 第六步：下载 docker-compose.yml 并启动容器
# ============================================================
title "步骤 6/6  启动容器"

download_compose() {
    info "正在下载 docker-compose.yml ..."
    if wget -q --timeout=30 -O "$COMPOSE_FILE" "$COMPOSE_URL" 2>/dev/null; then
        success "docker-compose.yml 下载成功（wget）：${COMPOSE_FILE}"
        return 0
    elif curl -fsSL --connect-timeout 30 -o "$COMPOSE_FILE" "$COMPOSE_URL" 2>/dev/null; then
        success "docker-compose.yml 下载成功（curl）：${COMPOSE_FILE}"
        return 0
    else
        # 清理可能生成的空文件
        [ -f "$COMPOSE_FILE" ] && rm -f "$COMPOSE_FILE"
        return 1
    fi
}

if ! download_compose; then
    warn "下载失败，可能是网络不稳定，请检查网络后重试。"
    echo ""
    echo -e "  您也可以选择手动下载该文件，操作步骤如下："
    echo ""
    echo -e "  ${BOLD}1. 打开浏览器，输入以下地址下载文件：${NC}"
    echo -e "     ${CYAN}${COMPOSE_URL}${NC}"
    echo -e "  ${BOLD}2. 将下载的 docker-compose.yml 上传到服务器${NC}"
    echo -e "  ${BOLD}3. 记录文件存放的完整路径，填写到下方${NC}"
    echo ""

    while true; do
        read -rp "是否已手动下载并上传文件到服务器？[y/N]：" MANUAL_CONFIRM
        case "$MANUAL_CONFIRM" in
            y|Y)
                while true; do
                    read -rp "请输入 docker-compose.yml 文件的完整路径（例如 /root/docker-compose.yml）：" MANUAL_PATH
                    if [ ! -f "$MANUAL_PATH" ]; then
                        error "文件 ${MANUAL_PATH} 不存在，请确认路径后重新输入。"
                        continue
                    fi
                    if [ "$MANUAL_PATH" != "$COMPOSE_FILE" ]; then
                        cp "$MANUAL_PATH" "$COMPOSE_FILE"
                        success "已将文件复制到：${COMPOSE_FILE}"
                    else
                        success "文件路径正确：${COMPOSE_FILE}"
                    fi
                    break
                done
                break
                ;;
            *)
                error "请先完成文件下载和上传后，再重新执行脚本。"
                exit 1
                ;;
        esac
    done
fi

info "正在启动容器，请稍候..."
cd /root
$DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" up -d

sleep 3

RUNNING_CONTAINERS=$(docker ps --filter "name=phpems_" --format "{{.Names}}" | wc -l)
if [ "$RUNNING_CONTAINERS" -lt 3 ]; then
    warn "部分容器可能未正常启动，请执行以下命令检查："
    warn "  docker ps -a"
    warn "  $DOCKER_COMPOSE_CMD -f ${COMPOSE_FILE} logs"
fi

# 获取宿主机 IP（排除 lo、docker0、br-、veth 等虚拟网卡）
HOST_IP=$(ip -4 addr show scope global | \
    awk '/inet / {print $2, $NF}' | \
    while read -r cidr iface; do
        case "$iface" in
            lo|docker0|br-*|veth*)
                continue
                ;;
            *)
                echo "${cidr%%/*}"
                break
                ;;
        esac
    done)

if [ -z "$HOST_IP" ]; then
    HOST_IP="<your-server-ip>"
fi

# 输出访问信息
echo ""
echo -e "${BOLD}${GREEN}============================================================${NC}"
echo -e "${BOLD}${GREEN}  phpems 部署完成！以下信息仅显示一次，请妥善保存！${NC}"
echo -e "${BOLD}${GREEN}============================================================${NC}"
echo ""
echo -e "  ${BOLD}访问地址：${NC}    http://${HOST_IP}"
echo -e "  ${BOLD}管理后台：${NC}    http://${HOST_IP}/admin"
echo ""
echo -e "  ${BOLD}管理员账号：${NC}  peadmin"
echo -e "  ${BOLD}管理员密码：${NC}  peadmin"
echo ""
echo -e "  ${BOLD}数据库账号：${NC}  root"
echo -e "  ${BOLD}数据库密码：${NC}  Zdr5NSqnyjAPwNvL"
echo -e "  ${BOLD}数据库名称：${NC}  phpems11"
echo ""
echo -e "${BOLD}${YELLOW}  ⚠️  该信息只显示一次，请立即截图或记录！${NC}"
echo -e "${BOLD}${GREEN}============================================================${NC}"
echo ""
