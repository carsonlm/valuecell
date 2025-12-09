# ValueCell 项目 Makefile
# 这个文件定义了项目的常用命令和自动化任务
# 使用方式：在项目根目录运行 `make <target>`

# ============================================================================
# 代码格式化 (Code Formatting)
# ============================================================================
format:
	# 使用 ruff 格式化 Python 代码
	# --config ./python/pyproject.toml: 指定配置文件路径
	# ./python/: 要格式化的目录
	ruff format --config ./python/pyproject.toml ./python/ && \
	# 使用 isort 对 import 语句进行排序
	# uv run --directory ./python: 在 python 目录下运行命令
	# isort .: 对当前目录的 import 进行排序
	uv run --directory ./python isort .

# ============================================================================
# 代码检查 (Code Linting)
# ============================================================================
lint:
	# 使用 ruff 进行代码检查
	# ruff check: 运行代码检查
	# --config ./python/pyproject.toml: 指定配置文件
	# ./python/: 要检查的目录
	ruff check --config ./python/pyproject.toml ./python/

# ============================================================================
# 运行测试 (Running Tests)
# ============================================================================
test:
	# 使用 pytest 运行测试
	# uv run pytest: 通过 uv 运行 pytest
	# ./python: 测试目录
	uv run pytest ./python

# ============================================================================
# 使用说明
# ============================================================================
# 常用命令：
#   make format    - 格式化所有 Python 代码
#   make lint      - 检查代码质量和风格
#   make test      - 运行所有测试
#
# 组合使用：
#   make format && make lint && make test  # 完整的代码质量检查流程
#
# 注意：
# 1. 需要在项目根目录运行这些命令
# 2. 确保已安装 uv (https://github.com/astral-sh/uv)
# 3. 确保已安装项目依赖：uv sync --group dev
#
# 扩展建议：
# 可以添加更多目标，如：
#   - install: 安装依赖
#   - clean: 清理构建文件
#   - build: 构建项目
#   - run: 运行应用
#   - deploy: 部署应用

# ============================================================================
# 各命令详细说明
# ============================================================================
# format 命令：
#   1. ruff format: 使用 ruff 的格式化功能，基于 pyproject.toml 中的配置
#   2. isort: 自动排序 import 语句，使代码更整洁
#
# lint 命令：
#   1. ruff check: 检查代码质量问题，如：
#      - 未使用的变量
#      - 导入错误
#      - 代码风格问题
#      - 潜在的错误
#
# test 命令：
#   1. uv run pytest: 使用 uv 虚拟环境运行 pytest
#   2. 会自动发现并运行所有测试文件
#   3. 支持测试覆盖率报告（如果配置了 pytest-cov）
#
# 工作流程建议：
#   1. 开发前：make lint 检查代码质量
#   2. 开发中：定期运行 make test 确保功能正常
#   3. 提交前：make format && make lint && make test
#   4. CI/CD：自动运行这些检查

# ============================================================================
# 环境要求
# ============================================================================
# 必需工具：
#   - make: GNU Make (通常 Linux/macOS 自带，Windows 需要安装)
#   - uv: Python 包管理器 (https://github.com/astral-sh/uv)
#   - Python 3.12+: 项目要求
#
# 安装 uv (如果尚未安装)：
#   Linux/macOS: curl -LsSf https://astral.sh/uv/install.sh | sh
#   Windows: 使用 winget: winget install astral-sh.uv
#   或从 GitHub Releases 下载
#
# 设置项目环境：
#   1. 克隆项目
#   2. 安装依赖: cd python && uv sync --group dev
#   3. 现在可以使用 make 命令了

# ============================================================================
# 故障排除
# ============================================================================
# 问题1: make: command not found
#   解决方案: 安装 make 工具
#   - Ubuntu/Debian: sudo apt-get install make
#   - macOS: 通常已安装，或通过 xcode-select --install
#   - Windows: 安装 MinGW 或使用 WSL
#
# 问题2: uv: command not found
#   解决方案: 安装 uv (见上面的安装说明)
#
# 问题3: 依赖安装失败
#   解决方案: 确保 Python 3.12+ 已安装，然后重试 uv sync
#
# 问题4: 测试失败
#   解决方案: 检查测试代码和依赖，确保环境正确配置
