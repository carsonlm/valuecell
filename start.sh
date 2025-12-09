#!/bin/bash
# ValueCell 项目启动脚本 (Linux/macOS)
# 这是一个智能启动脚本，会自动检查并安装必要的工具，然后启动前后端服务
# 使用方式：./start.sh [选项]

set -Eeuo pipefail
# 设置严格的错误处理：
# -E: 继承 ERR 陷阱
# -e: 遇到错误立即退出
# -u: 使用未定义变量时报错
# -o pipefail: 管道中任何命令失败都视为失败

# ============================================================================
# 目录和变量定义
# ============================================================================

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"

# 前端目录路径
FRONTEND_DIR="$SCRIPT_DIR/frontend"

# Python后端目录路径
PY_DIR="$SCRIPT_DIR/python"

# 进程ID变量，用于后续清理
BACKEND_PID=""
FRONTEND_PID=""

# ============================================================================
# 日志输出函数
# ============================================================================

# 信息级别日志（蓝色）
info()  { echo "[INFO]  $*"; }

# 成功级别日志（绿色）
success(){ echo "[ OK ]  $*"; }

# 警告级别日志（黄色）
warn()  { echo "[WARN]  $*"; }

# 错误级别日志（红色）
error() { echo "[ERR ]  $*" 1>&2; }

# ============================================================================
# 工具函数
# ============================================================================

# 检查命令是否存在
command_exists() { command -v "$1" >/dev/null 2>&1; }

# 在macOS上确保Homebrew已安装
ensure_brew_on_macos() {
  if [[ "${OSTYPE:-}" == darwin* ]]; then
    if ! command_exists brew; then
      error "Homebrew is not installed. Please install Homebrew: https://brew.sh/"
      error "Example install: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      exit 1
    fi
  fi
}

# 确保工具已安装，如果未安装则自动安装
ensure_tool() {
  local tool_name="$1"; shift
  local brew_formula="$1"; shift || true

  # 检查工具是否已安装
  if command_exists "$tool_name"; then
    success "$tool_name is installed ($($tool_name --version 2>/dev/null | head -n1 || echo version unknown))"
    return 0
  fi

  # 根据操作系统安装工具
  case "$(uname -s)" in
    Darwin)
      # macOS: 使用Homebrew安装
      ensure_brew_on_macos
      info "Installing $tool_name via Homebrew..."
      brew install "$brew_formula"
      ;;
    Linux)
      # Linux: 使用官方安装脚本
      info "Detected Linux, auto-installing $tool_name..."
      if [[ "$tool_name" == "bun" ]]; then
        # 安装Bun (JavaScript运行时)
        curl -fsSL https://bun.sh/install | bash
        # 将Bun添加到PATH（仅当前进程）
        if ! command_exists bun && [[ -x "$HOME/.bun/bin/bun" ]]; then
          export PATH="$HOME/.bun/bin:$PATH"
        fi
      elif [[ "$tool_name" == "uv" ]]; then
        # 安装uv (Python包管理器)
        curl -LsSf https://astral.sh/uv/install.sh | sh
        # 将uv添加到PATH（仅当前进程）
        if ! command_exists uv && [[ -x "$HOME/.local/bin/uv" ]]; then
          export PATH="$HOME/.local/bin:$PATH"
        fi
      else
        warn "Unknown tool: $tool_name"
      fi
      ;;
    *)
      # 其他操作系统：提示手动安装
      warn "$tool_name not installed. Auto-install is not provided on this OS. Please install manually and retry."
      exit 1
      ;;
  esac

  # 验证安装是否成功
  if command_exists "$tool_name"; then
    success "$tool_name installed successfully"
  else
    error "$tool_name installation failed. Please install manually and retry."
    exit 1
  fi
}

# ============================================================================
# 编译和依赖安装
# ============================================================================

compile() {
  # 后端依赖安装
  if [[ -d "$PY_DIR" ]]; then
    info "Sync Python dependencies (uv sync)..."
    # 进入Python目录并执行：
    # 1. 运行环境准备脚本
    # 2. 初始化数据库
    (cd "$PY_DIR" && bash scripts/prepare_envs.sh && uv run valuecell/server/db/init_db.py)
    success "Python dependencies synced"
  else
    warn "Backend directory not found: $PY_DIR. Skipping"
  fi

  # 前端依赖安装
  if [[ -d "$FRONTEND_DIR" ]]; then
    info "Install frontend dependencies (bun install)..."
    # 进入前端目录并使用bun安装依赖
    (cd "$FRONTEND_DIR" && bun install)
    success "Frontend dependencies installed"
  else
    warn "Frontend directory not found: $FRONTEND_DIR. Skipping"
  fi
}

# ============================================================================
# 服务启动函数
# ============================================================================

# 启动后端服务
start_backend() {
  if [[ ! -d "$PY_DIR" ]]; then
    warn "Backend directory not found; skipping backend start"
    return 0
  fi
  info "Starting backend in debug mode (AGENT_DEBUG_MODE=true)..."
  # 进入Python目录，设置调试模式并启动服务器
  cd "$PY_DIR" && AGENT_DEBUG_MODE=true uv run python -m valuecell.server.main
}

# 启动前端服务（在后台运行）
start_frontend() {
  if [[ ! -d "$FRONTEND_DIR" ]]; then
    warn "Frontend directory not found; skipping frontend start"
    return 0
  fi
  info "Starting frontend dev server (bun run dev)..."
  # 在前端目录中启动开发服务器，并记录进程ID
  (
    cd "$FRONTEND_DIR" && bun run dev
  ) & FRONTEND_PID=$!
  info "Frontend PID: $FRONTEND_PID"
}

# ============================================================================
# 清理函数
# ============================================================================

cleanup() {
  echo
  info "Stopping services..."
  # 停止前端进程（如果正在运行）
  if [[ -n "$FRONTEND_PID" ]] && kill -0 "$FRONTEND_PID" 2>/dev/null; then
    kill "$FRONTEND_PID" 2>/dev/null || true
  fi
  # 停止后端进程（如果正在运行）
  if [[ -n "$BACKEND_PID" ]] && kill -0 "$BACKEND_PID" 2>/dev/null; then
    kill "$BACKEND_PID" 2>/dev/null || true
  fi
  success "Stopped"
}

# 注册清理函数，在脚本退出时自动调用
trap cleanup EXIT INT TERM

# ============================================================================
# 使用说明
# ============================================================================

print_usage() {
  cat <<'EOF'
Usage: ./start.sh [options]

Description:
  - Checks whether bun and uv are installed; on macOS, missing tools will be auto-installed via Homebrew.
  - Then installs backend and frontend dependencies and starts services.
  - Environment variables are loaded from system path:
    * macOS: ~/Library/Application Support/ValueCell/.env
    * Linux: ~/.config/valuecell/.env
    * Windows: %APPDATA%\ValueCell\.env
  - The .env file will be auto-created from .env.example on first run.
  - Debug mode is automatically enabled (AGENT_DEBUG_MODE=true) for local development.

Options:
  --no-frontend   Start backend only
  --no-backend    Start frontend only
  -h, --help      Show help
EOF
}

# ============================================================================
# 主函数
# ============================================================================

main() {
  local start_frontend_flag=1
  local start_backend_flag=1

  # 解析命令行参数
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-frontend) start_frontend_flag=0; shift ;;
      --no-backend)  start_backend_flag=0; shift ;;
      -h|--help)     print_usage; exit 0 ;;
      *) error "Unknown argument: $1"; print_usage; exit 1 ;;
    esac
  done

  # 确保必要的工具已安装
  ensure_tool bun oven-sh/bun/bun  # Bun: JavaScript运行时和包管理器
  ensure_tool uv uv                # uv: Python包管理器

  # 安装依赖
  compile

  # 启动前端服务（如果启用）
  if (( start_frontend_flag )); then
    start_frontend
  fi
  sleep 5  # 给前端一些时间启动

  # 启动后端服务（如果启用）
  if (( start_backend_flag )); then
    start_backend
  fi

  # 等待后台作业完成
  wait
}

# 执行主函数
main "$@"

# ============================================================================
# 脚本详细说明
# ============================================================================
#
# 功能概述：
# 1. 环境检查：检查操作系统，确保必要的工具（bun, uv）已安装
# 2. 自动安装：如果工具未安装，根据操作系统自动安装
# 3. 依赖安装：安装前后端的所有依赖
# 4. 服务启动：启动开发服务器
# 5. 清理处理：优雅地停止服务
#
# 支持的操作系统：
# - macOS: 使用Homebrew安装工具
# - Linux: 使用官方安装脚本
# - 其他: 提示手动安装
#
# 环境变量：
# - AGENT_DEBUG_MODE=true: 启用调试模式，显示详细日志
# - 配置文件从系统标准位置加载
#
# 使用示例：
#   ./start.sh                    # 启动所有服务
#   ./start.sh --no-frontend      # 只启动后端
#   ./start.sh --no-backend       # 只启动前端
#   ./start.sh --help             # 显示帮助
#
# 注意事项：
# 1. 首次运行会自动安装工具，可能需要网络连接
# 2. 依赖安装可能需要一些时间
# 3. 按Ctrl+C可以优雅地停止所有服务
# 4. 确保有足够的磁盘空间和内存
#
# 故障排除：
# 1. 如果安装失败，检查网络连接
# 2. 如果权限不足，使用sudo运行（但注意安全）
# 3. 查看日志输出获取详细信息
#
# 开发说明：
# 这个脚本是跨平台的，支持Linux和macOS
# Windows用户请使用start.ps1
#
