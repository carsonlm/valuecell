# MCP (Model Context Protocol) 在 ValueCell 中的应用详解

## 什么是 MCP？

MCP (Model Context Protocol) 是一个开放协议，用于标准化大型语言模型（LLM）与外部工具、数据源之间的交互。它允许模型动态地发现、调用和使用外部资源，而无需硬编码集成。

在 ValueCell 项目中，虽然我们没有直接使用官方的 MCP 库，但我们实现了一套类似的协议和架构模式，通过 Agno 框架和自定义工具系统来实现智能体与外部资源的交互。

## ValueCell 中的 MCP 式架构

### 1. 架构概览

```
┌─────────────────────────────────────────────────────┐
│                 ValueCell 智能体平台                │
├─────────────────────────────────────────────────────┤
│        Agno 框架 + 自定义工具系统 (MCP式)           │
├─────────────────────────────────────────────────────┤
│  工具发现 │ 上下文管理 │ 协议适配 │ 安全控制        │
├─────────────────────────────────────────────────────┤
│           外部数据源和 API 集成层                   │
│           • SEC 文件系统                            │
│           • 金融数据 API                            │
│           • 新闻源                                  │
│           • 加密货币数据                           │
└─────────────────────────────────────────────────────┘
```

### 2. 核心组件

#### 2.1 工具系统 (Tools System)
ValueCell 实现了类似 MCP 的工具发现和调用机制：

```python
# valuecell/python/valuecell/agents/research_agent/sources.py
async def fetch_periodic_sec_filings(
    cik_or_ticker: str,
    forms: List[str] | str = "10-Q",
    year: Optional[int | List[int]] = None,
    quarter: Optional[int | List[int]] = None,
    limit: int = 10,
):
    """Fetch periodic SEC filings (10-K, 10-Q) with optional year/quarter filtering.
    
    Args:
        cik_or_ticker: CIK or ticker symbol
        forms: "10-K", "10-Q" or a list of these
        year: Single year or list of years
        quarter: Single quarter (1-4) or list of quarters
        limit: Number of latest filings to return
        
    Returns:
        List[SECFilingResult]
    """
    # 工具实现...
```

#### 2.2 上下文管理器 (Context Manager)
ValueCell 通过 Agno 框架管理对话上下文：

```python
# valuecell/python/valuecell/agents/research_agent/core.py
class ResearchAgent(BaseAgent):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        tools = [
            fetch_periodic_sec_filings,
            fetch_event_sec_filings,
            fetch_ashare_filings,
            web_search,
            search_crypto_projects,
            search_crypto_vcs,
            search_crypto_people,
        ]
        
        self.knowledge_research_agent = Agent(
            model=model_utils_mod.get_model_for_agent("research_agent"),
            instructions=[KNOWLEDGE_AGENT_INSTRUCTION],
            expected_output=KNOWLEDGE_AGENT_EXPECTED_OUTPUT,
            tools=tools,  # 工具注册
            knowledge=knowledge,
            db=InMemoryDb(),
            # 上下文配置
            search_knowledge=knowledge is not None,
            add_datetime_to_context=True,
            add_history_to_context=True,
            num_history_runs=3,
            read_chat_history=True,
        )
```

#### 2.3 协议适配器 (Protocol Adapter)
ValueCell 通过 A2A (Agent-to-Agent) 协议实现智能体间的标准化通信：

```python
# valuecell/python/valuecell/core/agent/client.py
class AgentClient:
    """Client for communicating with remote agents via A2A protocol.
    
    实现了类似 MCP 的标准化通信：
    1. 智能体发现 (AgentCard 解析)
    2. 消息传递标准化
    3. 流式响应处理
    4. 错误处理标准化
    """
```

## MCP 核心概念在 ValueCell 中的实现

### 1. 工具发现 (Tool Discovery)

#### 静态工具注册
```python
# 在智能体初始化时注册工具
tools = [
    fetch_periodic_sec_filings,  # SEC 文件获取
    fetch_event_sec_filings,     # 事件驱动文件
    fetch_ashare_filings,        # A股文件
    web_search,                  # 网络搜索
    search_crypto_projects,      # 加密货币项目搜索
    search_crypto_vcs,           # 加密货币风投搜索
    search_crypto_people,        # 加密货币人物搜索
]
```

#### 动态工具描述
每个工具都有详细的文档字符串，Agno 框架会解析这些描述供 LLM 理解：

```python
async def web_search(
    query: str,
    max_results: int = 5,
    region: str = "us",
    time_period: str = "w",
):
    """Perform a web search using DuckDuckGo.
    
    Use this tool when you need to find current information, news,
    or general knowledge that is not in your training data.
    
    Args:
        query: Search query string
        max_results: Maximum number of results (default: 5)
        region: Region code for search (default: "us")
        time_period: Time period for results: d (day), w (week), m (month)
    
    Returns:
        Search results as a formatted string
    """
```

### 2. 上下文管理 (Context Management)

#### 对话上下文
```python
# valuecell/python/valuecell/agents/utils/context.py
def build_ctx_from_dep(dep: Optional[Dict[str, Any]]) -> Dict[str, str] | None:
    """构建从依赖项到上下文的映射"""
    if not dep:
        return None

    context = {}
    lang_ctx = _build_lang_ctx_from_dep(dep)
    if lang_ctx:
        context["compose_answer_hint"] = lang_ctx

    return context

def _build_lang_ctx_from_dep(dependencies: Optional[Dict[str, Any]]) -> str | None:
    """构建语言和时区上下文"""
    if not dependencies:
        return None

    user_lang = dependencies.get("language")
    user_tz = dependencies.get("timezone")

    parts = []
    parts.append("When composing your answer, consider the user's language and timezone:")
    if user_lang:
        parts.append(f"- Preferred language: {user_lang}")
    if user_tz:
        parts.append(f"- Timezone: {user_tz}")
    
    return "\n".join(parts)
```

#### 交易上下文
```python
# valuecell/python/valuecell/agents/common/trading/models.py
@dataclass
class ComposeContext:
    """交易决策的上下文信息"""
    ts: int  # 时间戳
    compose_id: str  # 组合ID
    features: List[FeatureVector]  # 特征向量
    portfolio: PortfolioView  # 投资组合视图
    market_type: MarketType  # 市场类型
    price_mode: PriceMode  # 价格模式
```

### 3. 协议通信 (Protocol Communication)

#### A2A 协议实现
```python
# valuecell/python/valuecell/core/agent/decorator.py
def _serve(agent_card: AgentCard):
    """创建装饰器，将智能体类包装为服务器"""
    
    def decorator(cls: Type) -> Type:
        class DecoratedAgent(cls):
            async def serve(self):
                # 创建 AgentExecutor 包装器
                self._executor = _create_agent_executor(self)
                
                # 设置服务器组件
                request_handler = DefaultRequestHandler(
                    agent_executor=self._executor,
                    task_store=InMemoryTaskStore(),
                    push_config_store=push_notification_config_store,
                    push_sender=push_notification_sender,
                )
                
                # 创建 A2A Starlette 应用
                server_app = A2AStarletteApplication(
                    agent_card=self.agent_card,
                    http_handler=request_handler,
                )
                
                # 启动服务器
                config = uvicorn.Config(
                    server_app.build(),
                    host=self._host,
                    port=self._port,
                    log_level="info",
                )
                self._server = uvicorn.Server(config)
                await self._server.serve()
        
        return DecoratedAgent
    
    return decorator
```

### 4. 安全控制 (Security Control)

#### 工具权限控制
```python
# 工具级别的访问控制
async def fetch_sensitive_data(
    user_id: str,
    resource_id: str,
    access_token: str = None,
):
    """获取敏感数据（需要权限验证）"""
    
    # 验证用户权限
    if not await validate_user_permission(user_id, resource_id, access_token):
        raise PermissionError("用户没有访问此资源的权限")
    
    # 执行数据获取
    data = await get_sensitive_resource(resource_id)
    
    # 数据脱敏处理
    sanitized_data = sanitize_sensitive_info(data)
    
    return sanitized_data
```

#### 输入验证
```python
def validate_tool_inputs(**kwargs):
    """验证工具输入参数"""
    
    validators = {
        'cik_or_ticker': lambda x: isinstance(x, str) and len(x) > 0,
        'limit': lambda x: isinstance(x, int) and 1 <= x <= 100,
        'year': lambda x: x is None or (isinstance(x, (int, list)) and all(1900 <= y <= 2100 for y in (x if isinstance(x, list) else [x]))),
    }
    
    for param, value in kwargs.items():
        if param in validators and not validators[param](value):
            raise ValueError(f"参数 {param} 验证失败: {value}")
```

## 实际应用示例

### 示例 1：研究智能体工作流

```python
# 完整的研究智能体工作流
class ResearchAgent(BaseAgent):
    async def stream(self, query, conversation_id, task_id, dependencies=None):
        """处理研究查询的完整工作流"""
        
        # 1. 初始化响应
        yield streaming.message_chunk(f"🔍 开始分析: {query}")
        yield streaming.reasoning("正在收集市场数据...")
        
        # 2. 使用 Agno Agent 处理查询（自动工具调用）
        response_stream = self.knowledge_research_agent.arun(
            query,
            stream=True,
            stream_intermediate_steps=True,
            session_id=conversation_id,
            add_dependencies_to_context=True,
            dependencies=build_ctx_from_dep(dependencies),
        )
        
        # 3. 处理流式响应
        async for event in response_stream:
            if event.event == "RunContent":
                yield streaming.message_chunk(event.content)
            elif event.event == "ToolCallStarted":
                # 工具调用开始事件
                yield streaming.tool_call_started(
                    event.tool.tool_call_id, 
                    event.tool.tool_name
                )
            elif event.event == "ToolCallCompleted":
                # 工具调用完成事件
                yield streaming.tool_call_completed(
                    event.tool.result, 
                    event.tool.tool_call_id, 
                    event.tool.tool_name
                )
        
        # 4. 完成处理
        yield streaming.message_chunk("✅ 分析完成")
        yield streaming.done()
```

### 示例 2：交易决策上下文

```python
# 交易决策的上下文构建和使用
class GridComposer:
    async def compose(self, context: ComposeContext) -> ComposeResult:
        """基于上下文进行网格交易决策"""
        
        # 1. 从上下文中提取特征
        symbols = list(self._request.trading_config.symbols or [])
        features = context.features or []
        
        # 2. 分析市场变化
        max_abs_change = self._max_abs_change_pct(context)
        has_market_change = self._has_clear_market_change(context)
        
        # 3. 构建交易区域描述
        zone_suffix = self._zone_suffix(context)
        
        # 4. 基于上下文做出决策
        decisions = []
        for symbol in symbols:
            # 获取价格信息
            price = self._get_price_from_context(context, symbol)
            position = context.portfolio.positions.get(symbol)
            
            # 基于上下文做出交易决策
            if self._should_open_long(context, symbol, price, position):
                decisions.append(self._create_long_decision(
                    symbol, price, context, zone_suffix
                ))
        
        return ComposeResult(decisions=decisions)
```

### 示例 3：多工具协同工作

```python
# 多工具协同完成复杂任务
async def comprehensive_research_workflow(agent, query):
    """综合研究流程：多个工具协同工作"""
    
    # 工具1：搜索相关公司
    search_results = await agent.tools["web_search"](f"{query} company stock")
    
    # 工具2：获取SEC文件
    ticker = extract_ticker_from_search(search_results)
    sec_filings = await agent.tools["fetch_periodic_sec_filings"](
        cik_or_ticker=ticker,
        forms=["10-K", "10-Q"],
        limit=5
    )
    
    # 工具3：获取新闻数据
    news = await agent.tools["get_financial_news"](
        query=ticker,
        max_results=10
    )
    
    # 工具4：加密货币数据（如果相关）
    if is_crypto_related(query):
        crypto_data = await agent.tools["search_crypto_projects"](
            query=query,
            limit=5
        )
    
    # 综合分析所有数据
    analysis = await agent.analyze_integrated_data(
        search_results, sec_filings, news, crypto_data
    )
    
    return analysis
```

## 架构优势

### 1. 模块化设计
- **工具独立**: 每个工具都是独立的函数，易于测试和维护
- **智能体解耦**: 智能体通过协议通信，不直接依赖具体实现
- **协议标准化**: A2A 协议提供统一的通信标准

### 2. 可扩展性
- **新工具添加**: 只需定义新函数并注册到智能体
- **新数据源集成**: 实现对应的工具函数即可
- **协议扩展**: A2A 协议支持自定义扩展

### 3. 安全性
- **输入验证**: 所有工具输入都经过验证
- **权限控制**: 敏感操作需要权限验证
- **数据脱敏**: 敏感数据在返回前进行脱敏处理

### 4. 可观测性
- **完整日志**: 所有工具调用都有详细日志
- **性能监控**: 监控工具执行时间和成功率
- **错误追踪**: 完整的错误堆栈和上下文信息

## 与标准 MCP 的对比

| 特性 | 标准 MCP | ValueCell 实现 |
|------|----------|----------------|
| 工具发现 | 动态发现协议 | 静态注册 + 动态描述 |
| 上下文管理 | 标准上下文协议 | 自定义上下文系统 |
| 通信协议 | HTTP/SSE | A2A over HTTP |
| 安全模型 | OAuth/API Key | 自定义权限系统 |
| 工具定义 | JSON Schema | Python 函数 + 文档字符串 |
| 扩展性 | 协议扩展点 | 插件式架构 |

## 最佳实践

### 1. 工具设计原则
```python
# 好的工具设计示例
async def well_designed_tool(
    # 清晰的参数名
    entity_id: str,
    # 合理的默认值
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    # 限制范围
    limit: int = Field(10, ge=1, le=100),
    # 枚举类型
    format: Literal["json", "csv", "markdown"] = "json",
):
    """
    清晰的功能描述
    
    使用场景：
    - 当用户需要获取...时
    - 当需要分析...时
    
    参数说明：
    - entity_id: 实体标识符
    - start_date: 开始日期 (YYYY-MM-DD)
    - end_date: 结束日期 (YYYY-MM-DD)
    - limit: 返回结果数量限制
    - format: 返回格式
    
    返回：
    结构化的数据结果
    
    错误处理：
    - 参数无效时抛出 ValueError
    - 网络错误时重试3次
    - 权限不足时抛出 PermissionError
    """
```

### 2. 上下文管理最佳实践
- **最小化上下文**: 只传递必要的信息
- **上下文验证**: 验证上下文数据的有效性
- **上下文缓存**: 合理缓存重复使用的上下文
- **上下文版本化**: 支持不同版本的上下文格式

### 3. 错误处理策略
```python
async def robust_tool_implementation(**kwargs):
    """健壮的工具实现"""
    
    try:
        # 1. 输入验证
        validate_inputs(**kwargs)
        
        # 2. 资源准备
        await prepare_resources()
        
        # 3. 执行操作（带重试）
        result = await execute_with_retry(
            operation,
            max_retries=3,
            retry_delay=1.0
        )
        
        # 4. 结果处理
        processed_result = process_result(result)
        
        # 5. 清理资源
        await cleanup_resources()
        
        return processed_result
        
    except ValidationError as e:
        logger.warning(f"输入验证失败: {e}")
        raise
    except ResourceError as e:
        logger.error(f"资源错误: {e}")
        raise
    except Exception as e:
        logger.exception(f"未预期的错误: {e}")
        raise RuntimeError(f"工具执行失败: {str(e)}")
```

## 未来扩展方向

### 1. 向标准 MCP 迁移
```python
# 可能的 MCP 集成方案
class MCPAdapter:
    """MCP 协议适配器"""
    
    async def discover_tools(self) -> List[ToolDefinition]:
        """发现可用工具"""
        return [
            {
                "name": tool.__name__,
                "description": tool.__doc__,
                "inputSchema": extract_json_schema(tool),
                "outputSchema": {"type": "string"},
            }
            for tool in self.registered_tools
        ]
    
    async def execute_tool(self, tool_name: str, arguments: dict):
        """执行工具"""
        tool = self.tools[tool_name]
        return await tool(**arguments)
```

### 2. 增强的上下文管理
- **向量化上下文**: 使用向量数据库存储和检索上下文
- **上下文压缩**: 自动压缩过长的上下文
- **上下文共享**: 在智能体间安全共享上下文

### 3. 高级工具功能
- **工具链**: 支持工具链式调用
- **条件工具**: 根据上下文动态启用/禁用工具
- **工具版本管理**: 支持工具版本控制和回滚

## 总结

ValueCell 项目虽然没有直接使用官方的 MCP 库，但实现了一套完整的 MCP 式架构，具有以下特点：

1. **完整的工具系统**: 基于 Agno 框架的工具发现和调用机制
2. **强大的上下文管理**: 支持多层次的上下文传递和管理
3. **标准化通信协议**: 通过 A2A 协议实现智能体间标准化通信
4. **企业级安全控制**: 完整的权限验证和输入验证机制
5. **优秀的可扩展性**: 模块化设计支持快速扩展新功能

这套架构为金融领域的多智能体应用提供了坚实的基础，既保持了灵活性，又确保了系统的稳定性和安全性。随着 MCP 标准的成熟，ValueCell 可以平滑地迁移到标准 MCP 协议，同时保持现有的功能和特性。