# A2A (Agent-to-Agent) 在 ValueCell 中的应用详解

## 概述

A2A (Agent-to-Agent) 是 ValueCell 平台的核心通信协议，它允许不同的智能体之间进行标准化、类型安全的通信。基于 `a2a-sdk` 实现，A2A 提供了完整的智能体发现、通信和状态管理功能。

## 架构设计

### 1. A2A 协议栈

```
┌─────────────────────────────────────────┐
│           ValueCell 应用层              │
├─────────────────────────────────────────┤
│      A2A 客户端/服务器包装层            │
├─────────────────────────────────────────┤
│           a2a-sdk 核心库                │
├─────────────────────────────────────────┤
│          HTTP/WebSocket 传输层          │
└─────────────────────────────────────────┘
```

### 2. 核心组件

#### 2.1 AgentCard (智能体名片)
每个智能体都有一个 `AgentCard`，包含：
- `name`: 智能体名称
- `url`: 智能体服务地址
- `capabilities`: 能力描述（流式响应、推送通知等）
- `description`: 智能体描述
- `version`: 版本信息

#### 2.2 AgentClient (智能体客户端)
负责与远程智能体通信：
- 解析 AgentCard
- 建立 HTTP 连接
- 发送消息并接收流式响应
- 处理推送通知

#### 2.3 AgentExecutor (智能体执行器)
包装本地智能体，使其符合 A2A 协议：
- 将本地智能体转换为 A2A 兼容的服务
- 处理请求上下文和事件队列
- 管理任务状态更新

## 实现细节

### 1. 智能体客户端实现

```python
# valuecell/python/valuecell/core/agent/client.py
class AgentClient:
    """Client for communicating with remote agents via A2A protocol."""
    
    async def send_message(
        self,
        query: str,
        conversation_id: str = None,
        metadata: dict = None,
        streaming: bool = True,
    ) -> AsyncIterator[RemoteAgentResponse]:
        """Send a message to the remote agent and return an async iterator."""
        
        # 1. 确保客户端已初始化
        await self.ensure_initialized()
        
        # 2. 创建 A2A 消息
        message = Message(
            role=Role.user,
            parts=[Part(root=TextPart(text=query))],
            message_id=generate_uuid("msg"),
            context_id=conversation_id or generate_uuid("ctx"),
            metadata=metadata if metadata else None,
        )
        
        # 3. 发送消息并获取响应流
        source_gen = self._client.send_message(message)
        
        # 4. 包装响应流
        async def wrapper() -> AsyncIterator[RemoteAgentResponse]:
            try:
                if streaming:
                    async for item in source_gen:
                        yield item
                else:
                    item = await source_gen.__anext__()
                    yield item
            finally:
                await source_gen.aclose()
        
        return wrapper()
```

### 2. 智能体服务器包装

```python
# valuecell/python/valuecell/core/agent/decorator.py
def _serve(agent_card: AgentCard):
    """Create a decorator that wraps an agent class with server capabilities."""
    
    def decorator(cls: Type) -> Type:
        class DecoratedAgent(cls):
            async def serve(self):
                # 1. 创建 AgentExecutor 包装器
                self._executor = _create_agent_executor(self)
                
                # 2. 设置服务器组件
                request_handler = DefaultRequestHandler(
                    agent_executor=self._executor,
                    task_store=InMemoryTaskStore(),
                    push_config_store=push_notification_config_store,
                    push_sender=push_notification_sender,
                )
                
                # 3. 创建 A2A Starlette 应用
                server_app = A2AStarletteApplication(
                    agent_card=self.agent_card,
                    http_handler=request_handler,
                )
                
                # 4. 启动服务器
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

### 3. 智能体执行器

```python
# valuecell/python/valuecell/core/agent/decorator.py
class GenericAgentExecutor(AgentExecutor):
    """Generic executor for BaseAgent implementations."""
    
    async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
        """Execute the agent with the given context and event queue."""
        
        # 1. 准备查询和任务
        query = context.get_user_input()
        task = context.current_task
        
        # 2. 更新任务状态为进行中
        await updater.update_status(
            TaskState.working,
            message=new_agent_text_message(
                f"Task received by {agent_name}", context_id, task_id
            ),
        )
        
        # 3. 执行智能体并流式处理响应
        async for response in query_handler(
            query, context_id, task_id, dependencies
        ):
            # 4. 根据响应类型处理事件
            if EventPredicates.is_tool_call(response_event):
                metadata["tool_call_id"] = response.metadata.get("tool_call_id")
                await updater.update_status(
                    TaskState.working,
                    message=new_agent_text_message(response.content or ""),
                    metadata=metadata,
                )
                continue
            
            # 5. 更新任务状态
            await updater.update_status(
                TaskState.working,
                message=new_agent_text_message(response.content or ""),
                metadata=metadata,
            )
        
        # 6. 完成任务
        await updater.complete()
```

## 使用示例

### 1. 创建本地智能体

```python
# valuecell/python/valuecell/agents/research_agent/core.py
class ResearchAgent(BaseAgent):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        # 初始化工具和知识库
        tools = [fetch_periodic_sec_filings, web_search, ...]
        knowledge = get_knowledge()
        
        self.knowledge_research_agent = Agent(
            model=get_model_for_agent("research_agent"),
            instructions=[KNOWLEDGE_AGENT_INSTRUCTION],
            expected_output=KNOWLEDGE_AGENT_EXPECTED_OUTPUT,
            tools=tools,
            knowledge=knowledge,
            db=InMemoryDb(),
        )
    
    async def stream(self, query: str, conversation_id: str, task_id: str, dependencies=None):
        # 执行智能体并流式返回响应
        response_stream = self.knowledge_research_agent.arun(
            query,
            stream=True,
            stream_intermediate_steps=True,
            session_id=conversation_id,
        )
        
        async for event in response_stream:
            if event.event == "RunContent":
                yield streaming.message_chunk(event.content)
            elif event.event == "ToolCallStarted":
                yield streaming.tool_call_started(
                    event.tool.tool_call_id, event.tool.tool_name
                )
            elif event.event == "ToolCallCompleted":
                yield streaming.tool_call_completed(
                    event.tool.result, event.tool.tool_call_id, event.tool.tool_name
                )
        
        yield streaming.done()
```

### 2. 启动智能体服务器

```python
# valuecell/python/valuecell/agents/research_agent/__main__.py
import asyncio
from valuecell.core.agent.decorator import create_wrapped_agent
from .core import ResearchAgent

if __name__ == "__main__":
    # 创建包装后的智能体实例
    agent = create_wrapped_agent(ResearchAgent)
    # 启动 A2A 服务器
    asyncio.run(agent.serve())
```

### 3. 任务执行器调用远程智能体

```python
# valuecell/python/valuecell/core/task/executor.py
async def _execute_single_task_run(self, task: Task, thread_id: str, metadata: dict):
    agent_name = task.agent_name
    
    # 1. 获取智能体客户端
    client = await self._agent_connections.get_client(agent_name)
    
    # 2. 发送消息到远程智能体
    remote_response = await client.send_message(
        task.query,
        conversation_id=task.conversation_id,
        metadata=metadata,
    )
    
    # 3. 处理流式响应
    async for remote_task, event in remote_response:
        if event is None and remote_task.status.state == TaskState.submitted:
            task.remote_task_ids.append(remote_task.id)
            # 发送任务开始事件
            started = self._event_service.factory.task_started(...)
            yield await self._event_service.emit(started)
        
        # 4. 路由任务状态事件
        route_result = self._event_service.router.route_task_status(
            remote_task, event, task.conversation_id, thread_id, task.task_id
        )
        
        if route_result.side_effect == SideEffectKind.fail_task:
            await self._task_service.fail_task(task.task_id, "Remote agent failed")
        
        for response in route_result.responses:
            yield await self._event_service.emit(response)
```

## 配置管理

### 1. AgentCard 配置

智能体配置通过 JSON 文件管理：

```json
{
  "name": "ResearchAgent",
  "url": "http://localhost:8000",
  "description": "Financial research agent with SEC filings and web search capabilities",
  "capabilities": {
    "streaming": true,
    "push_notifications": false
  },
  "default_input_modes": [],
  "default_output_modes": [],
  "version": "1.0.0",
  "enabled": true,
  "metadata": {
    "planner_passthrough": false,
    "hidden": false
  },
  "display_name": "Research Agent"
}
```

### 2. 智能体连接管理

```python
# valuecell/python/valuecell/core/agent/connect.py
@dataclass
class AgentContext:
    """Unified context for remote agents."""
    
    name: str
    url: Optional[str] = None
    local_agent_card: Optional[AgentCard] = None
    listener_task: Optional[asyncio.Task] = None
    listener_url: Optional[str] = None
    client: Optional[AgentClient] = None
    metadata: Optional[Dict[str, Any]] = None
    agent_instance: Optional[BaseAgent] = None
    agent_task: Optional[asyncio.Task] = None
```

## 通信流程

### 1. 智能体发现流程

```
1. 客户端请求智能体URL
2. 解析 AgentCard
3. 验证智能体能力
4. 建立连接池
```

### 2. 消息处理流程

```
1. 用户输入 → 任务执行器
2. 任务执行器 → AgentClient
3. AgentClient → 远程智能体 (HTTP)
4. 远程智能体 → 流式响应
5. 响应 → 事件路由器
6. 事件 → UI/存储
```

### 3. 状态管理流程

```
1. 任务创建 → TaskState.submitted
2. 智能体接收 → TaskState.working
3. 流式响应 → 多个 TaskState.working (带消息)
4. 完成/失败 → TaskState.completed/failed
```

## 错误处理

### 1. 连接错误

```python
try:
    self.agent_card = await card_resolver.get_agent_card()
except Exception as e:
    raise RuntimeError(
        "Failed to resolve agent card. Maybe the agent URL is incorrect or the agent is unreachable."
        " Check the agent logs for more details."
    ) from e
```

### 2. 执行错误

```python
try:
    async for response in query_handler(...):
        # 处理响应
        pass
except Exception as e:
    message = f"Error during {agent_name} agent execution: {e}"
    logger.error(message)
    await updater.update_status(
        TaskState.failed,
        message=new_agent_text_message(message, context_id, task_id),
    )
```

## 最佳实践

### 1. 智能体设计原则

1. **单一职责**: 每个智能体专注于特定领域
2. **异步优先**: 所有I/O操作使用异步API
3. **流式响应**: 支持增量结果返回
4. **错误恢复**: 优雅处理连接中断

### 2. 性能优化

1. **连接复用**: 使用 httpx.AsyncClient 连接池
2. **懒加载**: 智能体资源按需初始化
3. **缓存策略**: 智能体卡片和配置缓存
4. **超时控制**: 合理设置请求超时

### 3. 监控和调试

1. **结构化日志**: 使用 loguru 记录关键事件
2. **指标收集**: 跟踪请求延迟、错误率
3. **健康检查**: 定期验证智能体可用性
4. **追踪ID**: 使用 correlation_id 跟踪请求链

## 扩展性

### 1. 添加新智能体

1. 创建智能体类继承 `BaseAgent`
2. 实现 `stream` 或 `notify` 方法
3. 添加智能体配置到 agent_cards 目录
4. 使用 `create_wrapped_agent` 包装

### 2. 自定义传输协议

1. 实现自定义 `AgentClient` 子类
2. 重写 `send_message` 方法
3. 注册到 `RemoteConnections`

### 3. 插件系统

1. 工具插件: 通过 `tools` 参数添加
2. 知识插件: 通过 `knowledge` 参数添加
3. 存储插件: 实现自定义存储后端

## 总结

ValueCell 的 A2A 实现提供了一个强大而灵活的智能体通信框架，具有以下特点：

1. **标准化协议**: 基于 a2a-sdk 的标准化通信
2. **类型安全**: 完整的类型提示和验证
3. **异步流式**: 支持实时流式响应
4. **易于扩展**: 模块化设计，易于添加新智能体
5. **生产就绪**: 包含错误处理、监控和配置管理

通过 A2A 协议，ValueCell 实现了真正的多智能体协作，为金融应用提供了强大的智能体编排能力。