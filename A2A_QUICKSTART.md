# A2A (Agent-to-Agent) 快速入门指南

## 什么是A2A？

A2A (Agent-to-Agent) 是ValueCell平台中智能体之间通信的标准协议。它基于`a2a-sdk`实现，提供了智能体发现、通信和状态管理的完整解决方案。

## 核心概念

### 1. AgentCard (智能体名片)
每个智能体都有一个名片，包含：
- `name`: 智能体名称
- `url`: 服务地址
- `capabilities`: 支持的能力（流式响应、推送通知等）
- `description`: 智能体描述

### 2. AgentClient (智能体客户端)
用于与远程智能体通信的客户端。

### 3. AgentExecutor (智能体执行器)
将本地智能体包装为A2A兼容的服务。

## 快速开始

### 步骤1：创建基础智能体

```python
# my_agent.py
from typing import AsyncGenerator, Dict, Optional
from valuecell.core.types import BaseAgent, StreamResponse
from valuecell.core.agent import streaming

class MySimpleAgent(BaseAgent):
    """一个简单的示例智能体"""
    
    async def stream(
        self,
        query: str,
        conversation_id: str,
        task_id: str,
        dependencies: Optional[Dict] = None,
    ) -> AsyncGenerator[StreamResponse, None]:
        """流式处理用户查询"""
        
        # 返回欢迎消息
        yield streaming.message_chunk(f"你好！我是MySimpleAgent。")
        yield streaming.message_chunk(f"你问我：{query}")
        
        # 模拟一些处理
        yield streaming.reasoning("正在分析你的问题...")
        
        # 返回最终结果
        yield streaming.message_chunk("处理完成！")
        yield streaming.done()
```

### 步骤2：创建智能体配置

```json
// agent_cards/MySimpleAgent.json
{
  "name": "MySimpleAgent",
  "url": "http://localhost:8001",
  "description": "一个简单的示例智能体",
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
  "display_name": "我的简单智能体"
}
```

### 步骤3：启动智能体服务器

```python
# start_agent.py
import asyncio
from valuecell.core.agent.decorator import create_wrapped_agent
from my_agent import MySimpleAgent

if __name__ == "__main__":
    # 创建包装后的智能体
    agent = create_wrapped_agent(MySimpleAgent)
    
    print("启动MySimpleAgent服务器...")
    print("访问地址: http://localhost:8001")
    
    # 启动服务器
    asyncio.run(agent.serve())
```

### 步骤4：调用远程智能体

```python
# call_agent.py
import asyncio
from valuecell.core.agent.client import AgentClient

async def main():
    # 创建客户端
    client = AgentClient("http://localhost:8001")
    
    print("正在调用远程智能体...")
    
    # 发送消息并接收流式响应
    async for remote_task, event in await client.send_message("你好，今天天气怎么样？"):
        if event:
            print(f"事件: {event}")
        if remote_task:
            print(f"任务状态: {remote_task.status.state}")
            if remote_task.status.message:
                print(f"消息: {remote_task.status.message.text}")

if __name__ == "__main__":
    asyncio.run(main())
```

## 完整示例：研究智能体

### 1. 创建研究智能体

```python
# research_agent.py
import os
from typing import AsyncGenerator, Dict, Optional

from agno.agent import Agent
from agno.db.in_memory import InMemoryDb
from loguru import logger

from valuecell.core.agent import streaming
from valuecell.core.types import BaseAgent, StreamResponse

class ResearchAgent(BaseAgent):
    """研究智能体，用于金融数据分析"""
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        
        # 初始化Agno Agent
        self.agent = Agent(
            name="ResearchAgent",
            model="gpt-4",
            instructions="你是一个金融研究助手，帮助用户分析股票、基金等金融产品。",
            tools=[],  # 可以添加工具
            db=InMemoryDb(),
        )
    
    async def stream(
        self,
        query: str,
        conversation_id: str,
        task_id: str,
        dependencies: Optional[Dict] = None,
    ) -> AsyncGenerator[StreamResponse, None]:
        """处理研究查询"""
        
        yield streaming.message_chunk(f"🔍 开始分析: {query}")
        yield streaming.reasoning("正在收集市场数据...")
        
        # 使用Agno Agent处理查询
        response_stream = self.agent.arun(
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
        
        yield streaming.message_chunk("✅ 分析完成")
        yield streaming.done()
```

### 2. 配置研究智能体

```json
// agent_cards/ResearchAgent.json
{
  "name": "ResearchAgent",
  "url": "http://localhost:8002",
  "description": "金融研究智能体，提供股票、基金等金融产品分析",
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
  "display_name": "研究智能体"
}
```

### 3. 在任务执行器中调用

```python
# task_executor_example.py
import asyncio
from valuecell.core.agent.connect import RemoteConnections
from valuecell.core.task.models import Task

async def execute_research_task():
    """执行研究任务示例"""
    
    # 初始化远程连接
    connections = RemoteConnections()
    
    # 创建任务
    task = Task(
        task_id="task_001",
        conversation_id="conv_001",
        agent_name="ResearchAgent",
        query="分析一下苹果公司(AAPL)的股票表现",
        title="AAPL股票分析",
    )
    
    # 获取客户端
    client = await connections.get_client("ResearchAgent")
    if not client:
        print("无法连接到ResearchAgent")
        return
    
    print("正在执行研究任务...")
    
    # 发送消息
    metadata = {
        "user_id": "user_001",
        "priority": "high"
    }
    
    async for remote_task, event in await client.send_message(
        task.query,
        conversation_id=task.conversation_id,
        metadata=metadata,
        streaming=True
    ):
        if event:
            print(f"收到事件: {type(event).__name__}")
        if remote_task and remote_task.status.message:
            print(f"智能体响应: {remote_task.status.message.text}")

if __name__ == "__main__":
    asyncio.run(execute_research_task())
```

## 高级功能

### 1. 添加工具支持

```python
from agno.tools import DuckDuckGoSearch, ExaSearch

class ToolEnhancedAgent(BaseAgent):
    """带有工具的智能体"""
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        
        # 添加搜索工具
        self.agent = Agent(
            name="ToolEnhancedAgent",
            model="gpt-4",
            instructions="使用可用工具帮助用户",
            tools=[
                DuckDuckGoSearch(),
                ExaSearch(),
            ],
            db=InMemoryDb(),
        )
    
    async def stream(self, query, conversation_id, task_id, dependencies=None):
        # ... 实现流式响应
        pass
```

### 2. 处理依赖关系

```python
async def stream_with_dependencies(
    self,
    query: str,
    conversation_id: str,
    task_id: str,
    dependencies: Optional[Dict] = None,
):
    """处理带依赖关系的查询"""
    
    if dependencies:
        user_profile = dependencies.get("user_profile", {})
        risk_level = user_profile.get("risk_tolerance", "medium")
        
        yield streaming.message_chunk(f"根据您的风险承受能力({risk_level})进行分析...")
    
    # 继续处理...
```

### 3. 错误处理

```python
async def stream_with_error_handling(
    self,
    query: str,
    conversation_id: str,
    task_id: str,
    dependencies: Optional[Dict] = None,
):
    """带错误处理的流式响应"""
    
    try:
        # 正常处理
        yield streaming.message_chunk("开始处理...")
        
        # 模拟可能出错的操作
        if "error" in query.lower():
            raise ValueError("模拟错误发生")
        
        yield streaming.message_chunk("处理成功")
        yield streaming.done()
        
    except Exception as e:
        logger.error(f"智能体执行错误: {e}")
        yield streaming.message_chunk(f"抱歉，处理时出现错误: {str(e)}")
        yield streaming.task_failed(f"任务失败: {str(e)}")
```

## 调试技巧

### 1. 查看智能体卡片

```python
import asyncio
from valuecell.core.agent.client import AgentClient

async def check_agent_card():
    client = AgentClient("http://localhost:8001")
    card = await client.get_agent_card()
    print(f"智能体名称: {card.name}")
    print(f"描述: {card.description}")
    print(f"能力: {card.capabilities}")

asyncio.run(check_agent_card())
```

### 2. 监控通信

```python
import httpx
from loguru import logger

# 启用详细日志
logger.add("agent_communication.log", level="DEBUG")

# 创建带日志的客户端
client = httpx.AsyncClient(
    timeout=30,
    event_hooks={
        'request': [lambda req: logger.debug(f"发送请求: {req.method} {req.url}")],
        'response': [lambda resp: logger.debug(f"收到响应: {resp.status_code}")],
    }
)
```

### 3. 测试流式响应

```python
async def test_streaming():
    client = AgentClient("http://localhost:8001")
    
    print("测试流式响应...")
    count = 0
    
    async for remote_task, event in await client.send_message(
        "测试消息",
        streaming=True
    ):
        count += 1
        print(f"收到第{count}个响应")
        
        if count >= 10:  # 限制测试数量
            break
    
    print(f"总共收到{count}个响应")
```

## 常见问题

### Q1: 智能体无法启动
**检查项**:
1. 端口是否被占用
2. AgentCard配置是否正确
3. 依赖是否安装完整

### Q2: 客户端连接失败
**解决方案**:
```python
# 增加超时时间
client = AgentClient("http://localhost:8001")
await client.ensure_initialized()  # 这会解析AgentCard
```

### Q3: 流式响应不工作
**调试步骤**:
1. 检查智能体是否支持`streaming`能力
2. 验证网络连接
3. 查看智能体日志

### Q4: 如何添加新工具？
**步骤**:
1. 在智能体初始化时添加工具
2. 在stream方法中处理工具调用事件
3. 测试工具集成

## 下一步

1. **阅读完整文档**: 查看 `A2A_IMPLEMENTATION.md` 了解详细实现
2. **探索现有智能体**: 研究 `valuecell/agents/` 目录中的示例
3. **集成到ValueCell**: 将智能体添加到ValueCell平台
4. **性能优化**: 学习连接池、缓存等高级特性

## 资源

- [a2a-sdk文档](https://github.com/ai2a/a2a-sdk)
- [ValueCell架构文档](../docs/CORE_ARCHITECTURE.md)
- [Agno框架文档](https://agno.com/docs)

---

**提示**: 运行智能体前确保已安装依赖:
```bash
uv sync --group dev
```

开始构建你的第一个A2A智能体吧！🚀