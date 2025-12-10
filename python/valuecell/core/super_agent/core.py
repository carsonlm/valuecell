import asyncio
from enum import Enum
from typing import AsyncIterator, Optional

from agno.agent import Agent  # Agno AI智能体框架，用于构建和管理AI代理
from agno.db.in_memory import InMemoryDb  # 内存数据库，用于存储会话历史
from loguru import logger  # 现代化的日志记录库
from pydantic import BaseModel, Field  # 数据验证和序列化库

import valuecell.utils.model as model_utils_mod  # 模型工具模块，处理模型配置
from valuecell.core.super_agent.prompts import (
    SUPER_AGENT_INSTRUCTION,  # Super Agent的指令提示词
)
from valuecell.core.types import UserInput  # 用户输入数据模型
from valuecell.utils.env import (
    agent_debug_mode_enabled,  # 环境变量检查，判断是否启用调试模式
)


class SuperAgentDecision(str, Enum):
    """Super Agent决策枚举 - 定义Super Agent可以做出的两种决策类型"""

    ANSWER = "answer"  # 直接回答：Super Agent可以自己回答用户的问题
    HANDOFF_TO_PLANNER = "handoff_to_planner"  # 转交给规划器：将问题交给规划器处理


class SuperAgentOutcome(BaseModel):
    """Super Agent执行结果数据模型 - 包含决策和相关信息"""

    decision: SuperAgentDecision = Field(..., description="Super Agent's decision")
    # Optional enriched result data
    answer_content: Optional[str] = Field(
        None, description="Optional direct answer when decision is 'answer'"
    )
    enriched_query: Optional[str] = Field(
        None, description="Optional concise restatement to forward to Planner"
    )
    reason: Optional[str] = Field(None, description="Brief rationale for the decision")


class SuperAgent:
    """Lightweight Super Agent that triages user intent before planning.

    Minimal stub implementation: returns HANDOFF_TO_PLANNER immediately.
    Future versions can stream content, ask for user input via callback,
    or directly produce tasks/plans.

    中文说明：轻量级Super Agent，在规划前对用户意图进行分流（triage）。
    这是系统的"总指挥AI"，负责判断用户请求的类型：
    1. 简单问题：直接回答（如问候、简单查询）
    2. 复杂问题：转交给规划器处理（如股票分析、投资建议）
    最小化实现：目前总是返回HANDOFF_TO_PLANNER。
    未来版本可以流式传输内容、通过回调询问用户输入，或直接生成任务/计划。
    """

    name: str = "ValueCellAgent"  # 智能体名称

    def __init__(self) -> None:
        # Lazy initialize: avoid constructing Agent at startup
        # 延迟初始化：避免在启动时构建Agent，提高启动速度
        self.agent: Optional[Agent] = None

    def _get_or_init_agent(self) -> Optional[Agent]:
        """Create the underlying agent on first use.

        Returns the initialized Agent or None if initialization fails.

        中文说明：创建底层Agent（首次使用时）。
        实现懒加载模式：
        1. 首次调用时创建Agent实例
        2. 检查模型配置是否变化，必要时重新创建
        3. 处理初始化失败的情况

        Returns:
            Optional[Agent]: 初始化后的Agent实例，如果初始化失败则返回None
        """

        def _build_agent(with_model) -> Agent:
            # Disable session summaries for DashScope models
            # DashScope requires 'json' word in messages when using response_format: json_object
            # but agno's internal summary feature doesn't include this, causing 400 errors

            # 中文说明：内部函数：根据给定的模型配置构建Agent实例。
            # 为DashScope模型禁用会话摘要功能
            # DashScope在使用response_format: json_object时需要在消息中包含'json'关键词
            # 但agno的内部摘要功能不包含这个关键词，会导致400错误
            enable_summaries = not model_utils_mod.model_should_use_json_mode(
                with_model
            )

            return Agent(
                model=with_model,  # 主模型
                parser_model=with_model,  # 解析模型（与主模型相同）
                markdown=False,  # 禁用Markdown格式
                debug_mode=agent_debug_mode_enabled(),  # 根据环境变量启用调试模式
                instructions=[SUPER_AGENT_INSTRUCTION],  # Super Agent的指令
                # expected_output=SUPER_AGENT_EXPECTED_OUTPUT,  # 注释掉的预期输出
                output_schema=SuperAgentOutcome,  # 输出数据模型
                use_json_mode=model_utils_mod.model_should_use_json_mode(
                    with_model
                ),  # 是否使用JSON模式
                db=InMemoryDb(),  # 内存数据库，存储会话历史
                add_datetime_to_context=True,  # 在上下文中添加时间信息
                add_history_to_context=True,  # 在上下文中添加历史记录
                num_history_runs=5,  # 保留最近5次对话历史
                read_chat_history=True,  # 读取聊天历史
                enable_session_summaries=enable_summaries,  # 是否启用会话摘要
            )

        try:
            # 从配置中获取super_agent应该使用的模型
            expected_model = model_utils_mod.get_model_for_agent("super_agent")
        except Exception as e:
            logger.warning(f"SuperAgent: failed to resolve expected model: {e}")
            expected_model = None

        # Initialize if not present
        # 如果Agent尚未初始化，则进行初始化
        if self.agent is None:
            if expected_model is None:
                self.agent = None
                return None
            try:
                self.agent = _build_agent(expected_model)
                return self.agent
            except Exception as e:
                logger.warning(f"SuperAgent: initialization failed: {e}")
                self.agent = None
                return None

        # If present, check consistency with current environment-configured model
        # 如果Agent已存在，检查与当前环境配置的模型是否一致
        # 获取当前Agent使用的模型信息
        try:
            current = getattr(self.agent, "model", None)
            current_pair = (
                getattr(current, "id", None),  # 模型ID
                getattr(current, "provider", None),  # 模型提供商
            )
        except Exception:
            current_pair = (None, None)

        try:
            # 获取期望的模型信息
            expected_pair = (
                getattr(expected_model, "id", None),
                getattr(expected_model, "provider", None),
            )
        except Exception:
            expected_pair = current_pair

        # 判断是否需要重启Agent（模型配置发生变化）
        needs_restart = expected_model is not None and (current_pair != expected_pair)

        if needs_restart:
            logger.info(
                f"SuperAgent: detected model change {current_pair} -> {expected_pair}, restarting agent"
            )
            try:
                # 使用新模型重新构建Agent
                self.agent = _build_agent(expected_model)
            except Exception as e:
                logger.warning(
                    f"SuperAgent: restart failed, continuing with existing agent: {e}"
                )

        return self.agent

    async def run(
        self, user_input: UserInput
    ) -> AsyncIterator[str | SuperAgentOutcome]:
        """Run super agent triage.

        中文说明：运行Super Agent分流逻辑。
        这是Super Agent的主要入口点，处理用户输入并做出决策：
        1. 初始化Agent（如果尚未初始化）
        2. 调用底层Agent处理用户输入
        3. 流式返回处理结果

        Args:
            user_input: 用户输入数据，包含查询内容和元数据

        Yields:
            Union[str, SuperAgentOutcome]: 流式返回的结果，可能是：
                - str: 中间文本内容（流式输出的一部分）
                - SuperAgentOutcome: 最终决策结果
        """
        await asyncio.sleep(0)  # 让出控制权，支持异步操作
        agent = self._get_or_init_agent()
        if agent is None:
            # Fallback: handoff directly to planner without super agent model
            # 后备方案：如果没有可用的Super Agent模型，直接转交给规划器
            yield SuperAgentOutcome(
                decision=SuperAgentDecision.HANDOFF_TO_PLANNER,
                enriched_query=user_input.query,
                reason="SuperAgent unavailable: missing model/provider configuration",
            )

        try:
            # 获取模型描述信息，用于错误报告
            model = agent.model
            model_description = f"{model.id} (via {model.provider})"
        except Exception:
            model_description = "unknown model/provider"
        try:
            # 调用底层Agent的异步运行方法
            async for response in agent.arun(
                user_input.query,  # 用户查询文本
                session_id=user_input.meta.conversation_id,  # 会话ID
                user_id=user_input.meta.user_id,  # 用户ID
                add_history_to_context=True,  # 在上下文中添加历史记录
                stream=True,  # 启用流式输出
            ):
                if response.content_type == "str":
                    # 如果是字符串内容，直接返回（流式输出的中间结果）
                    yield response.content
                    continue

                # Only process non-string content as final outcome
                # 只处理非字符串内容作为最终结果
                final_outcome = response.content
                if not isinstance(final_outcome, SuperAgentOutcome):
                    # 如果返回的不是预期的SuperAgentOutcome类型，创建错误响应
                    answer_content = (
                        f"SuperAgent produced a malformed response: `{final_outcome}`. "
                        f"Please check the capabilities of your model `{model_description}` and try again later."
                    )
                    final_outcome = SuperAgentOutcome(
                        decision=SuperAgentDecision.ANSWER,
                        answer_content=answer_content,
                    )

                yield final_outcome

        except Exception as e:
            # 处理运行过程中的异常
            yield SuperAgentOutcome(
                decision=SuperAgentDecision.ANSWER,
                reason=(
                    f"SuperAgent encountered an error: {e}."
                    f"Please check the capabilities of your model `{model_description}` and try again later."
                ),
            )
