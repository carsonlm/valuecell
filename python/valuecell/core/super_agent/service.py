"""Service façade for the super agent orchestration stage."""

from __future__ import annotations

from typing import AsyncIterator

from valuecell.core.types import UserInput

from .core import SuperAgent, SuperAgentOutcome


class SuperAgentService:
    """Thin wrapper to expose SuperAgent behaviour as a service.

    中文说明：Super Agent服务类 - 将Super Agent行为封装为服务。
    这是一个薄包装层，主要目的：
    1. 提供统一的接口访问Super Agent功能
    2. 支持依赖注入（可以通过构造函数传入自定义的Super Agent实例）
    3. 作为协调器（Orchestrator）和底层Super Agent之间的桥梁
    """

    def __init__(self, super_agent: SuperAgent | None = None) -> None:
        """初始化Super Agent服务。

        Args:
            super_agent: 可选的Super Agent实例。如果为None，则创建新的默认实例。
                        这个设计支持依赖注入，便于测试和定制。

        中文说明：构造函数支持依赖注入模式。
        如果传入super_agent参数，则使用传入的实例；
        否则创建新的SuperAgent()实例。
        这种设计便于单元测试（可以传入mock对象）和功能扩展。
        """
        self._super_agent = super_agent or SuperAgent()

    @property
    def name(self) -> str:
        """获取Super Agent的名称。

        Returns:
            str: Super Agent的名称，默认为"ValueCellAgent"

        中文说明：这是一个只读属性，返回底层Super Agent的名称。
        在ValueCell架构中，名称用于标识和日志记录。
        """
        return self._super_agent.name

    async def run(
        self, user_input: UserInput
    ) -> AsyncIterator[str | SuperAgentOutcome]:
        """运行Super Agent处理用户输入。

        Args:
            user_input: 用户输入数据，包含查询内容和元数据

        Yields:
            AsyncIterator[str | SuperAgentOutcome]: 异步迭代器，产生两种类型的输出：
                - str: 流式输出的中间文本内容
                - SuperAgentOutcome: 最终决策结果（直接回答或转交规划器）

        中文说明：这是Super Agent服务的主要入口方法。
        它调用底层Super Agent的run()方法，并将结果原样返回。
        使用异步生成器（async for）支持流式输出，这对于：
        1. 实时显示处理进度
        2. 处理长时间运行的任务
        3. 提供更好的用户体验

        方法设计为异步迭代器，符合Python的异步编程最佳实践。
        """
        async for item in self._super_agent.run(user_input):
            yield item
