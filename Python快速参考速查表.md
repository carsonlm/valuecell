# Python快速参考速查表 - Java开发者版

## 一、语法速查

### 1.1 基础语法对比

| Java | Python | 说明 |
|------|--------|------|
| `System.out.println("Hello");` | `print("Hello")` | 输出 |
| `int x = 10;` | `x: int = 10` | 变量声明 |
| `final int MAX = 100;` | `MAX: Final[int] = 100` | 常量 |
| `String name = "John";` | `name: str = "John"` | 字符串 |
| `boolean flag = true;` | `flag: bool = True` | 布尔值 |
| `int[] arr = {1,2,3};` | `arr: list[int] = [1,2,3]` | 数组/列表 |
| `Map<String, Integer> map = new HashMap<>();` | `map: dict[str, int] = {}` | 字典/映射 |

### 1.2 控制结构

```python
# if-else
if score >= 90:
    grade = "A"
elif score >= 80:
    grade = "B"
else:
    grade = "C"

# for循环 (类似Java的增强for)
for item in items:
    print(item)

# 带索引的for循环
for i, item in enumerate(items):
    print(f"Index {i}: {item}")

# while循环
while count < 10:
    count += 1

# 列表推导式 (类似Java Stream)
squares = [x**2 for x in range(10) if x % 2 == 0]
# Java: IntStream.range(0,10).filter(x->x%2==0).map(x->x*x).toArray()
```

### 1.3 函数定义

```python
# 基本函数
def add(a: int, b: int) -> int:
    return a + b

# 默认参数
def greet(name: str = "Guest") -> str:
    return f"Hello, {name}"

# 可变参数 (*args类似Java的...)
def sum_all(*args: int) -> int:
    return sum(args)

# 关键字参数 (**kwargs类似Map)
def print_info(**kwargs):
    for key, value in kwargs.items():
        print(f"{key}: {value}")

# Lambda表达式 (类似Java的lambda)
square = lambda x: x ** 2
# Java: Function<Integer, Integer> square = x -> x * x;
```

## 二、面向对象编程

### 2.1 类定义

```python
from typing import Optional, List
from datetime import datetime

# 基类
class Person:
    # 类变量 (类似static)
    species: str = "Homo sapiens"
    
    # 构造方法
    def __init__(self, name: str, age: int):
        self.name = name  # 实例变量
        self.age = age
        self.created_at = datetime.now()
    
    # 实例方法
    def greet(self) -> str:
        return f"Hello, I'm {self.name}"
    
    # 类方法 (@classmethod类似static方法)
    @classmethod
    def create_anonymous(cls) -> "Person":
        return cls("Anonymous", 0)
    
    # 静态方法
    @staticmethod
    def is_adult(age: int) -> bool:
        return age >= 18
    
    # 属性装饰器 (类似getter)
    @property
    def birth_year(self) -> int:
        return datetime.now().year - self.age
    
    # 字符串表示 (类似toString())
    def __str__(self) -> str:
        return f"Person(name={self.name}, age={self.age})"
    
    # 相等性比较 (类似equals())
    def __eq__(self, other) -> bool:
        if not isinstance(other, Person):
            return False
        return self.name == other.name and self.age == other.age

# 继承
class Employee(Person):
    def __init__(self, name: str, age: int, employee_id: str):
        super().__init__(name, age)  # 调用父类构造方法
        self.employee_id = employee_id
    
    def work(self) -> str:
        return f"{self.name} is working"
```

### 2.2 抽象类和接口

```python
from abc import ABC, abstractmethod
from typing import Protocol

# 抽象类 (类似Java抽象类)
class Animal(ABC):
    @abstractmethod
    def make_sound(self) -> str:
        pass
    
    def sleep(self) -> str:
        return "Sleeping..."

# 协议 (类似Java接口)
class Flyable(Protocol):
    def fly(self) -> str: ...

class Bird(Animal, Flyable):
    def make_sound(self) -> str:
        return "Chirp!"
    
    def fly(self) -> str:
        return "Flying high"
```

## 三、异常处理

```python
# 基本异常处理
try:
    result = 10 / 0
except ZeroDivisionError as e:
    print(f"除零错误: {e}")
except ValueError as e:
    print(f"值错误: {e}")
except Exception as e:  # 类似catch(Exception e)
    print(f"未知错误: {e}")
else:
    print("没有异常发生")
finally:
    print("清理资源")  # 类似finally块

# 抛出异常
def validate_age(age: int):
    if age < 0:
        raise ValueError("年龄不能为负数")
    if age > 150:
        raise ValueError("年龄不合理")

# 自定义异常
class BusinessError(Exception):
    def __init__(self, message: str, code: int):
        super().__init__(message)
        self.code = code

try:
    raise BusinessError("业务错误", 1001)
except BusinessError as e:
    print(f"错误代码: {e.code}, 消息: {e}")
```

## 四、集合操作

### 4.1 列表操作

```python
# 创建列表
numbers = [1, 2, 3, 4, 5]

# 基本操作
numbers.append(6)           # 添加元素
numbers.insert(0, 0)        # 插入元素
numbers.remove(3)           # 删除元素
popped = numbers.pop()      # 弹出最后一个
popped = numbers.pop(0)     # 弹出第一个

# 列表切片 (类似subList)
first_three = numbers[:3]   # 前三个
last_two = numbers[-2:]     # 最后两个
middle = numbers[1:4]       # 索引1到3
reversed_list = numbers[::-1]  # 反转

# 列表推导式
even_squares = [x**2 for x in numbers if x % 2 == 0]
# Java: numbers.stream().filter(x->x%2==0).map(x->x*x).collect(Collectors.toList())
```

### 4.2 字典操作

```python
# 创建字典
person = {"name": "Alice", "age": 30, "city": "New York"}

# 基本操作
person["email"] = "alice@example.com"  # 添加/更新
value = person.get("name")             # 安全获取
value = person.get("country", "USA")   # 带默认值
del person["city"]                     # 删除键值对

# 遍历字典
for key in person:                     # 遍历键
    print(key)

for value in person.values():          # 遍历值
    print(value)

for key, value in person.items():      # 遍历键值对
    print(f"{key}: {value}")

# 字典推导式
squared_dict = {x: x**2 for x in range(5)}
```

### 4.3 集合操作

```python
# 创建集合
set1 = {1, 2, 3, 4, 5}
set2 = {4, 5, 6, 7, 8}

# 集合运算
union = set1 | set2        # 并集
intersection = set1 & set2 # 交集
difference = set1 - set2   # 差集
symmetric_diff = set1 ^ set2  # 对称差集

# 集合推导式
unique_squares = {x**2 for x in [1, 2, 2, 3, 3, 4]}
```

## 五、文件操作

```python
# 读取文件
with open("data.txt", "r", encoding="utf-8") as file:
    content = file.read()           # 读取全部
    lines = file.readlines()        # 读取所有行
    for line in file:               # 逐行读取
        print(line.strip())

# 写入文件
with open("output.txt", "w", encoding="utf-8") as file:
    file.write("Hello\n")
    file.writelines(["Line 1\n", "Line 2\n"])

# JSON处理
import json

# 读取JSON
with open("data.json", "r") as file:
    data = json.load(file)

# 写入JSON
with open("output.json", "w") as file:
    json.dump(data, file, indent=2)
```

## 六、异步编程

### 6.1 基础概念

```python
import asyncio

# 定义异步函数
async def fetch_data(url: str) -> dict:
    # 模拟异步操作
    await asyncio.sleep(1)
    return {"url": url, "data": "result"}

# 运行异步函数
async def main():
    # 单个任务
    result = await fetch_data("http://example.com")
    
    # 并行执行多个任务
    tasks = [
        fetch_data("http://example.com/1"),
        fetch_data("http://example.com/2"),
        fetch_data("http://example.com/3")
    ]
    results = await asyncio.gather(*tasks)
    
    # 超时控制
    try:
        result = await asyncio.wait_for(fetch_data(url), timeout=5.0)
    except asyncio.TimeoutError:
        print("请求超时")

# 在同步代码中运行
asyncio.run(main())
```

### 6.2 异步上下文管理器

```python
import aiohttp
import aiofiles

# 异步HTTP请求
async def fetch_url(url: str):
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as response:
            return await response.text()

# 异步文件操作
async def process_file(filepath: str):
    async with aiofiles.open(filepath, "r") as file:
        content = await file.read()
        # 处理内容
        return content
```

## 七、装饰器

```python
# 函数装饰器
def timer(func):
    import time
    def wrapper(*args, **kwargs):
        start = time.time()
        result = func(*args, **kwargs)
        end = time.time()
        print(f"{func.__name__} 执行时间: {end-start:.2f}秒")
        return result
    return wrapper

@timer
def slow_function():
    time.sleep(2)
    return "完成"

# 带参数的装饰器
def repeat(n: int):
    def decorator(func):
        def wrapper(*args, **kwargs):
            results = []
            for i in range(n):
                result = func(*args, **kwargs)
                results.append(result)
            return results
        return wrapper
    return decorator

@repeat(3)
def say_hello(name: str):
    return f"Hello, {name}"

# 类装饰器
class Singleton:
    def __init__(self, cls):
        self.cls = cls
        self.instance = None
    
    def __call__(self, *args, **kwargs):
        if self.instance is None:
            self.instance = self.cls(*args, **kwargs)
        return self.instance

@Singleton
class Database:
    def __init__(self):
        print("数据库连接已建立")
```

## 八、类型提示

### 8.1 基础类型

```python
from typing import List, Dict, Tuple, Set, Optional, Union, Any

# 基本类型
name: str = "Alice"
age: int = 30
price: float = 19.99
is_active: bool = True

# 集合类型
numbers: List[int] = [1, 2, 3]
person: Dict[str, Any] = {"name": "Alice", "age": 30}
coordinates: Tuple[float, float] = (40.7128, -74.0060)
unique_ids: Set[str] = {"id1", "id2", "id3"}

# 可选类型
middle_name: Optional[str] = None  # 可以是str或None

# 联合类型
identifier: Union[int, str] = 100  # 可以是int或str
identifier = "ABC123"  # 也可以

# 类型别名
UserId = int
UserMap = Dict[UserId, str]

# 回调函数类型
from typing import Callable
Processor = Callable[[str], str]

def process_text(text: str, processor: Processor) -> str:
    return processor(text)
```

### 8.2 泛型

```python
from typing import TypeVar, Generic

T = TypeVar('T')  # 任意类型
K = TypeVar('K')  # 键类型
V = TypeVar('V')  # 值类型

class Stack(Generic[T]):
    def __init__(self):
        self.items: List[T] = []
    
    def push(self, item: T) -> None:
        self.items.append(item)
    
    def pop(self) -> T:
        return self.items.pop()

# 使用
int_stack = Stack[int]()
int_stack.push(1)
int_stack.push(2)
value = int_stack.pop()  # value的类型是int
```

## 九、常用内置函数

```python
# 数学运算
abs(-5)           # 绝对值: 5
round(3.14159, 2) # 四舍五入: 3.14
pow(2, 3)         # 幂运算: 8
divmod(10, 3)     # 商和余数: (3, 1)

# 类型转换
int("123")        # 字符串转整数: 123
float("3.14")     # 字符串转浮点数: 3.14
str(123)          # 整数转字符串: "123"
list("abc")       # 字符串转列表: ['a', 'b', 'c']
tuple([1,2,3])    # 列表转元组: (1, 2, 3)
dict([('a',1),('b',2)])  # 列表转字典: {'a':1,'b':2}

# 迭代工具
len([1,2,3])      # 长度: 3
range(5)          # 生成序列: 0,1,2,3,4
enumerate(['a','b','c'])  # 枚举: (0,'a'),(1,'b'),(2,'c')
zip([1,2,3], ['a','b','c'])  # 合并: (1,'a'),(2,'b'),(3,'c')

# 排序和过滤
sorted([3,1,2])           # 排序: [1,2,3]
sorted([3,1,2], reverse=True)  # 降序: [3,2,1]
filter(lambda x: x>0, [-1,0,1,2])  # 过滤: [1,2]
map(lambda x: x*2, [1,2,3])        # 映射: [2,4,6]

# 聚合函数
sum([1,2,3,4])    # 求和: 10
min([1,2,3,4])    # 最小值: 1
max([1,2,3,4])    # 最大值: 4
any([False, True, False])  # 任意为真: True
all([True, True, False])   # 所有为真: False
```

## 十、ValueCell项目常用模式

### 10.1 Pydantic模型

```python
from pydantic import BaseModel, Field, validator
from typing import Optional
from datetime import datetime

class UserInput(BaseModel):
    query: str = Field(..., min_length=1, description="用户查询")
    user_id: str = Field(..., description="用户ID")
    timestamp: datetime = Field(default_factory=datetime.now)
    metadata: Optional[dict] = Field(default_factory=dict)
    
    @validator('query')
    def validate_query(cls, v):
        if len(v.strip()) == 0:
            raise ValueError("查询不能为空")
        return v.strip()
    
    class Config:
        frozen = True  # 不可变对象
        extra = "forbid"  # 禁止额外字段
```

### 10.2 异步生成器

```python
from typing import AsyncGenerator
import asyncio

async def stream_analysis(symbol: str) -> AsyncGenerator[str, None]:
    """流式返回分析结果"""
    yield f"开始分析 {symbol}..."
    await asyncio.sleep(0.5)
    
    yield "获取市场数据..."
    await asyncio.sleep(0.5)
    
    yield "计算技术指标..."
    await asyncio.sleep(0.5)
    
    yield "生成分析报告..."
    await asyncio.sleep(0.5)
    
    yield f"{symbol} 分析完成"

# 使用
async def main():
    async for chunk in stream_analysis("AAPL"):
        print(chunk)
```

### 10.3 依赖注入模式

```python
from typing import Protocol
from dataclasses import dataclass

class DataService(Protocol):
    async def fetch_data(self, symbol: str) -> dict: ...

@dataclass
class AnalysisService:
    data_service: DataService  # 依赖注入
    
    async def analyze(self, symbol: str) -> dict:
        data = await self.data_service.fetch_data(symbol)
        # 分析逻辑
        return {"symbol": symbol, "analysis": "看好"}

# 使用
class YahooFinanceService:
    async def fetch_data(self, symbol: str) -> dict:
        # 实现数据获取
        return {"price": 150.0}

service = AnalysisService(data_service=YahooFinanceService())
result = await service.analyze("AAPL")
```

## 十一、调试技巧

```python
# 1. 使用pdb调试器
import pdb

def buggy_function():
    x = 10
    y = 0
    pdb.set_trace()  # 设置断点
    result = x / y   # 这里会出错
    return result

# 调试命令:
# n - 下一步
# s - 进入函数
# c - 继续执行
# p variable - 打印变量
# l - 显示代码
# q - 退出

# 2. 使用logging调试
import logging

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

def process_data(data):
    logger.debug(f"开始处理数据: {data}")
    try:
        result = complex_operation(data)
        logger.info(f"处理成功: {result}")
        return result
    except Exception as e:
        logger.error(f"处理失败: {e}", exc_info=True)
        raise

# 3. 性能分析
import cProfile
import pstats

def profile_function():
    profiler = cProfile.Profile()
    profiler.enable()
    
    # 运行要分析的代码
    result = expensive_function()
    
    profiler.disable()
    stats = pstats.Stats(profiler)
    stats.sort_stats('cumulative')
    stats.print_stats(10)  # 打印前10个最耗时的函数
```

## 十二、常用快捷键（VS Code）

| 操作 | 快捷键 | 说明 |
|------|--------|------|
| 格式化代码 | Shift + Alt + F | 使用Ruff格式化 |
| 快速修复 | Ctrl + . | 显示快速修复建议 |
| 转到定义 | F12 | 跳转到定义处 |
| 查看引用 | Shift + F12 | 查看所有引用 |
| 重命名符号 | F2 | 重命名变量/函数 |
| 折叠代码 | Ctrl + Shift + [ | 折叠当前区域 |
| 展开代码 | Ctrl + Shift + ] | 展开当前区域 |
| 多行编辑 | Alt + 点击 | 添加多个光标 |
| 运行测试 | Ctrl + ; t | 运行当前测试 |
| 调试启动 | F5 | 启动调试 |
| 调试继续 | F5 | 继续执行 |
| 调试下一步 | F10 | 单步跳过 |
| 调试进入 | F11 | 单步进入 |

---

**记住**: Python是"电池内置"的语言，很多功能都有内置库支持。遇到问题时，先查Python标准库文档，再考虑第三方库。

祝您Python编程愉快！ 🐍