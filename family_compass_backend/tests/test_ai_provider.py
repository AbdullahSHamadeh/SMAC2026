import asyncio
import json
from datetime import timedelta
from uuid import uuid4

import httpx

from app.ai_service import OpenAICompatibleProvider
from app.models import (
    AIQuestionScope,
    AuthorizedAIRequest,
    AuthorizedFact,
    CompassFactAudience,
    CompassFactFreshness,
    CompassFactSource,
    CompassVisibility,
    MessageKind,
    utc_now,
)


def test_openai_compatible_provider_answers_general_questions_without_ids() -> None:
    captured: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["body"] = json.loads(request.content)
        return httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "content": "The sky looks blue because of scattering."
                        }
                    }
                ]
            },
        )

    provider = OpenAICompatibleProvider(
        base_url="http://127.0.0.1:1234/v1",
        model="local-model",
        name="lm-studio",
        uses_external_processing=False,
        require_loopback=True,
        transport=httpx.MockTransport(handler),
    )
    response = asyncio.run(
        provider.answer(
            AuthorizedAIRequest(
                prompt="Why does the sky look blue?",
                visibility=CompassVisibility.PRIVATE,
                facts=[],
                question_scope=AIQuestionScope.GENERAL,
            )
        )
    )

    assert response.answer_kind == AIQuestionScope.GENERAL
    assert response.grounded_facts == []
    serialized = json.dumps(captured["body"])
    assert "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" not in serialized
    assert "11111111-1111-1111-1111-111111111111" not in serialized


def test_family_question_sends_only_pre_authorized_fact_text() -> None:
    captured: dict[str, object] = {}
    now = utc_now()

    def handler(request: httpx.Request) -> httpx.Response:
        captured["body"] = json.loads(request.content)
        return httpx.Response(
            200,
            json={
                "choices": [
                    {"message": {"content": "Dad shared that he is on his way."}}
                ]
            },
        )

    provider = OpenAICompatibleProvider(
        base_url="http://127.0.0.1:1234/v1",
        model="local-model",
        name="lm-studio",
        uses_external_processing=False,
        require_loopback=True,
        transport=httpx.MockTransport(handler),
    )
    subject_user_id = uuid4()
    fact = AuthorizedFact(
        text="On the way home.",
        source_id=uuid4(),
        subject_user_id=subject_user_id,
        source_type=CompassFactSource.SHARED_UPDATE,
        source_label="Dad shared update",
        author_label="Dad",
        content_kind=MessageKind.TEXT,
        audience=CompassFactAudience.WHOLE_FAMILY,
        freshness=CompassFactFreshness.CURRENT,
        updated_at=now,
        expires_at=now + timedelta(hours=1),
    )
    response = asyncio.run(
        provider.answer(
            AuthorizedAIRequest(
                prompt="Where is Dad?",
                visibility=CompassVisibility.PRIVATE,
                facts=[fact],
                question_scope=AIQuestionScope.FAMILY_GROUNDED,
            )
        )
    )

    assert response.grounded_facts == [fact]
    serialized = json.dumps(captured["body"])
    assert "On the way home" in serialized
    assert "Dad shared update" in serialized
    assert '\\"author\\": \\"Dad\\"' in serialized
    assert '\\"content_kind\\": \\"text\\"' in serialized
    assert "updated_at" in serialized
    assert '\\"audience\\": \\"whole_family\\"' in serialized
    assert '\\"freshness\\": \\"current\\"' in serialized
    assert "family_id" not in serialized
    assert "user_id" not in serialized
    assert str(subject_user_id) not in serialized


def test_family_question_without_context_never_calls_the_model() -> None:
    called = False

    def handler(_: httpx.Request) -> httpx.Response:
        nonlocal called
        called = True
        return httpx.Response(500)

    provider = OpenAICompatibleProvider(
        base_url="http://127.0.0.1:1234/v1",
        model="local-model",
        name="lm-studio",
        uses_external_processing=False,
        require_loopback=True,
        transport=httpx.MockTransport(handler),
    )
    response = asyncio.run(
        provider.answer(
            AuthorizedAIRequest(
                prompt="Where is Mom?",
                visibility=CompassVisibility.PRIVATE,
                facts=[],
                question_scope=AIQuestionScope.FAMILY_WITHOUT_CONTEXT,
            )
        )
    )

    assert called is False
    assert response.answer_kind == AIQuestionScope.FAMILY_WITHOUT_CONTEXT
    assert response.has_permitted_information is False


def test_lm_studio_mode_rejects_non_loopback_servers() -> None:
    try:
        OpenAICompatibleProvider(
            base_url="https://example.com/v1",
            require_loopback=True,
        )
    except ValueError as error:
        assert "loopback" in str(error)
    else:
        raise AssertionError("A remote LM Studio URL should be rejected")
