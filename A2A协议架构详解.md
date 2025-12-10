# A2A协议架构详解

## 架构总览

```
┌─────────────────────────────────────────────────────────────┐
│                     ValueCell 系统架构                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   前端界面   │    │   用户输入   │    │   结果显示   │     │
│  │  (Web UI)   │◄──►│             │◄──►│             │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│          │                         │                        │
│          ▼                         ▼                        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                 Orchestrator (协调器)                 │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │   │
│  │  │ Super Agent │  │   Planner   │  │ Task Exec. │  │   │
│  │  │ (总指挥AI)   │  │  (规划器)   │  │ (任务执行器) │  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  │   │
│  └─────────────────────────────────────────────────────┘   │
│                    │                                        │
│                    ▼                                        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              A2A Protocol Layer                     │   │
│  │         (A2A协议层 - 智能体通信桥梁)                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                    │                                        │
│                    ▼                                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ Market Agent│  │ News Agent  │  │Fundamental  │  ...    │
│  │(市场分析AI) │  │(新闻分析AI) │  │ Agent(财报AI)│         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 核心组件详解

### 1. Orchestrator (协调器)
**位置**: `valuecell/core/coordinate/orchestrator.py`
**职责**: 整个系统的指挥中心

```python
class AgentOrchestrator:
    async def process_user_input(self, query: str):
        """处理用户输入的完整流程"""
        # 1. 接收用户输入
        # 2. 调用Super Agent进行分流
        # 3. 调用Planner制定计划
        # 4. 通过A2A协议执行任务
        # 5. 流式返回结果
```

**工作流程**:
```
1. 接收用户请求 → 2. Super Agent分流 → 3. Planner规划 → 4. A2A执行 → 5. 结果返回
```

### 2. Super Agent (总指挥AI)
**位置**: `valuecell/core/super_agent/`
**职责**: 判断请求类型，决定如何处理

```python
class SuperAgent:
    async def triage(self, user_input: str) -> SuperAgentOutcome:
        """分流决策"""
        # 决策类型:
        # - ANSWER: 直接回答（简单问题）
        # - HANDOFF_TO_PLANNER: 交给规划器（复杂问题）
```

**决策逻辑**:
- **简单问题**: "当前时间"、"你好" → 直接回答
- **复杂问题**: "分析股票"、"制定投资策略" → 交给规划器

### 3. Planner (规划器)
**位置**: `valuecell/core/plan/`
**职责**: 制定执行计划，确定需要哪些智能体

```python
class ExecutionPlanner:
    async def create_plan(self, query: str) -> ExecutionPlan:
        """创建执行计划"""
        # 分析需求，确定需要哪些智能体
        # 例如："分析AAPL股票"需要:
        # 1. 市场分析师
        # 2. 新闻分析师
        # 3. 基本面分析师
```

### 4. Task Executor (任务执行器)
**位置**: `valuecell/core/task/executor.py`
**职责**: 通过A2A协议执行任务

```python
class TaskExecutor:
    async def execute_plan(self, plan: ExecutionPlan):
        """执行计划"""
        # 通过A2A协议并行调用多个智能体
        tasks = []
        for task in plan.tasks:
            # 通过A2A客户端调用远程智能体
            task_result = await self.a2a_client.execute(task)
            tasks.append(task_result)
        
        # 等待所有任务完成
        results = await asyncio.gather(*tasks)
        return results
```

## A2A协议层架构

### 1. A2A Client (客户端)
**位置**: `valuecell/core/agent/client.py`

```python
class AgentClient:
    """A2A协议客户端"""
    
    def __init__(self, agent_url: str):
        self.agent_url = agent_url
        self.httpx_client = httpx.AsyncClient()
    
    async def send_message(self, query: str) -> AsyncIterator[Response]:
        """通过A2A协议发送消息"""
        # 1. 解析Agent Card
        card = await self.get_agent_card()
        
        # 2. 创建A2A消息
        message = A2AMessage(
            role=Role.user,
            content=query,
            message_id=generate_uuid()
        )
        
        # 3. 发送请求（支持流式）
        async for chunk in self._stream_request(message):
            yield chunk
```

### 2. Agent Decorator (智能体装饰器)
**位置**: `valuecell/core/agent/decorator.py`

```python
def agent_decorator(cls):
    """将普通类转换为A2A智能体"""
    
    class DecoratedAgent(cls):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            # 自动生成Agent Card
            self.agent_card = self._create_agent_card()
            
        async def serve(self):
            """启动A2A服务器"""
            # 创建HTTP服务器
            app = A2AStarletteApplication(
                agent_card=self.agent_card,
                handler=self._handle_request
            )
            # 启动服务
            uvicorn.run(app, host="0.0.0.0", port=8000)
    
    return DecoratedAgent
```

### 3. Agent Card (智能体名片)
**位置**: `valuecell/core/agent/card.py`

```python
class AgentCard:
    """智能体能力描述"""
    
    name: str                    # 智能体名称
    description: str             # 描述
    capabilities: List[str]      # 能力列表
    url: str                     # 服务地址
    input_schema: Dict           # 输入格式
    output_schema: Dict          # 输出格式
    metadata: Dict               # 元数据
```

## 数据流详解

### 场景：分析特斯拉股票

```
┌───────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ 用户  │────▶│ Orchestrator│────▶│ Super Agent │────▶│   Planner   │
└───────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                                    │
                                                    ▼
                                          ┌─────────────────┐
                                          │  ExecutionPlan  │
                                          │ - 任务1: 市场分析 │
                                          │ - 任务2: 新闻分析 │
                                          │ - 任务3: 财报分析 │
                                          └─────────────────┘
                                                    │
                                                    ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ Market Agent│◀────│ Task Executor│────▶│ News Agent  │◀────│ A2A Protocol│
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
        │                   │                   │                   │
        ▼                   ▼                   ▼                   ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  股价分析结果 │     │  结果聚合器   │     │  新闻分析结果 │     │  财报分析结果 │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                                    │
                                                    ▼
                                          ┌─────────────┐
                                          │  综合报告   │
                                          └─────────────┘
                                                    │
                                                    ▼
                                          ┌─────────────┐
                                          │     用户    │
                                          └─────────────┘
```

### 详细步骤：

1. **用户输入**: "分析特斯拉股票前景"
2. **Orchestrator接收**: 创建新的会话上下文
3. **Super Agent分流**: 判断为复杂问题，需要多个专家
4. **Planner规划**: 
   - 确定需要: 市场分析 + 新闻分析 + 财报分析
   - 创建执行计划
5. **Task Executor执行**:
   - 通过A2A协议并行调用三个智能体
   - 每个智能体返回流式结果
6. **结果聚合**: 聚合所有智能体的分析结果
7. **生成报告**: 创建综合投资建议
8. **返回用户**: 流式显示分析过程

## 协议消息格式

### 1. 请求消息 (Request)
```json
{
  "message_id": "msg_123456",
  "context_id": "ctx_789012",
  "role": "user",
  "content": "分析AAPL股票",
  "metadata": {
    "user_id": "user_001",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

### 2. 响应消息 (Response)
```json
{
  "message_id": "msg_123456_response",
  "context_id": "ctx_789012",
  "role": "assistant",
  "content": "AAPL分析结果...",
  "status": "streaming",  // 或 "completed"
  "chunk_index": 1,
  "total_chunks": 5
}
```

### 3. 状态更新 (Status Update)
```json
{
  "event_type": "task_status_update",
  "task_id": "task_123",
  "status": "running",
  "progress": 0.5,
  "timestamp": "2024-01-15T10:31:00Z"
}
```

## 并发处理机制

### 1. 异步执行
```python
async def analyze_multiple_stocks(tickers: List[str]):
    """同时分析多只股票"""
    tasks = []
    
    for ticker in tickers:
        # 为每只股票创建分析任务
        task = asyncio.create_task(
            analyze_single_stock(ticker)
        )
        tasks.append(task)
    
    # 等待所有任务完成
    results = await asyncio.gather(*tasks)
    return results
```

### 2. 流式响应
```python
async def stream_analysis(ticker: str):
    """流式返回分析结果"""
    # 第一部分：获取基本信息
    yield {"type": "info", "content": "开始分析..."}
    
    # 第二部分：市场分析
    market_result = await market_agent.analyze(ticker)
    yield {"type": "market", "content": market_result}
    
    # 第三部分：新闻分析
    news_result = await news_agent.analyze(ticker)
    yield {"type": "news", "content": news_result}
    
    # 第四部分：总结
    yield {"type": "summary", "content": "分析完成"}
```

## 错误处理机制

### 1. 重试策略
```python
class A2AClientWithRetry:
    async def send_with_retry(self, message, max_retries=3):
        """带重试的发送"""
        for attempt in range(max_retries):
            try:
                return await self.send_message(message)
            except (TimeoutError, ConnectionError) as e:
                if attempt == max_retries - 1:
                    raise
                await asyncio.sleep(2 ** attempt)  # 指数退避
```

### 2. 降级处理
```python
async def analyze_stock_with_fallback(ticker: str):
    """带降级的股票分析"""
    try:
        # 首选：完整的多智能体分析
        return await full_analysis(ticker)
    except Exception:
        # 备选：简化分析
        return await simple_analysis(ticker)
```

## 配置管理

### 1. 智能体注册
```yaml
# agents.yaml
agents:
  market_analyst:
    name: "市场分析师"
    url: "http://localhost:8001"
    capabilities: ["technical_analysis", "market_trends"]
    health_check: "/health"
    
  news_analyst:
    name: "新闻分析师"
    url: "http://localhost:8002"
    capabilities: ["news_analysis", "sentiment"]
    health_check: "/health"
```

### 2. A2A协议配置
```python
# config.py
A2A_CONFIG = {
    "timeout": 30,           # 超时时间(秒)
    "max_retries": 3,        # 最大重试次数
    "streaming": True,       # 启用流式
    "compression": True,     # 启用压缩
    "encryption": True,      # 启用加密
}
```

## 监控和日志

### 1. 性能监控
```python
class A2AMonitor:
    def record_metrics(self, agent_name: str, duration: float, success: bool):
        """记录性能指标"""
        metrics = {
            "agent": agent_name,
            "duration": duration,
            "success": success,
            "timestamp": datetime.now()
        }
        # 发送到监控系统
        self.metrics_store.save(metrics)
```

### 2. 详细日志
```python
# 启用详细日志
import logging
logging.basicConfig(level=logging.DEBUG)

# A2A协议日志示例
logger.debug(f"A2A请求: {agent_url}, 消息: {message_id}")
logger.info(f"A2A响应: 状态={status}, 大小={response_size}")
logger.error(f"A2A错误: {error}, 重试={retry_count}")
```

## 扩展性设计

### 1. 插件式架构
```python
class PluginManager:
    def register_agent(self, agent_class):
        """注册新智能体"""
        # 自动生成Agent Card
        agent_card = create_agent_card(agent_class)
        
        # 注册到A2A网络
        self.a2a_network.register(agent_card)
        
        # 更新Planner的能力认知
        self.planner.update_capabilities(agent_card.capabilities)
```

### 2. 水平扩展
```python
class LoadBalancer:
    async def get_agent_instance(self, agent_type: str):
        """获取智能体实例（负载均衡）"""
        instances = self.get_available_instances(agent_type)
        
        # 选择负载最低的实例
        selected = min(instances, key=lambda x: x.load)
        
        # 更新负载
        selected.load += 1
        
        return selected.url
```

## 总结

ValueCell的A2A协议架构实现了：

1. **模块化设计**: 每个智能体独立开发、部署
2. **标准化通信**: 统一的协议和消息格式
3. **高效协作**: 支持并行执行和流式响应
4. **弹性扩展**: 易于添加新智能体和扩展容量
5. **可靠运行**: 完善的错误处理和监控机制

这种架构使得ValueCell能够构建复杂的金融分析系统，同时保持系统的灵活性、可维护性和可扩展性。