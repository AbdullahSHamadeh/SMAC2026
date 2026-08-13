import json
from datetime import timedelta
from uuid import UUID, uuid4

from fastapi.testclient import TestClient

from app.ai_service import AIProvider
from app.main import create_app
from app.models import AIResponse, AuthorizedAIRequest, utc_now
from app.seed import (
    ABDULLAH_ID,
    DAD_ID,
    DINNER_PLAN_ID,
    FAMILY_ID,
    MOM_ID,
    OTHER_FAMILY_ID,
    OUTSIDER_ID,
    seeded_store,
)


def auth(user_id: UUID = ABDULLAH_ID) -> dict[str, str]:
    return {"X-Demo-User": str(user_id)}


def make_app(ai_provider: AIProvider | None = None):
    return create_app(
        store_factory=seeded_store,
        ai_provider=ai_provider,
        allow_demo_auth=True,
    )


def test_health_is_public_but_family_data_requires_a_session() -> None:
    client = TestClient(make_app())

    assert client.get("/health").json() == {"status": "ok"}
    assert client.get("/api/v1/me").status_code == 401

    me = client.get("/api/v1/me", headers=auth())
    assert me.status_code == 200
    assert me.json() == {"id": str(ABDULLAH_ID), "name": "Abdullah"}
    assert "phone" not in me.text


def test_family_reads_are_scoped_and_do_not_expose_phone_numbers() -> None:
    client = TestClient(make_app())

    members = client.get(f"/api/v1/families/{FAMILY_ID}/members", headers=auth())
    assert members.status_code == 200
    assert len(members.json()) == 3
    assert "phone" not in members.text
    assert "+971" not in members.text

    denied = client.get(f"/api/v1/families/{OTHER_FAMILY_ID}/members", headers=auth())
    assert denied.status_code == 403
    outsider_denied = client.get(
        f"/api/v1/families/{FAMILY_ID}/members", headers=auth(OUTSIDER_ID)
    )
    assert outsider_denied.status_code == 403


def test_invitation_permission_and_phone_masking() -> None:
    client = TestClient(make_app())
    route = f"/api/v1/families/{FAMILY_ID}/invitations"

    denied = client.post(
        route,
        headers=auth(),
        json={"phone_number": "+971501234567", "role": "adult"},
    )
    assert denied.status_code == 403

    created = client.post(
        route,
        headers=auth(DAD_ID),
        json={"phone_number": "+971501234567", "role": "adult"},
    )
    assert created.status_code == 201
    assert created.json()["masked_phone_number"] == "•••• 4567"
    assert "+971501234567" not in created.text

    organizer_invite = client.post(
        route,
        headers=auth(DAD_ID),
        json={"phone_number": "+971501234568", "role": "organizer"},
    )
    assert organizer_invite.status_code == 422


def test_message_sender_is_derived_from_the_session_and_is_idempotent() -> None:
    client = TestClient(make_app())
    route = f"/api/v1/families/{FAMILY_ID}/messages"
    client_id = uuid4()
    payload = {
        "client_id": str(client_id),
        "body": "I can bring dessert.",
    }

    forged = client.post(
        route,
        headers=auth(),
        json={
            **payload,
            "sender_id": str(DAD_ID),
            "family_id": str(OTHER_FAMILY_ID),
        },
    )
    assert forged.status_code == 422

    first = client.post(route, headers=auth(), json=payload)
    second = client.post(route, headers=auth(), json=payload)

    assert first.status_code == 201
    assert first.json()["sender_id"] == str(ABDULLAH_ID)
    assert second.json()["id"] == first.json()["id"]


def test_shared_updates_are_temporary_and_audience_filtered() -> None:
    client = TestClient(make_app())
    route = f"/api/v1/families/{FAMILY_ID}/shared-updates"
    text = "At the pharmacy. Back in about 20 minutes."
    created = client.post(
        route,
        headers=auth(DAD_ID),
        json={
            "text": text,
            "expires_at": (utc_now() + timedelta(hours=1)).isoformat(),
            "audience": "selected_people",
            "selected_member_ids": [str(MOM_ID)],
        },
    )
    assert created.status_code == 201

    assert text in client.get(route, headers=auth(DAD_ID)).text
    assert text in client.get(route, headers=auth(MOM_ID)).text
    assert text not in client.get(route, headers=auth()).text

    private_text = "Keeping this note private while I decide whether to share."
    private_update = client.post(
        route,
        headers=auth(DAD_ID),
        json={
            "text": private_text,
            "expires_at": (utc_now() + timedelta(hours=1)).isoformat(),
            "audience": "self_only",
        },
    )
    assert private_update.status_code == 201
    assert private_text in client.get(route, headers=auth(DAD_ID)).text
    assert private_text not in client.get(route, headers=auth(MOM_ID)).text
    assert private_text not in client.get(route, headers=auth()).text

    invalid_whole_family = client.post(
        route,
        headers=auth(DAD_ID),
        json={
            "text": "This audience shape is ambiguous.",
            "expires_at": (utc_now() + timedelta(hours=1)).isoformat(),
            "audience": "whole_family",
            "selected_member_ids": [str(MOM_ID)],
        },
    )
    assert invalid_whole_family.status_code == 422

    too_long = client.post(
        route,
        headers=auth(DAD_ID),
        json={
            "text": "This should not become permanent tracking.",
            "expires_at": (utc_now() + timedelta(days=2)).isoformat(),
        },
    )
    assert too_long.status_code == 422
    assert client.get("/api/v1/journeys", headers=auth()).status_code == 404


def test_plan_reply_then_confirmation_creates_an_automatic_reminder() -> None:
    client = TestClient(make_app())
    plan_route = f"/api/v1/families/{FAMILY_ID}/plans/{DINNER_PLAN_ID}"

    replied = client.post(
        f"{plan_route}/responses",
        headers=auth(),
        json={
            "candidate_id": "fri-1900",
            "choice": "going",
            "expected_version": 1,
        },
    )
    assert replied.status_code == 200
    assert replied.json()["phase"] == "ready_to_confirm"
    assert replied.json()["version"] == 2

    stale = client.post(
        f"{plan_route}/responses",
        headers=auth(),
        json={
            "candidate_id": "fri-1900",
            "choice": "maybe",
            "expected_version": 1,
        },
    )
    assert stale.status_code == 409

    unsupported = client.post(
        f"{plan_route}/confirm",
        headers=auth(DAD_ID),
        json={"candidate_id": "sat-1900", "expected_version": 2},
    )
    assert unsupported.status_code == 409

    confirmed = client.post(
        f"{plan_route}/confirm",
        headers=auth(DAD_ID),
        json={"candidate_id": "fri-1900", "expected_version": 2},
    )
    assert confirmed.status_code == 200
    body = confirmed.json()
    assert body["phase"] == "confirmed"
    assert body["confirmed_candidate_id"] == "fri-1900"
    assert body["reminders"][0]["automatic"] is True


def test_today_and_compass_use_only_authorized_family_context() -> None:
    client = TestClient(make_app())
    today = client.get(f"/api/v1/families/{FAMILY_ID}/today", headers=auth())
    assert today.status_code == 200
    assert today.json()["next_plan"]["title"] == "Family dinner"
    assert len(today.json()["needs_reply"]) == 1

    compass_route = f"/api/v1/families/{FAMILY_ID}/compass"
    dad = client.post(
        compass_route,
        headers=auth(),
        json={"prompt": "Where is Dad?"},
    )
    assert dad.status_code == 200
    assert dad.json()["has_permitted_information"] is True
    assert dad.json()["grounded_facts"][0]["source_label"] == "Dad shared update"
    assert "journey" not in dad.text.casefold()

    mom = client.post(
        compass_route,
        headers=auth(),
        json={"prompt": "Where is Mom?"},
    )
    assert mom.status_code == 200
    assert mom.json()["has_permitted_information"] is False
    assert mom.json()["grounded_facts"] == []

    dad_arabic = client.post(
        compass_route,
        headers=auth(),
        json={"prompt": "أين أبي؟"},
    )
    assert dad_arabic.status_code == 200
    assert dad_arabic.json()["answer_kind"] == "family_grounded"
    assert dad_arabic.json()["grounded_facts"][0]["source_label"] == "Dad shared update"


class CapturingExternalProvider(AIProvider):
    uses_external_processing = True
    name = "capturing-external"

    def __init__(self) -> None:
        self.request: AuthorizedAIRequest | None = None

    async def answer(self, request: AuthorizedAIRequest) -> AIResponse:
        self.request = request
        return AIResponse(
            answer="captured",
            provider=self.name,
            grounded_facts=request.facts,
            suggested_actions=[],
            has_permitted_information=bool(request.facts),
        )


def test_external_provider_context_honors_each_members_consent() -> None:
    provider = CapturingExternalProvider()
    client = TestClient(make_app(ai_provider=provider))
    update_route = f"/api/v1/families/{FAMILY_ID}/shared-updates"
    client.post(
        update_route,
        headers=auth(),
        json={
            "text": "At the library until 4 PM.",
            "expires_at": (utc_now() + timedelta(hours=1)).isoformat(),
        },
    )
    hidden_text = "At the clinic. Only Abdullah should see this."
    client.post(
        update_route,
        headers=auth(DAD_ID),
        json={
            "text": hidden_text,
            "expires_at": (utc_now() + timedelta(hours=1)).isoformat(),
            "audience": "selected_people",
            "selected_member_ids": [str(ABDULLAH_ID)],
        },
    )

    blocked = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={"prompt": "What has everyone shared?"},
    )
    assert blocked.status_code == 403
    assert provider.request is None

    allowed = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(MOM_ID),
        json={"prompt": "What has everyone shared?"},
    )
    assert allowed.status_code == 200
    assert provider.request is not None
    serialized = json.dumps(
        [fact.model_dump(mode="json") for fact in provider.request.facts]
    )
    assert "At the library" not in serialized
    assert hidden_text not in serialized
    assert "Family plan" not in serialized
    assert "Dad shared update" in serialized
    assert str(FAMILY_ID) not in serialized
    assert str(ABDULLAH_ID) not in serialized
    assert str(DAD_ID) not in serialized


def test_general_question_does_not_receive_an_unrelated_family_plan() -> None:
    provider = CapturingExternalProvider()
    client = TestClient(make_app(ai_provider=provider))

    response = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(MOM_ID),
        json={"prompt": "What is a simple dinner recipe?"},
    )

    assert response.status_code == 200
    assert provider.request is not None
    assert provider.request.question_scope == "general"
    assert provider.request.facts == []

    dad_joke = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(MOM_ID),
        json={"prompt": "Tell me a dad joke."},
    )
    assert dad_joke.status_code == 200
    assert provider.request is not None
    assert provider.request.question_scope == "general"
    assert provider.request.facts == []


def test_poll_rejects_replies_after_its_deadline() -> None:
    app = make_app()
    plan = app.state.store.plans.get(DINNER_PLAN_ID)
    assert plan is not None
    app.state.store.plans.save(
        plan.model_copy(update={"decision_deadline": utc_now() - timedelta(seconds=1)})
    )
    client = TestClient(app)

    response = client.post(
        f"/api/v1/families/{FAMILY_ID}/plans/{DINNER_PLAN_ID}/responses",
        headers=auth(),
        json={
            "candidate_id": "fri-1900",
            "choice": "going",
            "expected_version": 1,
        },
    )

    assert response.status_code == 409
    assert response.json()["detail"] == "This poll has closed"


def test_demo_identity_is_disabled_unless_development_enables_it() -> None:
    client = TestClient(create_app(store_factory=seeded_store, allow_demo_auth=False))

    response = client.get("/api/v1/me", headers=auth(DAD_ID))

    assert response.status_code == 503
    assert response.json()["detail"] == "No identity verifier is configured."


def test_openapi_has_no_precise_or_passive_tracking_contracts() -> None:
    client = TestClient(make_app())
    schema = json.dumps(client.get("/openapi.json").json()).casefold()

    for prohibited in (
        "latitude",
        "longitude",
        "battery",
        "coordinate",
        "route_polyline",
        "location_history",
    ):
        assert prohibited not in schema
