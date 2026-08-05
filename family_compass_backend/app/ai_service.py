from abc import ABC, abstractmethod

from .models import AIRequest, AIResponse


class AIProvider(ABC):
    """Stable boundary for OpenAI, LM Studio, vLLM, or another provider."""

    @abstractmethod
    async def answer(self, request: AIRequest) -> AIResponse:
        raise NotImplementedError


class MockAIProvider(AIProvider):
    async def answer(self, request: AIRequest) -> AIResponse:
        prompt = request.prompt.lower()
        facts = ["Dad is driving to work", "Abdullah arrived at university", "Mom is free after 2:00 PM"]
        if "dinner" in prompt or "gather" in prompt:
            answer = "Friday after 7:00 PM is open for everyone. I can suggest dinner, a movie night, or an evening walk."
            actions = ["Create family dinner", "Suggest three activities"]
        elif "help" in prompt:
            answer = "Abdullah is nearby and available after class. Ask him to help Mom with the groceries?"
            actions = ["Send help request", "Create arrival reminder"]
        else:
            answer = "All active journeys look normal. Dad is driving to work and Abdullah has arrived at university."
            actions = ["View Dad's journey", "Create a reminder"]
        return AIResponse(answer=answer, provider="mock", grounded_facts=facts, suggested_actions=actions)
