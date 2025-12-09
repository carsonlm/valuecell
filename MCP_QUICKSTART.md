# MCP (Model Context Protocol) 快速入门指南

## 什么是 MCP？

MCP (Model Context Protocol) 是一个让 AI 模型能够安全、标准化地使用外部工具和数据的协议。在 ValueCell 项目中，我们虽然没有直接使用官方的 MCP 库，但实现了一套类似的架构，让你可以轻松地为 AI 智能体添加各种能力。

## 核心概念（简单版）

### 1. 工具 (Tools)
就像给 AI 安装的"小程序"，让 AI 能做更多事情：
- 搜索网页
- 读取文件
- 查询数据库
- 调用 API

### 2. 上下文 (Context)
AI 需要知道的信息：
- 用户是谁
- 之前聊过什么
- 现在是什么时间
- 用户偏好什么语言

### 3. 智能体 (Agents)
会使用工具的 AI 助手，每个助手有特定专长：
- 研究助手：分析股票、公司
- 新闻助手：获取最新资讯
- 交易助手：帮助投资决策

## 从零开始：创建你的第一个工具

### 步骤 1：创建简单的天气查询工具

```python
# weather_tools.py
import asyncio
from typing import Optional
from datetime import datetime
import aiohttp
from loguru import logger

async def get_weather(
    city: str,
    country: str = "CN",
    units: str = "metric"
) -> str:
    """
    获取指定城市的天气信息
    
    使用场景：
    - 当用户询问天气时
    - 当需要天气数据做决策时
    
    参数：
    - city: 城市名称，如"北京"、"上海"
    - country: 国家代码，默认"CN"（中国）
    - units: 温度单位，"metric"为摄氏度，"imperial"为华氏度
    
    返回：
    格式化的天气信息字符串
    """
    try:
        # 这里使用模拟数据，实际可以调用天气API
        weather_data = {
            "北京": {"temp": 25, "condition": "晴朗", "humidity": 40},
            "上海": {"temp": 28, "condition": "多云", "humidity": 65},
            "深圳": {"temp": 30, "condition": "阵雨", "humidity": 75},
        }
        
        if city in weather_data:
            data = weather_data[city]
            return (
                f"{city}的天气：\n"
                f"• 温度：{data['temp']}°C\n"
                f"• 天气：{data['condition']}\n"
                f"• 湿度：{data['humidity']}%\n"
                f"• 更新时间：{datetime.now().strftime('%Y-%m-%d %H:%M')}"
            )
        else:
            return f"抱歉，找不到{city}的天气信息"
            
    except Exception as e:
        logger.error(f"获取天气失败: {e}")
        return f"获取天气信息时出错：{str(e)}"

async def get_weather_forecast(
    city: str,
    days: int = 3
) -> str:
    """
    获取多日天气预报
    
    参数：
    - city: 城市名称
    - days: 预报天数（1-7）
    
    返回：
    多日天气预报
    """
    # 模拟天气预报数据
    forecasts = [
        {"day": "今天", "high": 26, "low": 18, "condition": "晴"},
        {"day": "明天", "high": 24, "low": 17, "condition": "多云"},
        {"day": "后天", "high": 22, "low": 16, "condition": "小雨"},
    ]
    
    result = [f"{city}未来{days}天天气预报："]
    for i in range(min(days, len(forecasts))):
        forecast = forecasts[i]
        result.append(
            f"{forecast['day']}: {forecast['condition']}, "
            f"温度 {forecast['low']}~{forecast['high']}°C"
        )
    
    return "\n".join(result)
```

### 步骤 2：创建使用工具的智能体

```python
# weather_agent.py
from typing import AsyncGenerator, Dict, Optional
from agno.agent import Agent
from agno.db.in_memory import InMemoryDb
from loguru import logger

from valuecell.core.agent import streaming
from valuecell.core.types import BaseAgent, StreamResponse

# 导入我们创建的工具
from weather_tools import get_weather, get_weather_forecast

class WeatherAgent(BaseAgent):
    """天气查询智能体"""
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        
        # 注册工具
        tools = [get_weather, get_weather_forecast]
        
        # 创建 Agno Agent
        self.agent = Agent(
            name="WeatherAgent",
            model="gpt-4",  # 可以使用其他模型
            instructions="""
            你是一个天气助手，专门帮助用户查询天气信息。
            
            你的能力：
            1. 查询当前天气
            2. 查询天气预报
            3. 根据天气给出建议
            
            回答要求：
            1. 友好、有帮助
            2. 提供准确的信息
            3. 必要时给出穿衣、出行建议
            """,
            tools=tools,
            db=InMemoryDb(),
            add_datetime_to_context=True,
        )
    
    async def stream(
        self,
        query: str,
        conversation_id: str,
        task_id: str,
        dependencies: Optional[Dict] = None,
    ) -> AsyncGenerator[StreamResponse, None]:
        """处理天气查询"""
        
        logger.info(f"处理天气查询: {query}")
        
        # 让 AI 处理查询（会自动调用合适的工具）
        response_stream = self.agent.arun(
            query,
            stream=True,
            stream_intermediate_steps=True,
            session_id=conversation_id,
        )
        
        # 处理流式响应
        async for event in response_stream:
            if event.event == "RunContent":
                # AI 的文本回复
                yield streaming.message_chunk(event.content)
            elif event.event == "ToolCallStarted":
                # 工具调用开始
                yield streaming.tool_call_started(
                    event.tool.tool_call_id,
                    event.tool.tool_name
                )
            elif event.event == "ToolCallCompleted":
                # 工具调用完成
                yield streaming.tool_call_completed(
                    event.tool.result,
                    event.tool.tool_call_id,
                    event.tool.tool_name
                )
        
        # 处理完成
        yield streaming.done()
```

### 步骤 3：配置智能体

```json
// 创建文件：agent_cards/WeatherAgent.json
{
  "name": "WeatherAgent",
  "url": "http://localhost:8003",
  "description": "天气查询助手，提供当前天气和天气预报",
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
  "display_name": "天气助手"
}
```

### 步骤 4：启动智能体服务器

```python
# start_weather_agent.py
import asyncio
from valuecell.core.agent.decorator import create_wrapped_agent
from weather_agent import WeatherAgent

if __name__ == "__main__":
    print("🚀 启动天气助手智能体...")
    print("📡 服务地址: http://localhost:8003")
    print("📋 等待连接...")
    
    # 创建并启动智能体
    agent = create_wrapped_agent(WeatherAgent)
    asyncio.run(agent.serve())
```

### 步骤 5：测试智能体

```python
# test_weather_agent.py
import asyncio
from valuecell.core.agent.client import AgentClient

async def test_weather_queries():
    """测试天气查询"""
    
    # 创建客户端
    client = AgentClient("http://localhost:8003")
    
    test_queries = [
        "北京今天天气怎么样？",
        "上海未来3天天气预报",
        "深圳的湿度和温度是多少？",
        "我应该带伞吗？",
    ]
    
    for query in test_queries:
        print(f"\n🔍 查询: {query}")
        print("-" * 40)
        
        async for remote_task, event in await client.send_message(query):
            if remote_task and remote_task.status.message:
                print(f"🤖 {remote_task.status.message.text}")
        
        print("-" * 40)

if __name__ == "__main__":
    asyncio.run(test_weather_queries())
```

## 进阶：创建股票查询工具

### 股票数据工具

```python
# stock_tools.py
import asyncio
from typing import Optional, List, Dict
import aiohttp
import yfinance as yf
from loguru import logger

async def get_stock_price(
    symbol: str,
    period: str = "1d",
    interval: str = "1h"
) -> str:
    """
    获取股票价格数据
    
    参数：
    - symbol: 股票代码，如"AAPL"、"MSFT"
    - period: 时间周期，"1d"、"5d"、"1mo"、"3mo"、"6mo"、"1y"、"2y"、"5y"、"10y"、"ytd"、"max"
    - interval: 时间间隔，"1m"、"2m"、"5m"、"15m"、"30m"、"60m"、"90m"、"1h"、"1d"、"5d"、"1wk"、"1mo"、"3mo"
    
    返回：
    股票价格信息
    """
    try:
        # 使用 yfinance 获取股票数据
        stock = yf.Ticker(symbol)
        
        # 获取历史价格
        hist = stock.history(period=period, interval=interval)
        
        if hist.empty:
            return f"无法获取 {symbol} 的价格数据"
        
        # 获取最新数据
        latest = hist.iloc[-1]
        info = stock.info
        
        result = [
            f"📈 {symbol} 股票信息",
            f"名称: {info.get('longName', 'N/A')}",
            f"当前价格: ${latest['Close']:.2f}",
            f"今日涨跌: {latest['Close'] - latest['Open']:.2f}",
            f"涨跌幅: {((latest['Close'] - latest['Open']) / latest['Open'] * 100):.2f}%",
            f"交易量: {latest['Volume']:,}",
            f"时间: {latest.name.strftime('%Y-%m-%d %H:%M')}",
        ]
        
        # 添加公司基本信息
        if 'sector' in info:
            result.append(f"行业: {info['sector']}")
        if 'marketCap' in info:
            market_cap = info['marketCap']
            if market_cap > 1e9:
                result.append(f"市值: ${market_cap/1e9:.2f}B")
        
        return "\n".join(result)
        
    except Exception as e:
        logger.error(f"获取股票数据失败: {e}")
        return f"获取股票信息时出错：{str(e)}"

async def get_stock_news(
    symbol: str,
    limit: int = 5
) -> str:
    """
    获取股票相关新闻
    
    参数：
    - symbol: 股票代码
    - limit: 新闻数量限制
    
    返回：
    股票新闻列表
    """
    try:
        stock = yf.Ticker(symbol)
        news = stock.news[:limit]
        
        if not news:
            return f"暂无 {symbol} 相关新闻"
        
        result = [f"📰 {symbol} 最新新闻 ({len(news)}条):"]
        
        for i, item in enumerate(news, 1):
            title = item.get('title', '无标题')
            publisher = item.get('publisher', '未知来源')
            link = item.get('link', '#')
            
            result.append(f"{i}. {title}")
            result.append(f"   来源: {publisher}")
            if 'thumbnail' in item:
                result.append(f"   图片: {item['thumbnail']['resolutions'][0]['url']}")
        
        return "\n".join(result)
        
    except Exception as e:
        logger.error(f"获取股票新闻失败: {e}")
        return f"获取新闻时出错：{str(e)}"

async def get_stock_financials(
    symbol: str
) -> str:
    """
    获取股票财务数据
    
    参数：
    - symbol: 股票代码
    
    返回：
    财务数据摘要
    """
    try:
        stock = yf.Ticker(symbol)
        
        # 获取财务数据
        financials = stock.financials
        balance_sheet = stock.balance_sheet
        cashflow = stock.cashflow
        
        if financials.empty:
            return f"无法获取 {symbol} 的财务数据"
        
        result = [f"💰 {symbol} 财务数据摘要"]
        
        # 收入数据
        if not financials.empty:
            revenue = financials.loc['Total Revenue'].iloc[0] if 'Total Revenue' in financials.index else None
            if revenue:
                result.append(f"总收入: ${revenue/1e9:.2f}B")
        
        # 利润数据
        net_income = financials.loc['Net Income'].iloc[0] if 'Net Income' in financials.index else None
        if net_income:
            result.append(f"净利润: ${net_income/1e9:.2f}B")
        
        # 资产负债表数据
        if not balance_sheet.empty:
            total_assets = balance_sheet.loc['Total Assets'].iloc[0] if 'Total Assets' in balance_sheet.index else None
            total_liabilities = balance_sheet.loc['Total Liabilities Net Minority Interest'].iloc[0] if 'Total Liabilities Net Minority Interest' in balance_sheet.index else None
            
            if total_assets:
                result.append(f"总资产: ${total_assets/1e9:.2f}B")
            if total_liabilities:
                result.append(f"总负债: ${total_liabilities/1e9:.2f}B")
        
        return "\n".join(result)
        
    except Exception as e:
        logger.error(f"获取财务数据失败: {e}")
        return f"获取财务数据时出错：{str(e)}"
```

### 股票分析智能体

```python
# stock_agent.py
from typing import AsyncGenerator, Dict, Optional
from agno.agent import Agent
from agno.db.in_memory import InMemoryDb
from loguru import logger

from valuecell.core.agent import streaming
from valuecell.core.types import BaseAgent, StreamResponse

# 导入股票工具
from stock_tools import get_stock_price, get_stock_news, get_stock_financials

class StockAgent(BaseAgent):
    """股票分析智能体"""
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        
        # 注册股票工具
        tools = [get_stock_price, get_stock_news, get_stock_financials]
        
        # 创建 Agno Agent
        self.agent = Agent(
            name="StockAgent",
            model="gpt-4",
            instructions="""
            你是一个专业的股票分析助手，帮助用户分析股票信息。
            
            你的能力：
            1. 查询股票实时价格
            2. 获取股票相关新闻
            3. 分析财务数据
            4. 提供投资建议
            
            回答要求：
            1. 专业、准确
            2. 数据驱动
            3. 提示风险
            4. 不提供具体的买卖建议
            
            重要提示：
            - 所有数据仅供参考
            - 投资有风险，入市需谨慎
            - 建议用户咨询专业投资顾问
            """,
            tools=tools,
            db=InMemoryDb(),
            add_datetime_to_context=True,
        )
    
    async def stream(
        self,
        query: str,
        conversation_id: str,
        task_id: str,
        dependencies: Optional[Dict] = None,
    ) -> AsyncGenerator[StreamResponse, None]:
        """处理股票查询"""
        
        logger.info(f"处理股票查询: {query}")
        
        # 添加投资风险提示
        yield streaming.message_chunk("📊 正在分析股票数据...")
        yield streaming.message_chunk("⚠️ 提示：以下信息仅供参考，投资有风险")
        
        # 让 AI 处理查询
        response_stream = self.agent.arun(
            query,
            stream=True,
            stream_intermediate_steps=True,
            session_id=conversation_id,
        )
        
        # 处理流式响应
        async for event in response_stream:
            if event.event == "RunContent":
                yield streaming.message_chunk(event.content)
            elif event.event == "ToolCallStarted":
                yield streaming.tool_call_started(
                    event.tool.tool_call_id,
                    event.tool.tool_name
                )
            elif event.event == "ToolCallCompleted":
                yield streaming.tool_call_completed(
                    event.tool.result,
                    event.tool.tool_call_id,
                    event.tool.tool_name
                )
        
        # 添加免责声明
        yield streaming.message_chunk("\n📌 免责声明：以上信息仅供参考，不构成投资建议。")
        yield streaming.done()
```

## 实战：创建个人助理智能体

### 综合工具集合

```python
# personal_assistant_tools.py
import asyncio
from typing import Optional, List
from datetime import datetime, timedelta
import aiohttp
import json
from loguru import logger

async def calculate(
    expression: str
) -> str:
    """
    计算数学表达式
    
    参数：
    - expression: 数学表达式，如"2+3*4"、"sqrt(16)"
    
    返回：
    计算结果
    """
    try:
        # 安全地评估表达式
        allowed_names = {
            'abs': abs, 'round': round, 'min': min, 'max': max,
            'pow': pow, 'sum': sum, 'len': len,
        }
        
        # 使用 ast 安全解析
        import ast
        
        # 这里简化处理，实际应该更安全
        result = eval(expression, {"__builtins__": {}}, allowed_names)
        return f"{expression} = {result}"
        
    except Exception as e:
        return f"计算失败：{str(e)}"

async def get_current_time(
    timezone: str = "Asia/Shanghai"
) -> str:
    """
    获取当前时间
    
    参数：
    - timezone: 时区名称
    
    返回：
    当前时间信息
    """
    from datetime import datetime
    import pytz
    
    try:
        tz = pytz.timezone(timezone)
        now = datetime.now(tz)
        
        return (
            f"🕐 当前时间：\n"
            f"• 日期：{now.strftime('%Y年%m月%d日')}\n"
            f"• 时间：{now.strftime('%H:%M:%S')}\n"
            f"• 时区：{timezone}\n"
            f"• 星期：{['一','二','三','四','五','六','日'][now.weekday()]}"
        )
    except Exception as e:
        return f"获取时间失败：{str(e)}"

async def convert_currency(
    amount: float,
    from_currency: str,
    to_currency: str
) -> str:
    """
    货币转换
    
    参数：
    - amount: 金额
    - from_currency: 源货币，如"USD"、"CNY"
    - to_currency: 目标货币
    
    返回：
    转换结果
    """
    try:
        # 模拟汇率数据
        exchange_rates = {
            "USD": {"CNY": 7.2, "EUR": 0.92, "JPY": 150},
            "CNY": {"USD": 0.14, "EUR": 0.13, "JPY": 21},
            "EUR": {"USD": 1.09, "CNY": 7.8, "JPY": 163},
        }
        
        if from_currency in exchange_rates and to_currency in exchange_rates[from_currency]:
            rate = exchange_rates[from_currency][to_currency]
            converted = amount * rate
            
            return (
                f"💱 货币转换：\n"
                f"• {amount} {from_currency} = {converted:.2f} {to_currency}\n"
                f"• 汇率：1 {from_currency} = {rate} {to_currency}\n"
                f"• 更新时间：{datetime.now().strftime('%Y-%m-%d')}"
            )
        else:
            return f"不支持 {from_currency} 到 {to_currency} 的转换"
            
    except Exception as e:
        return f"货币转换失败：{str(e)}"

async def create_reminder(
    task: str,
    time: str,
    repeat: str = "once"
) -> str:
    """
    创建提醒
    
    参数：
    - task: 提醒事项
    - time: 提醒时间，如"明天 10:00"、"2024-12-25 14:30"
    - repeat: 重复频率，"once"、"daily"、"weekly"、"monthly"
    
    返回：
    提醒创建确认
    """
    repeat_map = {
        "once": "一次",
        "daily": "每天",
        "weekly": "每周",
        "monthly": "每月",
    }
    
    repeat_text = repeat_map.get(repeat, "一次")
    
    return (
        f"⏰ 提醒已创建：\n"
        f"• 事项：{task}\n"
        f"• 时间：{time}\n"
        f"• 重复：{repeat_text}\n"
        f"• 创建时间：{datetime.now().strftime('%Y-%m-%d %H:%M')}"
    )
```

### 个人助理智能体

```python
# personal_assistant_agent.py
from typing import AsyncGenerator, Dict, Optional
from agno.agent import Agent
from agno.db.in_memory import InMemoryDb
from loguru import logger

from valuecell.core.agent import streaming
from valuecell.core.types import BaseAgent, StreamResponse

# 导入各种工具
from personal_assistant_tools import calculate, get_current_time, convert_currency, create_reminder
from weather_tools import get_weather, get_weather_forecast
from stock_tools import get_stock_price

class PersonalAssistantAgent(BaseAgent):
    """个人助理智能体"""
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        
        # 注册所有工具
        tools = [
            calculate,
            get_current_time,
            convert_currency,
            create_reminder,
            get_weather,
            get_weather_forecast,
            get_stock_price,
        ]
        
        # 创建 Agno Agent
        self.agent = Agent(
            name="PersonalAssistant",
            model="gpt-4",
            instructions="""
            你是一个全能个人助理，可以帮助用户处理各种日常事务。
            
            你的能力：
            1. 数学计算
            2. 时间查询
            3. 货币转换
            4. 提醒管理
            5. 天气查询
            6. 股票查询
            
            性格特点：
            1. 友好、耐心
            2. 乐于助人
            3. 细心周到
            4. 幽默风趣（适当的时候）
            
            回答风格：
            1. 使用表情符号让回答更生动
            2. 提供实用的建议
            3. 必要时询问更多细节
            4. 保持积极的态度
            """,
            tools=tools,
            db=InMemoryDb(),
            add_datetime_to_context=True,
            add_history_to_context=True,
            num_history_runs=5,
        )
    
    async def stream(
        self,
        query: str,
        conversation_id: str,
        task_id: str,
        dependencies: Optional[Dict] = None,
    ) -> AsyncGenerator[StreamResponse, None]:
        """处理用户查询"""
        
        logger.info(f"个人助理处理查询: {query}")
        
        # 友好的问候
        yield streaming.message_chunk("👋 你好！我是你的个人助理，很高兴为你服务！")
        
        # 让 AI 处理查询
        response_stream = self.agent.arun(
            query,
            stream=True,
            stream_intermediate_steps=True,
            session_id=conversation_id,
        )
        
        # 处理流式响应
        async for event in response_stream:
            if event.event == "RunContent":
                yield streaming.message_chunk(event.content)
            elif event.event == "ToolCallStarted":
                yield streaming.tool_call_started(
                    event.tool.tool_call_id,
                    event.tool.tool_name
                )
            elif event.event == "ToolCallCompleted":
                yield streaming.tool_call_completed(
                    event.tool.result,
                    event.tool.tool_call_id,
                    event.tool.tool_name
                )
        
        # 结束语
        yield streaming.message_chunk("\n😊 还有什么可以帮你的吗？")
        yield streaming.done()
```

## 运行你的智能体

### 1. 安装依赖
```bash
# 进入项目目录
cd valuecell/python

# 安装开发依赖
uv sync --group dev

# 安装额外工具包
pip install yfinance pytz aiohttp
```

### 2. 启动智能体
```bash
# 启动天气助手
python start_weather_agent.py

# 启动股票分析助手
python start_stock_agent.py

# 启动个人助理
python start_personal_assistant.py
```

### 3. 测试智能体
```bash
# 测试天气查询
python test_weather_agent.py

# 测试股票查询
python test_stock_agent.py

# 测试个人助理
python test_personal_assistant.py
```

## 常见问题解答

### Q1: 工具函数必须用 async 吗？
**A**: 是的，ValueCell 使用异步架构，工具函数应该用 `async def` 定义。

### Q2: 如何添加新的工具？
**A**: 只需：
1. 创建新的工具函数（用 `async def`）
2. 添加详细的文档字符串
3. 在智能体的 `tools` 列表中注册
4. 重启智能体服务器

### Q3: 工具调用失败怎么办？
**A**: 检查：
1. 工具函数是否有错误
2. 输入参数是否正确
3. 网络连接是否正常
4. 查看日志文件中的错误信息

### Q4: 如何让工具更智能？
**A**: 可以：
1. 添加更多的输入验证
2. 实现错误重试机制
3. 添加缓存功能
4. 提供更详细的错误信息

### Q5: 如何分享我的工具？
**A**: 可以：
1. 将工具函数放在单独的模块中
2. 通过 pip 打包分发
3. 在 GitHub 上开源
4. 提交到 ValueCell 社区

## 下一步学习

### 1. 学习高级特性
- 工具链：让工具可以调用其他工具
- 上下文共享：在工具间共享数据
- 权限控制：限制工具的使用权限
- 性能优化：提高工具的执行效率

### 2. 探索现有工具
查看 ValueCell 项目中已有的工具：
```bash
# 查看研究工具
ls valuecell/python/valuecell/agents/research_agent/sources.py

# 查看新闻工具
ls valuecell/python/valuecell/agents/news_agent/tools.py

# 查看交易工具
ls valuecell/python/valuecell/agents/common/trading/
```

### 3. 加入社区
- 阅读项目文档
- 查看示例代码
- 参与讨论
- 贡献代码

## 总结

通过这个快速入门指南，你学会了：

✅ 创建基本的工具函数  
✅ 注册工具到智能体  
✅ 配置智能体服务器  
✅ 测试工具调用  
✅ 创建综合的个人助理  

现在你可以开始创建自己的工具，让 AI 智能体变得更加强大！记住，好的工具应该：
1. 功能明确单一
2. 文档清晰完整
3. 错误处理完善
4. 性能高效稳定

祝你编码愉快！ 🚀

---
*有问题？查看完整文档：`MCP_IMPLEMENTATION.md`*