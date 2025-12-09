# ValueCell 项目启动脚本 (Windows PowerShell)
# 这是一个智能启动脚本，会自动检查并安装必要的工具，然后启动前后端服务
# 使用方式：.\start.ps1 [选项]

param(
    [switch]$NoFrontend,    # 只启动后端，不启动前端
    [switch]$NoBackend,     # 只启动前端，不启动后端
    [Alias("h")]
    [switch]$Help           # 显示帮助信息
)

# 设置错误处理：遇到错误时停止执行
$ErrorActionPreference = "Stop"

# ============================================================================
# 目录和变量定义
# ============================================================================

# 获取脚本所在目录的绝对路径
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# 前端目录路径
$FRONTEND_DIR = Join-Path $SCRIPT_DIR "frontend"

# Python后端目录路径
$PY_DIR = Join-Path $SCRIPT_DIR "python"

# 进程变量，用于后续清理
$BACKEND_PROCESS = $null
$FRONTEND_PROCESS = $null

# ============================================================================
# 日志输出函数（带颜色）
# ============================================================================

# 信息级别日志（青色）
function Write-Info($message) {
    Write-Host "[INFO]  $message" -ForegroundColor Cyan
}

# 成功级别日志（绿色）
function Write-Success($message) {
    Write-Host "[ OK ]  $message" -ForegroundColor Green
}

# 警告级别日志（黄色）
function Write-Warn($message) {
    Write-Host "[WARN]  $message" -ForegroundColor Yellow
}

# 错误级别日志（红色）
function Write-Err($message) {
    Write-Host "[ERR ]  $message" -ForegroundColor Red
}

# ============================================================================
# 工具函数
# ============================================================================

# 检查命令是否存在
function Test-CommandExists($command) {
    $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
}

# 确保工具已安装，如果未安装则自动安装
function Ensure-Tool($toolName) {
    # 检查工具是否已安装
    if (Test-CommandExists $toolName) {
        try {
            # 尝试获取版本信息
            $version = & $toolName --version 2>$null | Select-Object -First 1
            if (-not $version) { $version = "version unknown" }
            Write-Success "$toolName is installed ($version)"
        } catch {
            Write-Success "$toolName is installed"
        }
        return
    }

    Write-Info "Installing $toolName..."

    # 根据工具名称选择安装方式
    if ($toolName -eq "bun") {
        # 安装Bun (JavaScript运行时)
        try {
            Write-Info "Installing bun via PowerShell script..."
            # 使用新的PowerShell进程安装，避免变量冲突
            $installCmd = "irm https://bun.sh/install.ps1 | iex"
            powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $installCmd

            # 将Bun添加到当前会话的PATH
            $bunPath = "$env:USERPROFILE\.bun\bin"
            if (Test-Path $bunPath) {
                $env:Path = "$bunPath;$env:Path"
            }
        } catch {
            Write-Err "Failed to install bun: $_"
            Write-Err "Please install manually from https://bun.sh/docs/installation"
            exit 1
        }
    } elseif ($toolName -eq "uv") {
        # 安装uv (Python包管理器)
        try {
            Write-Info "Installing uv via PowerShell script..."
            # 使用新的PowerShell进程安装
            $installCmd = "irm https://astral.sh/uv/install.ps1 | iex"
            powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $installCmd

            # 将uv添加到当前会话的PATH，检查多个可能的安装位置
            $possiblePaths = @(
                "$env:USERPROFILE\.cargo\bin",      # 通过cargo安装的位置
                "$env:USERPROFILE\.local\bin",      # 用户本地bin目录
                "$env:LOCALAPPDATA\Programs\uv"     # 程序安装目录
            )
            foreach ($uvPath in $possiblePaths) {
                if (Test-Path $uvPath) {
                    $env:Path = "$uvPath;$env:Path"
                    break
                }
            }
        } catch {
            Write-Err "Failed to install uv: $_"
            Write-Err "Please install manually from https://docs.astral.sh/uv/getting-started/installation/"
            exit 1
        }
    } else {
        Write-Warn "Unknown tool: $toolName"
        exit 1
    }

    # 验证安装是否成功
    if (Test-CommandExists $toolName) {
        Write-Success "$toolName installed successfully"
    } else {
        Write-Err "$toolName installation failed. Please install manually and retry."
        Write-Err "You may need to restart your terminal or add the tool to your PATH."
        exit 1
    }
}

# ============================================================================
# 编译和依赖安装
# ============================================================================

function Compile {
    # 后端依赖安装
    if (Test-Path $PY_DIR) {
        Write-Info "Sync Python dependencies (uv sync)..."
        Push-Location $PY_DIR
        try {
            # 运行环境准备脚本（如果存在）
            if (Test-Path "scripts\prepare_envs.ps1") {
                Write-Info "Running environment preparation script..."
                & ".\scripts\prepare_envs.ps1"
            } else {
                Write-Warn "prepare_envs.ps1 not found, running uv sync directly..."
                uv sync
            }
            # 初始化数据库
            uv run valuecell/server/db/init_db.py
            Write-Success "Python dependencies synced"
        } catch {
            Write-Err "Failed to sync Python dependencies: $_"
            exit 1
        } finally {
            Pop-Location
        }
    } else {
        Write-Warn "Backend directory not found: $PY_DIR. Skipping"
    }

    # 前端依赖安装
    if (Test-Path $FRONTEND_DIR) {
        Write-Info "Install frontend dependencies (bun install)..."
        Push-Location $FRONTEND_DIR
        try {
            bun install
            Write-Success "Frontend dependencies installed"
        } catch {
            Write-Err "Failed to install frontend dependencies: $_"
            exit 1
        } finally {
            Pop-Location
        }
    } else {
        Write-Warn "Frontend directory not found: $FRONTEND_DIR. Skipping"
    }
}

# ============================================================================
# 服务启动函数
# ============================================================================

# 启动后端服务（前台运行）
function Start-Backend {
    if (-not (Test-Path $PY_DIR)) {
        Write-Warn "Backend directory not found; skipping backend start"
        return
    }

    Write-Info "Starting backend in debug mode (AGENT_DEBUG_MODE=true)..."
    Push-Location $PY_DIR
    try {
        # 设置调试模式，用于本地开发
        $env:AGENT_DEBUG_MODE = "true"
        # 使用uv运行Python服务器
        & uv run python -m valuecell.server.main
    } catch {
        Write-Err "Failed to start backend: $_"
    } finally {
        Pop-Location
    }
}

# 启动前端服务（后台运行）
function Start-Frontend {
    if (-not (Test-Path $FRONTEND_DIR)) {
        Write-Warn "Frontend directory not found; skipping frontend start"
        return
    }

    Write-Info "Starting frontend dev server (bun run dev)..."
    Push-Location $FRONTEND_DIR
    try {
        # 首先尝试找到bun.exe的实际位置
        $bunExe = "$env:USERPROFILE\.bun\bin\bun.exe"
        $bunPath = $null

        if (Test-Path $bunExe) {
            $bunPath = $bunExe
            Write-Info "Using bun at: $bunPath"
            # 启动前端进程，不创建新窗口，传递进程对象
            $script:FRONTEND_PROCESS = Start-Process -FilePath $bunPath -ArgumentList "run", "dev" -NoNewWindow -PassThru
        } else {
            # 备选方案：获取bun命令的完整路径
            $bunCmd = Get-Command "bun" -ErrorAction Stop
            $resolvedPath = $bunCmd.Source

            if ([System.IO.Path]::GetExtension($resolvedPath) -eq ".ps1") {
                # 如果是PowerShell脚本，使用powershell.exe执行
                Write-Info "Using bun script at: $resolvedPath"
                $currentDir = Get-Location
                $script:FRONTEND_PROCESS = Start-Process -FilePath "powershell.exe" `
                    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "& { Set-Location '$currentDir'; & '$resolvedPath' run dev }" `
                    -NoNewWindow -PassThru
            } else {
                # 常规可执行文件
                Write-Info "Using bun at: $resolvedPath"
                $script:FRONTEND_PROCESS = Start-Process -FilePath $resolvedPath -ArgumentList "run", "dev" -NoNewWindow -PassThru
            }
        }

        Write-Info "Frontend PID: $($script:FRONTEND_PROCESS.Id)"
    } catch {
        Write-Err "Failed to start frontend: $_"
        throw
    } finally {
        Pop-Location
    }
}

# ============================================================================
# 清理函数
# ============================================================================

function Cleanup {
    Write-Host ""
    Write-Info "Stopping services..."

    # 停止前端进程（如果正在运行）
    if ($script:FRONTEND_PROCESS -and -not $script:FRONTEND_PROCESS.HasExited) {
        try {
            Stop-Process -Id $script:FRONTEND_PROCESS.Id -Force -ErrorAction SilentlyContinue
        } catch {
            # 忽略清理过程中的错误
        }
    }

    # 停止后端进程（如果正在运行）
    if ($script:BACKEND_PROCESS -and -not $script:BACKEND_PROCESS.HasExited) {
        try {
            Stop-Process -Id $script:BACKEND_PROCESS.Id -Force -ErrorAction SilentlyContinue
        } catch {
            # 忽略清理过程中的错误
        }
    }

    Write-Success "Stopped"
}

# ============================================================================
# 使用说明
# ============================================================================

function Print-Usage {
    Write-Host @"
Usage: .\start.ps1 [options]

Description:
  - Checks whether bun and uv are installed; missing tools will be auto-installed via PowerShell scripts.
  - Then installs backend and frontend dependencies and starts services.
  - Environment variables are loaded from system path:
    * macOS: ~/Library/Application Support/ValueCell/.env
    * Linux: ~/.config/valuecell/.env
    * Windows: %APPDATA%\ValueCell\.env
  - The .env file will be auto-created from .env.example on first run.
  - Debug mode is automatically enabled (AGENT_DEBUG_MODE=true) for local development.

Options:
  -NoFrontend     Start backend only
  -NoBackend      Start frontend only
  -Help, -h       Show this help message
"@
}

# ============================================================================
# 主程序
# ============================================================================

# 注册退出事件，确保脚本退出时清理资源
Register-EngineEvent PowerShell.Exiting -Action { Cleanup } | Out-Null

try {
    # 显示帮助信息（如果请求）
    if ($Help) {
        Print-Usage
        exit 0
    }

    # 确保必要的工具已安装
    Ensure-Tool "bun"  # Bun: JavaScript运行时和包管理器
    Ensure-Tool "uv"   # uv: Python包管理器

    # 安装依赖
    Compile

    # 启动前端服务（如果启用）
    if (-not $NoFrontend) {
        Start-Frontend
        Start-Sleep -Seconds 5  # 给前端一些时间启动
    }

    # 启动后端服务（如果启用）
    if (-not $NoBackend) {
        Start-Backend
    }

    # 如果前端正在运行，等待它
    if ($script:FRONTEND_PROCESS -and -not $script:FRONTEND_PROCESS.HasExited) {
        Write-Info "Services running. Press Ctrl+C to stop..."
        Wait-Process -Id $script:FRONTEND_PROCESS.Id -ErrorAction SilentlyContinue
    }
} catch {
    Write-Err "An error occurred: $_"
    exit 1
} finally {
    Cleanup
}

# ============================================================================
# 脚本详细说明
# ============================================================================
#
# 功能概述：
# 1. 环境检查：检查必要的工具（bun, uv）是否已安装
# 2. 自动安装：如果工具未安装，使用PowerShell脚本自动安装
# 3. 依赖安装：安装前后端的所有依赖
# 4. 服务启动：启动开发服务器
# 5. 清理处理：优雅地停止服务
#
# 支持的Windows版本：
# - Windows 10 或更高版本
# - Windows Server 2016 或更高版本
# - PowerShell 5.1 或更高版本
#
# 环境变量：
# - AGENT_DEBUG_MODE=true: 启用调试模式，显示详细日志
# - 配置文件从系统标准位置加载：%APPDATA%\ValueCell\.env
#
# 使用示例：
#   .\start.ps1                    # 启动所有服务
#   .\start.ps1 -NoFrontend        # 只启动后端
#   .\start.ps1 -NoBackend         # 只启动前端
#   .\start.ps1 -Help              # 显示帮助
#
# 注意事项：
# 1. 首次运行会自动安装工具，需要管理员权限
# 2. 依赖安装可能需要一些时间，请耐心等待
# 3. 按Ctrl+C可以优雅地停止所有服务
# 4. 确保Windows Defender或防火墙不阻止网络连接
#
# 故障排除：
# 1. 如果安装失败，检查网络连接和代理设置
# 2. 如果权限不足，以管理员身份运行PowerShell
# 3. 查看PowerShell执行策略：Get-ExecutionPolicy
# 4. 可能需要设置：Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#
# 开发说明：
# 这个脚本专门为Windows设计，使用PowerShell特性
# Linux/macOS用户请使用start.sh
#
# 安全提示：
# 1. 脚本会从互联网下载安装程序，请确保网络环境安全
# 2. 建议在运行前检查脚本内容
# 3. 不要以管理员身份运行不受信任的脚本
#
