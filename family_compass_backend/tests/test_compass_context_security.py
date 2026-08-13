import json
from datetime import timedelta
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.ai_service import AIProvider, AIProviderUnavailable, MockAIProvider
from app.database import SqlAlchemyStore
from app.main import create_app
from app.models import (
    AIQuestionScope,
    AIResponse,
    AuthorizedAIRequest,
    AuthorizedFact,
    CheckIn,
    CompassActionArtifact,
    CompassActionKind,
    CompassFactAudience,
    CompassFactFreshness,
    CompassFactSource,
    CompassUncertainty,
    CompassVisibility,
    DevicePlatform,
    DeviceToken,
    FamilyCompassArtifact,
    FamilyRole,
    Journey,
    Membership,
    MemberStatus,
    Message,
    MessageKind,
    Reminder,
    SharedUpdate,
    SharedUpdateAudience,
    User,
    utc_now,
)
from app.notification_service import InMemoryNotificationService
from app.seed import (
    ABDULLAH_ID,
    DAD_ID,
    DINNER_PLAN_ID,
    FAMILY_ID,
    MOM_ID,
    OTHER_FAMILY_ID,
    OUTSIDER_ID,
    seed_store,
    seeded_store,
)


def auth(user_id: UUID = ABDULLAH_ID) -> dict[str, str]:
    return {"X-Demo-User": str(user_id)}


class CapturingProvider(AIProvider):
    uses_external_processing = False
    name = "capturing-local"

    def __init__(self, suggested_actions: list[str] | None = None) -> None:
        self.requests: list[AuthorizedAIRequest] = []
        self.suggested_actions = suggested_actions or []

    async def answer(self, request: AuthorizedAIRequest) -> AIResponse:
        self.requests.append(request)
        return AIResponse(
            answer="A context-grounded answer.",
            provider=self.name,
            grounded_facts=request.facts,
            suggested_actions=self.suggested_actions,
            has_permitted_information=bool(request.facts),
            answer_kind=request.question_scope,
        )


class ExternalCapturingProvider(CapturingProvider):
    uses_external_processing = True
    name = "capturing-external"


class InventingProvider(CapturingProvider):
    async def answer(self, request: AuthorizedAIRequest) -> AIResponse:
        self.requests.append(request)
        now = utc_now()
        return AIResponse(
            answer="A general activity answer.",
            provider=self.name,
            grounded_facts=[
                AuthorizedFact(
                    text="Provider-invented family context.",
                    source_id=uuid4(),
                    source_type=CompassFactSource.PLAN,
                    source_label="Provider-selected source",
                    audience=CompassFactAudience.WHOLE_FAMILY,
                    freshness=CompassFactFreshness.CURRENT,
                    updated_at=now,
                    expires_at=now + timedelta(hours=1),
                )
            ],
            suggested_actions=["Open the family plan", "Start a family plan"],
            has_permitted_information=True,
            answer_kind=AIQuestionScope.FAMILY_GROUNDED,
        )


def make_client(provider: AIProvider, store=None) -> TestClient:
    value = store or seeded_store()
    return TestClient(
        create_app(
            store_factory=lambda: value,
            ai_provider=provider,
            allow_demo_auth=True,
        )
    )


def test_private_compass_minimizes_all_authorized_family_source_types() -> None:
    now = utc_now()
    store = seeded_store()
    store.reminders.save(
        Reminder(
            family_id=FAMILY_ID,
            created_by=MOM_ID,
            label="Bring dessert",
            at=now + timedelta(hours=4),
        )
    )
    store.check_ins.save(
        CheckIn(
            family_id=FAMILY_ID,
            requester_id=DAD_ID,
            subject_user_id=ABDULLAH_ID,
        )
    )
    store.statuses.save(
        MemberStatus(
            family_id=FAMILY_ID,
            subject_user_id=DAD_ID,
            summary="Leaving work soon",
            expires_at=now + timedelta(hours=2),
        )
    )
    store.journeys.save(
        Journey(
            family_id=FAMILY_ID,
            subject_user_id=DAD_ID,
            summary="Heading home",
            status="on the way",
            eta=now + timedelta(minutes=25),
            expires_at=now + timedelta(hours=1),
        )
    )
    provider = CapturingProvider()
    client = make_client(provider, store)

    response = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={
            "prompt": (
                "What did our family chat say about dinner, what are the plan "
                "poll responses and reminder, did Dad request a check in, and "
                "what is Dad's current status and ETA?"
            )
        },
    )

    assert response.status_code == 200
    request = provider.requests[-1]
    source_types = {fact.source_type for fact in request.facts}
    assert source_types == {
        CompassFactSource.CHAT_MESSAGE,
        CompassFactSource.PLAN,
        CompassFactSource.REMINDER,
        CompassFactSource.CHECK_IN,
        CompassFactSource.SHARED_UPDATE,
        CompassFactSource.MEMBER_STATUS,
        CompassFactSource.JOURNEY,
    }
    plan_fact = next(
        fact for fact in request.facts if fact.source_type == CompassFactSource.PLAN
    )
    assert "Dad: going" in plan_fact.text
    assert "Mom: going" in plan_fact.text
    assert "1 waiting" in plan_fact.text
    body = response.json()
    assert body["audience"] == "private"
    assert body["uncertainty"] == "medium"
    assert all(fact["source_id"] for fact in body["grounded_facts"])
    assert all(fact["audience"] for fact in body["grounded_facts"])
    assert all(fact["freshness"] for fact in body["grounded_facts"])


def test_both_compass_surfaces_answer_from_the_same_recent_chat_context() -> None:
    store = seeded_store()
    marker = "The blue picnic basket is in the hall cupboard."
    store.messages.save(
        Message(
            client_id=uuid4(),
            family_id=FAMILY_ID,
            sender_id=MOM_ID,
            body=marker,
        )
    )
    client = make_client(MockAIProvider(), store)
    prompt = "What did Mom say about the picnic basket in our family chat?"

    private = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={"prompt": prompt},
    )
    family_room = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass/family-room",
        headers=auth(),
        json={"prompt": f"@Compass {prompt}"},
    )

    assert private.status_code == 200
    assert family_room.status_code == 201
    private_body = private.json()
    room_artifact = family_room.json()["artifact"]
    assert private_body["answer"] == marker
    assert room_artifact["answer"] == marker
    private_fact = private_body["grounded_facts"][0]
    room_fact = room_artifact["grounded_facts"][0]
    assert private_fact == room_fact
    assert private_fact["source_type"] == "chat_message"
    assert private_fact["source_label"] == "Family chat message from Mom"
    assert private_fact["author_label"] == "Mom"
    assert private_fact["content_kind"] == "text"
    assert private_fact["audience"] == "whole_family"
    assert private_fact["freshness"] == "recent"
    assert private_body["audience"] == "private"
    assert room_artifact["audience"] == "family_room"
    assert private_body["uncertainty"] == "low"
    assert room_artifact["uncertainty"] == "low"


@pytest.mark.parametrize(
    "prompt",
    [
        "Can you tell us what Dad said in chat?",
        "Can you tell me what Mom said in our family chat?",
    ],
)
def test_natural_named_chat_questions_use_the_same_context_in_both_surfaces(
    prompt: str,
) -> None:
    store = seeded_store()
    client = make_client(MockAIProvider(), store)

    private = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={"prompt": prompt},
    )
    family_room = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass/family-room",
        headers=auth(),
        json={"prompt": f"Could you help, @Compass? {prompt}"},
    )

    assert private.status_code == 200
    assert family_room.status_code == 201
    private_facts = private.json()["grounded_facts"]
    family_facts = family_room.json()["artifact"]["grounded_facts"]
    assert private_facts
    assert family_facts == private_facts
    assert all(fact["source_type"] == "chat_message" for fact in private_facts)


def test_named_member_chat_retrieval_is_membership_bound_and_author_exact() -> None:
    store = seeded_store()
    sara_id = uuid4()
    store.users.save(
        User(
            id=sara_id,
            name="Sara",
            phone_number="+971500000099",
            auth_subject=str(sara_id),
        )
    )
    store.memberships.save(
        Membership(
            family_id=FAMILY_ID,
            user_id=sara_id,
            role=FamilyRole.ADULT,
        )
    )
    family = store.families.get(FAMILY_ID)
    assert family is not None
    store.families.save(
        family.model_copy(update={"member_ids": [*family.member_ids, sara_id]})
    )
    sara_marker = "Dad said the blue album is in the living room."
    dad_marker = "Sara said the red album is in the kitchen."
    store.messages.save(
        Message(
            client_id=uuid4(),
            family_id=FAMILY_ID,
            sender_id=sara_id,
            body=sara_marker,
        )
    )
    store.messages.save(
        Message(
            client_id=uuid4(),
            family_id=FAMILY_ID,
            sender_id=DAD_ID,
            body=dad_marker,
        )
    )
    provider = CapturingProvider()
    client = make_client(provider, store)

    sara_response = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={"prompt": "What did Sara say in our family chat?"},
    )
    dad_response = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={"prompt": "What did Dad say about Sara in our family chat?"},
    )

    assert sara_response.status_code == 200
    sara_facts = provider.requests[-2].facts
    assert sara_facts
    assert all(fact.subject_user_id == sara_id for fact in sara_facts)
    assert any(fact.text == sara_marker for fact in sara_facts)
    assert all(fact.text != dad_marker for fact in sara_facts)
    assert dad_response.status_code == 200
    dad_facts = provider.requests[-1].facts
    assert dad_facts
    assert all(fact.subject_user_id == DAD_ID for fact in dad_facts)
    assert any(fact.text == dad_marker for fact in dad_facts)
    assert all(fact.text != sara_marker for fact in dad_facts)


def test_named_current_requester_can_retrieve_only_their_own_chat_messages() -> None:
    store = seeded_store()
    own_marker = "I put the spare key beside the family calendar."
    other_marker = "Abdullah said the spare key is under the plant."
    store.messages.save(
        Message(
            client_id=uuid4(),
            family_id=FAMILY_ID,
            sender_id=ABDULLAH_ID,
            body=own_marker,
        )
    )
    store.messages.save(
        Message(
            client_id=uuid4(),
            family_id=FAMILY_ID,
            sender_id=MOM_ID,
            body=other_marker,
        )
    )
    provider = CapturingProvider()
    client = make_client(provider, store)

    response = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={"prompt": "What did Abdullah say in the family chat?"},
    )

    assert response.status_code == 200
    facts = provider.requests[-1].facts
    assert facts
    assert all(fact.subject_user_id == ABDULLAH_ID for fact in facts)
    assert any(fact.text == own_marker for fact in facts)
    assert all(fact.text != other_marker for fact in facts)


def test_family_room_structured_member_mention_selects_exact_context_subject() -> None:
    store = seeded_store()
    provider = CapturingProvider()
    client = make_client(provider, store)

    response = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass/family-room",
        headers=auth(),
        json={
            "prompt": "@Compass What did they say in the family chat?",
            "mentioned_member_ids": [str(MOM_ID)],
        },
    )
    outsider = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass/family-room",
        headers=auth(),
        json={
            "prompt": "@Compass What did they say in the family chat?",
            "mentioned_member_ids": [str(OUTSIDER_ID)],
        },
    )

    assert response.status_code == 201
    assert response.json()["question_message"]["mentioned_member_ids"] == [str(MOM_ID)]
    assert provider.requests[-1].facts
    assert all(fact.subject_user_id == MOM_ID for fact in provider.requests[-1].facts)
    assert outsider.status_code == 422


def test_chat_context_excludes_other_families_and_removed_members() -> None:
    store = seeded_store()
    removed_marker = "removed-member-chat-marker-7201"
    other_family_marker = "other-family-chat-marker-7202"
    store.messages.save(
        Message(
            client_id=uuid4(),
            family_id=FAMILY_ID,
            sender_id=DAD_ID,
            body=removed_marker,
        )
    )
    store.messages.save(
        Message(
            client_id=uuid4(),
            family_id=OTHER_FAMILY_ID,
            sender_id=OUTSIDER_ID,
            body=other_family_marker,
        )
    )
    dad_membership = store.membership(FAMILY_ID, DAD_ID)
    assert dad_membership is not None
    store.memberships.delete(dad_membership.id)
    provider = CapturingProvider()
    client = make_client(provider, store)

    response = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={"prompt": "What did our family chat say?"},
    )

    assert response.status_code == 200
    serialized = json.dumps(provider.requests[-1].model_dump(mode="json"))
    assert removed_marker not in serialized
    assert other_family_marker not in serialized
    assert str(OUTSIDER_ID) not in serialized


def test_chat_context_is_bounded_to_the_newest_relevant_messages() -> None:
    now = utc_now()
    store = seeded_store()
    for seeded_message in store.messages.all():
        store.messages.save(
            seeded_message.model_copy(update={"created_at": now - timedelta(hours=2)})
        )
    for index in range(50):
        store.messages.save(
            Message(
                client_id=uuid4(),
                family_id=FAMILY_ID,
                sender_id=MOM_ID,
                body=f"Family chat note {index:02d}",
                created_at=now - timedelta(minutes=50 - index),
            )
        )
    provider = CapturingProvider()
    client = make_client(provider, store)

    response = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={"prompt": "What are the latest family chat messages?"},
    )

    assert response.status_code == 200
    chat_facts = [
        fact
        for fact in provider.requests[-1].facts
        if fact.source_type == CompassFactSource.CHAT_MESSAGE
    ]
    assert len(chat_facts) == 12
    assert chat_facts[0].text == "Family chat note 49"
    assert chat_facts[-1].text == "Family chat note 38"
    assert all(fact.author_label == "Mom" for fact in chat_facts)
    assert all(fact.content_kind == MessageKind.TEXT for fact in chat_facts)


@pytest.mark.parametrize(
    ("value", "expected_prompt"),
    [
        ("@Compass What did Mom say?", "What did Mom say?"),
        ("What did @COMPASS Mom say?", "What did Mom say?"),
        ("What did Mom say @compass?", "What did Mom say?"),
        ("@Compass: What did Mom say?", "What did Mom say?"),
        ("Hey, @Compass, what did Mom say?", "Hey, what did Mom say?"),
    ],
)
def test_family_room_compass_mention_works_anywhere(
    value: str,
    expected_prompt: str,
) -> None:
    provider = CapturingProvider()
    client = make_client(provider)

    response = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass/family-room",
        headers=auth(),
        json={"prompt": value},
    )

    assert response.status_code == 201
    assert provider.requests[-1].prompt == expected_prompt
    assert response.json()["question_message"]["body"] == value


@pytest.mark.parametrize(
    "value",
    [
        "@Mom What time is dinner?",
        "Can @Dad pick me up?",
        "This mentions @CompassBot, not the assistant.",
        "Email family@compass.example about dinner.",
    ],
)
def test_ordinary_member_mentions_do_not_trigger_family_room_compass(
    value: str,
) -> None:
    provider = CapturingProvider()
    client = make_client(provider)

    response = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass/family-room",
        headers=auth(),
        json={"prompt": value},
    )

    assert response.status_code == 422
    assert provider.requests == []


def test_client_only_and_compass_question_content_never_become_chat_context() -> None:
    store = seeded_store()
    client_only_marker = "pending-client-only-marker-8111"
    prior_compass_marker = "private-or-ai-history-marker-8112"
    store.messages.save(
        Message(
            client_id=uuid4(),
            family_id=FAMILY_ID,
            sender_id=MOM_ID,
            kind=MessageKind.COMPASS_QUESTION,
            body=prior_compass_marker,
        )
    )
    provider = CapturingProvider()
    client = make_client(provider, store)

    rejected = client.post(
        f"/api/v1/families/{FAMILY_ID}/messages",
        headers=auth(MOM_ID),
        json={
            "body": client_only_marker,
            "pending": True,
            "visibility": "private",
        },
    )
    response = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={"prompt": "What did our family chat say?"},
    )

    assert rejected.status_code == 422
    assert response.status_code == 200
    serialized = json.dumps(provider.requests[-1].model_dump(mode="json"))
    assert client_only_marker not in serialized
    assert prior_compass_marker not in serialized


def test_private_and_family_room_context_have_different_audience_boundaries() -> None:
    now = utc_now()
    store = seeded_store()
    selected_text = "Dad selected Abdullah for this update."
    hidden_text = "Dad selected Mom for this update."
    self_only_text = "Dad kept this update to himself."
    expired_text = "Dad's old update must not be used."
    for text, audience, recipients, expires_at in (
        (
            selected_text,
            SharedUpdateAudience.SELECTED_PEOPLE,
            [ABDULLAH_ID],
            now + timedelta(hours=1),
        ),
        (
            hidden_text,
            SharedUpdateAudience.SELECTED_PEOPLE,
            [MOM_ID],
            now + timedelta(hours=1),
        ),
        (
            self_only_text,
            SharedUpdateAudience.SELF_ONLY,
            [],
            now + timedelta(hours=1),
        ),
        (
            expired_text,
            SharedUpdateAudience.WHOLE_FAMILY,
            [],
            now - timedelta(minutes=1),
        ),
    ):
        store.shared_updates.save(
            SharedUpdate(
                family_id=FAMILY_ID,
                subject_user_id=DAD_ID,
                text=text,
                audience=audience,
                selected_member_ids=recipients,
                expires_at=expires_at,
            )
        )
    provider = CapturingProvider()
    client = make_client(provider, store)

    private = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={"prompt": "What are the latest family updates?"},
    )
    assert private.status_code == 200
    private_context = json.dumps(
        [fact.model_dump(mode="json") for fact in provider.requests[-1].facts]
    )
    assert selected_text in private_context
    assert hidden_text not in private_context
    assert self_only_text not in private_context
    assert expired_text not in private_context

    family_room = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass/family-room",
        headers=auth(),
        json={"prompt": "@Compass What are the latest family updates?"},
    )
    assert family_room.status_code == 201
    room_request = provider.requests[-1]
    assert room_request.visibility == "family_room"
    assert all(
        fact.audience == CompassFactAudience.WHOLE_FAMILY for fact in room_request.facts
    )
    room_context = json.dumps(
        [fact.model_dump(mode="json") for fact in room_request.facts]
    )
    assert selected_text not in room_context
    assert hidden_text not in room_context
    assert self_only_text not in room_context
    assert expired_text not in room_context


def test_private_compass_history_never_enters_family_visible_storage_or_context() -> (
    None
):
    provider = CapturingProvider()
    store = seeded_store()
    client = make_client(provider, store)
    secret = "private-compass-secret-8472"

    private = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={"conversation_id": str(uuid4()), "prompt": secret},
    )
    assert private.status_code == 200
    assert store.compass_artifacts.all() == []
    assert secret not in json.dumps(
        [message.model_dump(mode="json") for message in store.messages.all()]
    )

    room = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass/family-room",
        headers=auth(),
        json={"prompt": "@Compass What are the latest family updates?"},
    )
    assert room.status_code == 201
    serialized_request = json.dumps(provider.requests[-1].model_dump(mode="json"))
    assert secret not in serialized_request
    artifacts = client.get(
        f"/api/v1/families/{FAMILY_ID}/compass/family-room",
        headers=auth(),
    )
    assert secret not in artifacts.text


def test_family_room_answer_is_shared_without_impersonating_a_family_member() -> None:
    class VisibilityProvider(CapturingProvider):
        async def answer(self, request: AuthorizedAIRequest) -> AIResponse:
            self.requests.append(request)
            marker = (
                "private-compass-answer-9911"
                if request.visibility == CompassVisibility.PRIVATE
                else "family-room-answer-9912"
            )
            return AIResponse(
                answer=marker,
                provider=self.name,
                grounded_facts=request.facts,
                suggested_actions=[],
                has_permitted_information=bool(request.facts),
                answer_kind=request.question_scope,
                audience=request.visibility,
            )

    provider = VisibilityProvider()
    store = seeded_store()
    client = make_client(provider, store)
    prompt = "What did Mom say in our family chat?"

    private = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={"prompt": prompt},
    )
    room = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass/family-room",
        headers=auth(),
        json={"prompt": f"Hi @Compass, {prompt}"},
    )

    assert private.json()["answer"] == "private-compass-answer-9911"
    assert room.json()["artifact"]["answer"] == "family-room-answer-9912"
    visible_artifacts = client.get(
        f"/api/v1/families/{FAMILY_ID}/compass/family-room",
        headers=auth(DAD_ID),
    )
    assert visible_artifacts.status_code == 200
    assert "family-room-answer-9912" in visible_artifacts.text
    assert "private-compass-answer-9911" not in visible_artifacts.text

    visible_messages = client.get(
        f"/api/v1/families/{FAMILY_ID}/messages",
        headers=auth(DAD_ID),
    )
    compass_questions = [
        message
        for message in visible_messages.json()
        if message["kind"] == "compass_question"
    ]
    assert compass_questions[-1]["sender_id"] == str(ABDULLAH_ID)
    assert "family-room-answer-9912" not in visible_messages.text
    assert "private-compass-answer-9911" not in visible_messages.text


def test_family_room_compass_is_explicit_idempotent_and_confirmation_only() -> None:
    store = seeded_store()
    before_check_ins = len(store.check_ins.all())
    client_id = uuid4()
    client = make_client(MockAIProvider(), store)
    route = f"/api/v1/families/{FAMILY_ID}/compass/family-room"

    implicit = client.post(
        route,
        headers=auth(),
        json={"prompt": "Where is Mom?"},
    )
    assert implicit.status_code == 422

    first = client.post(
        route,
        headers=auth(),
        json={"client_id": str(client_id), "prompt": "@Compass Where is Mom?"},
    )
    second = client.post(
        route,
        headers=auth(),
        json={"client_id": str(client_id), "prompt": "@Compass Where is Mom?"},
    )
    assert first.status_code == 201
    assert second.status_code == 201
    assert second.json() == first.json()
    body = first.json()
    assert body["question_message"]["kind"] == "compass_question"
    assert body["artifact"]["audience"] == "family_room"
    assert body["artifact"]["uncertainty"] == "high"
    assert body["artifact"]["kind"] == "suggestion"
    assert body["artifact"]["actions"] == [
        {
            "kind": "request_check_in",
            "label": "Request a check-in",
            "requires_confirmation": True,
            "target_id": str(MOM_ID),
        }
    ]
    assert len(store.check_ins.all()) == before_check_ins
    assert len(store.compass_artifacts.all()) == 1
    assert client.get(route, headers=auth(OUTSIDER_ID)).status_code == 403


def test_family_room_question_survives_provider_failure_and_exact_retry() -> None:
    store = seeded_store()
    client_id = uuid4()
    prompt = "@Compass private-question-marker-4107: what did Mom say in chat?"

    class FailOnceProvider(AIProvider):
        name = "fail-once"
        uses_external_processing = False

        def __init__(self) -> None:
            self.calls = 0

        async def answer(self, request: AuthorizedAIRequest) -> AIResponse:
            self.calls += 1
            saved_questions = [
                message
                for message in store.messages.all()
                if message.client_id == client_id
            ]
            assert len(saved_questions) == 1
            assert saved_questions[0].kind == MessageKind.COMPASS_QUESTION
            assert saved_questions[0].body == prompt
            if self.calls == 1:
                raise AIProviderUnavailable("temporary provider failure")
            return AIResponse(
                answer="Mom asked whether Friday dinner works for everyone.",
                provider=self.name,
                grounded_facts=request.facts,
                suggested_actions=[],
                has_permitted_information=bool(request.facts),
                answer_kind=request.question_scope,
                audience=request.visibility,
            )

    notifications = InMemoryNotificationService()
    store.device_tokens.save(
        DeviceToken(
            user_id=DAD_ID,
            token="dad-firebase-installation-id-4107",
            platform=DevicePlatform.IOS,
        )
    )
    provider = FailOnceProvider()
    client = TestClient(
        create_app(
            store_factory=lambda: store,
            ai_provider=provider,
            allow_demo_auth=True,
            notification_service=notifications,
        )
    )
    route = f"/api/v1/families/{FAMILY_ID}/compass/family-room"
    payload = {"client_id": str(client_id), "prompt": prompt}

    failed = client.post(route, headers=auth(), json=payload)

    assert failed.status_code == 503
    question_id = failed.headers["x-compass-question-id"]
    saved_questions = [
        message for message in store.messages.all() if message.client_id == client_id
    ]
    assert len(saved_questions) == 1
    assert str(saved_questions[0].id) == question_id
    assert store.compass_artifacts.get(client_id) is None
    visible_messages = client.get(
        f"/api/v1/families/{FAMILY_ID}/messages",
        headers=auth(DAD_ID),
    )
    assert visible_messages.status_code == 200
    assert prompt in visible_messages.text
    assert len(notifications.deliveries) == 1
    notification = notifications.deliveries[0].payload
    assert notification.event_type == "message.created"
    assert notification.resource_id == saved_questions[0].id
    assert "private-question-marker-4107" not in notification.body

    changed = client.post(
        route,
        headers=auth(),
        json={
            "client_id": str(client_id),
            "prompt": "@Compass use a different question",
        },
    )
    retried = client.post(route, headers=auth(), json=payload)
    replayed = client.post(route, headers=auth(), json=payload)

    assert changed.status_code == 409
    assert retried.status_code == 201
    assert replayed.status_code == 201
    assert replayed.json() == retried.json()
    assert retried.json()["question_message"]["id"] == question_id
    assert provider.calls == 2
    assert (
        len(
            [
                message
                for message in store.messages.all()
                if message.client_id == client_id
            ]
        )
        == 1
    )
    assert (
        len(
            [
                artifact
                for artifact in store.compass_artifacts.all()
                if artifact.id == client_id
            ]
        )
        == 1
    )
    assert len(notifications.deliveries) == 2
    reply_notification = notifications.deliveries[-1].payload
    assert reply_notification.event_type == "compass.artifact.created"
    assert reply_notification.resource_id == client_id
    assert reply_notification.deep_link.endswith(question_id)
    assert "private-question-marker-4107" not in reply_notification.body


def test_sqlite_reuses_persisted_question_when_provider_recovers(tmp_path) -> None:
    class UnavailableProvider(AIProvider):
        name = "unavailable"
        uses_external_processing = False

        async def answer(self, request: AuthorizedAIRequest) -> AIResponse:
            del request
            raise AIProviderUnavailable("temporary provider failure")

    database_url = f"sqlite+pysqlite:///{tmp_path / 'compass-retry.db'}"
    client_id = uuid4()
    prompt = "@Compass What did Mom say in family chat?"
    payload = {"client_id": str(client_id), "prompt": prompt}
    route = f"/api/v1/families/{FAMILY_ID}/compass/family-room"
    first_store = SqlAlchemyStore.from_url(database_url)
    seed_store(first_store)
    first_app = create_app(
        store_factory=lambda: first_store,
        ai_provider=UnavailableProvider(),
        allow_demo_auth=True,
    )
    with TestClient(first_app) as client:
        failed = client.post(route, headers=auth(), json=payload)
        assert failed.status_code == 503
        question_id = failed.headers["x-compass-question-id"]

    second_store = SqlAlchemyStore.from_url(database_url)
    second_app = create_app(
        store_factory=lambda: second_store,
        ai_provider=MockAIProvider(),
        allow_demo_auth=True,
    )
    with TestClient(second_app) as client:
        recovered = client.post(route, headers=auth(), json=payload)
        assert recovered.status_code == 201
        assert recovered.json()["question_message"]["id"] == question_id
        questions = [
            message
            for message in second_store.messages.all()
            if message.client_id == client_id
        ]
        assert len(questions) == 1
        assert len(second_store.compass_artifacts.all()) == 1


def test_provider_actions_are_allowlisted_and_consequential_actions_confirmed() -> None:
    provider = CapturingProvider(
        suggested_actions=["Delete the family", "Start a family plan"]
    )
    store = seeded_store()
    store.plans.delete(DINNER_PLAN_ID)
    client = make_client(provider, store)

    response = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass/family-room",
        headers=auth(),
        json={"prompt": "@Compass Help us start a family gathering."},
    )

    assert response.status_code == 201
    actions = response.json()["artifact"]["actions"]
    assert actions == [
        {
            "kind": "start_plan",
            "label": "Start a family plan",
            "requires_confirmation": True,
            "target_id": None,
        }
    ]
    assert "delete" not in response.text.casefold()


def test_expired_chat_and_nonconsenting_chat_are_never_sent_to_provider() -> None:
    now = utc_now()
    store = seeded_store()
    old_text = "Mom said this more than thirty days ago."
    nonconsenting_text = "Abdullah did not consent to external processing."
    store.messages.save(
        Message(
            client_id=uuid4(),
            family_id=FAMILY_ID,
            sender_id=MOM_ID,
            body=old_text,
            created_at=now - timedelta(days=31),
        )
    )
    store.messages.save(
        Message(
            client_id=uuid4(),
            family_id=FAMILY_ID,
            sender_id=ABDULLAH_ID,
            body=nonconsenting_text,
        )
    )
    provider = ExternalCapturingProvider()
    client = make_client(provider, store)

    response = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(MOM_ID),
        json={"prompt": "What did our family chat say?"},
    )

    assert response.status_code == 200
    serialized = json.dumps(provider.requests[-1].model_dump(mode="json"))
    assert old_text not in serialized
    assert nonconsenting_text not in serialized


def test_general_family_terms_do_not_receive_real_family_context() -> None:
    provider = CapturingProvider()
    client = make_client(provider)

    general = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={"prompt": "What is a family gathering?"},
    )
    contextual = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={"prompt": "When is the family dinner?"},
    )

    assert general.status_code == 200
    assert provider.requests[-2].question_scope == "general"
    assert provider.requests[-2].facts == []
    assert contextual.status_code == 200
    assert provider.requests[-1].question_scope == "family_grounded"
    assert any(
        fact.source_type == CompassFactSource.PLAN
        for fact in provider.requests[-1].facts
    )


@pytest.mark.parametrize(
    "prompt",
    [
        "Give our family one simple, warm idea for spending time together tonight.",
        "أعطِ عائلتنا فكرة بسيطة ودافئة لقضاء وقت معًا الليلة.",
        "What should our family do together tonight?",
        "ماذا يمكننا أن نفعل معًا كعائلة الليلة؟",
    ],
)
def test_family_activity_advice_is_general_without_provenance(prompt: str) -> None:
    provider = InventingProvider()
    client = make_client(provider)

    private = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={"prompt": prompt},
    )
    family_room = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass/family-room",
        headers=auth(),
        json={"prompt": f"@Compass {prompt}"},
    )

    assert private.status_code == 200
    private_request = provider.requests[-2]
    assert private_request.question_scope == "general"
    assert private_request.facts == []
    assert private.json()["answer_kind"] == "general"
    assert private.json()["grounded_facts"] == []
    assert private.json()["action_artifacts"] == []
    assert private.json()["uncertainty"] == "not_applicable"

    assert family_room.status_code == 201
    room_request = provider.requests[-1]
    assert room_request.question_scope == "general"
    assert room_request.facts == []
    artifact = family_room.json()["artifact"]
    assert artifact["grounded_facts"] == []
    assert artifact["actions"] == []
    assert artifact["uncertainty"] == "not_applicable"


@pytest.mark.parametrize(
    ("prompt", "expected_source"),
    [
        ("When is the family dinner?", CompassFactSource.PLAN),
        ("متى عشاء العائلة؟", CompassFactSource.PLAN),
        ("Where is Dad?", CompassFactSource.SHARED_UPDATE),
        ("أين أبي؟", CompassFactSource.SHARED_UPDATE),
        ("What is Dad's current status?", CompassFactSource.SHARED_UPDATE),
        ("ما حالة أبي الآن؟", CompassFactSource.SHARED_UPDATE),
        (
            "What did our family chat say about dinner?",
            CompassFactSource.CHAT_MESSAGE,
        ),
        ("ماذا قالت محادثة العائلة عن العشاء؟", CompassFactSource.CHAT_MESSAGE),
        ("What reminders do we have?", CompassFactSource.REMINDER),
        ("ما هي تذكيراتنا القادمة؟", CompassFactSource.REMINDER),
    ],
)
def test_current_family_state_questions_remain_grounded(
    prompt: str,
    expected_source: CompassFactSource,
) -> None:
    provider = CapturingProvider()
    store = seeded_store()
    store.reminders.save(
        Reminder(
            family_id=FAMILY_ID,
            created_by=MOM_ID,
            label="Bring dessert",
            at=utc_now() + timedelta(hours=4),
        )
    )
    client = make_client(provider, store)

    response = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={"prompt": prompt},
    )

    assert response.status_code == 200
    request = provider.requests[-1]
    assert request.question_scope == "family_grounded"
    assert request.facts
    assert any(fact.source_type == expected_source for fact in request.facts)
    assert response.json()["grounded_facts"]


def test_family_room_artifact_persists_without_private_history(tmp_path) -> None:
    database_url = f"sqlite+pysqlite:///{tmp_path / 'compass.db'}"
    first_store = SqlAlchemyStore.from_url(database_url)
    seed_store(first_store)
    first_app = create_app(
        store_factory=lambda: first_store,
        ai_provider=MockAIProvider(),
        allow_demo_auth=True,
    )
    with TestClient(first_app) as client:
        private = client.post(
            f"/api/v1/families/{FAMILY_ID}/compass",
            headers=auth(),
            json={"prompt": "private persistence marker 9127"},
        )
        assert private.status_code == 200
        created = client.post(
            f"/api/v1/families/{FAMILY_ID}/compass/family-room",
            headers=auth(),
            json={"prompt": "@Compass Where is Mom?"},
        )
        assert created.status_code == 201
        artifact_id = created.json()["artifact"]["id"]

    second_store = SqlAlchemyStore.from_url(database_url)
    second_app = create_app(
        store_factory=lambda: second_store,
        ai_provider=MockAIProvider(),
        allow_demo_auth=True,
    )
    with TestClient(second_app) as client:
        artifacts = client.get(
            f"/api/v1/families/{FAMILY_ID}/compass/family-room",
            headers=auth(),
        )
        assert artifacts.status_code == 200
        assert [artifact["id"] for artifact in artifacts.json()] == [artifact_id]
        assert "private persistence marker 9127" not in artifacts.text


def test_family_artifact_model_rejects_private_facts_and_unconfirmed_actions() -> None:
    now = utc_now()
    selected_fact = AuthorizedFact(
        text="Selected-person context",
        source_id=uuid4(),
        source_type=CompassFactSource.SHARED_UPDATE,
        source_label="Dad shared update",
        audience=CompassFactAudience.SELECTED_PEOPLE,
        freshness=CompassFactFreshness.CURRENT,
        updated_at=now,
        expires_at=now + timedelta(hours=1),
    )
    with pytest.raises(ValidationError, match="whole-family"):
        FamilyCompassArtifact(
            family_id=FAMILY_ID,
            request_message_id=uuid4(),
            requested_by=ABDULLAH_ID,
            answer="Unsafe",
            provider="test",
            grounded_facts=[selected_fact],
            uncertainty=CompassUncertainty.LOW,
        )
    with pytest.raises(ValidationError, match="require confirmation"):
        CompassActionArtifact(
            kind=CompassActionKind.START_PLAN,
            label="Start a plan",
            requires_confirmation=False,
        )


def test_unknown_family_question_targets_named_member_for_confirmed_check_in() -> None:
    class CheckInProvider(AIProvider):
        name = "check-in-test"
        uses_external_processing = False

        async def answer(self, request: AuthorizedAIRequest) -> AIResponse:
            return AIResponse(
                answer="No current shared update is available.",
                provider=self.name,
                grounded_facts=[],
                suggested_actions=["Request a check-in"],
                has_permitted_information=False,
                answer_kind=request.question_scope,
                audience=request.visibility,
                uncertainty=CompassUncertainty.HIGH,
            )

    client = make_client(CheckInProvider())
    response = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={"prompt": "Where is Dad?", "visibility": "private"},
    )

    assert response.status_code == 200
    action = response.json()["action_artifacts"][0]
    assert action == {
        "kind": "request_check_in",
        "label": "Request a check-in",
        "requires_confirmation": True,
        "target_id": str(DAD_ID),
    }
