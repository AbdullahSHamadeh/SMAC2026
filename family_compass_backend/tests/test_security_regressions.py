from __future__ import annotations

from datetime import timedelta
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.ai_service import AIProvider
from app.auth import DevTokenIdentityVerifier, issue_dev_token
from app.main import create_app
from app.models import (
    AIResponse,
    AuthorizedAIRequest,
    CandidateTime,
    InvitationState,
    Journey,
    MemberStatus,
    Plan,
    PlanPhase,
    utc_now,
)
from app.notification_service import InMemoryNotificationService
from app.seed import (
    ABDULLAH_ID,
    DAD_ID,
    FAMILY_ID,
    MOM_ID,
    OUTSIDER_ID,
    seeded_store,
)

DEV_SECRET = "family-compass-security-test-secret-32-bytes"


def auth(user_id: UUID = ABDULLAH_ID) -> dict[str, str]:
    return {"X-Demo-User": str(user_id)}


def make_client(*, store=None, notifications=None, provider=None) -> TestClient:
    resolved_store = store or seeded_store()
    return TestClient(
        create_app(
            store_factory=lambda: resolved_store,
            allow_demo_auth=True,
            notification_service=notifications,
            ai_provider=provider,
        )
    )


def create_outsider_invitation(client: TestClient) -> dict[str, object]:
    response = client.post(
        f"/api/v1/families/{FAMILY_ID}/invitations",
        headers=auth(DAD_ID),
        json={"phone_number": "+12025550104", "role": "adult"},
    )
    assert response.status_code == 201
    return response.json()


def test_failed_invitation_acceptance_rolls_back_every_family_mutation() -> None:
    store = seeded_store()
    client = make_client(store=store)
    invitation = create_outsider_invitation(client)
    invitation_id = UUID(str(invitation["id"]))
    family_before = store.families.get(FAMILY_ID)
    assert family_before is not None

    original_save = store.invitations.save

    def fail_final_invitation_write(value):
        if value.id == invitation_id and value.state == InvitationState.ACCEPTED:
            raise RuntimeError("simulated final invitation write failure")
        return original_save(value)

    store.invitations.save = fail_final_invitation_write  # type: ignore[method-assign]
    failing_client = TestClient(client.app, raise_server_exceptions=False)

    response = failing_client.post(
        f"/api/v1/invitations/{invitation_id}/accept",
        headers=auth(OUTSIDER_ID),
    )

    assert response.status_code == 500
    assert store.membership(FAMILY_ID, OUTSIDER_ID) is None
    assert store.families.get(FAMILY_ID) == family_before
    stored_invitation = store.invitations.get(invitation_id)
    assert stored_invitation is not None
    assert stored_invitation.state == InvitationState.PENDING
    assert (
        failing_client.get(
            f"/api/v1/families/{FAMILY_ID}", headers=auth(OUTSIDER_ID)
        ).status_code
        == 403
    )


@pytest.mark.parametrize("action", ["accept", "decline"])
def test_wrong_invitation_recipient_cannot_enumerate_invitation_ids(
    action: str,
) -> None:
    client = make_client()
    invitation = create_outsider_invitation(client)

    existing = client.post(
        f"/api/v1/invitations/{invitation['id']}/{action}",
        headers=auth(ABDULLAH_ID),
    )
    missing = client.post(
        f"/api/v1/invitations/{uuid4()}/{action}",
        headers=auth(ABDULLAH_ID),
    )

    assert existing.status_code == missing.status_code == 404
    assert existing.json() == missing.json() == {"detail": "Invitation not found"}
    assert "phone" not in existing.text.casefold()


def test_leave_and_member_removal_enforce_roles_and_last_organizer_safety() -> None:
    client = make_client()
    family_members = f"/api/v1/families/{FAMILY_ID}/members"

    denied = client.delete(f"{family_members}/{MOM_ID}", headers=auth(ABDULLAH_ID))
    assert denied.status_code == 403

    removed = client.delete(f"{family_members}/{MOM_ID}", headers=auth(DAD_ID))
    assert removed.status_code == 204
    assert (
        client.get(f"/api/v1/families/{FAMILY_ID}", headers=auth(MOM_ID)).status_code
        == 403
    )

    left = client.delete(f"{family_members}/me", headers=auth(ABDULLAH_ID))
    assert left.status_code == 204
    assert (
        client.get(
            f"/api/v1/families/{FAMILY_ID}", headers=auth(ABDULLAH_ID)
        ).status_code
        == 403
    )

    last_organizer = client.delete(f"{family_members}/me", headers=auth(DAD_ID))
    assert last_organizer.status_code == 409
    assert "organizer" in last_organizer.json()["detail"].casefold()
    assert (
        client.get(f"/api/v1/families/{FAMILY_ID}", headers=auth(DAD_ID)).status_code
        == 200
    )


def test_expired_bearer_cannot_receive_later_websocket_events() -> None:
    clock = [1_000.0]
    verifier = DevTokenIdentityVerifier(DEV_SECRET, now=lambda: clock[0])
    app = create_app(
        store_factory=seeded_store,
        identity_verifier=verifier,
    )
    short_token = issue_dev_token(
        ABDULLAH_ID,
        DEV_SECRET,
        ttl_seconds=2,
        now=1_000,
    )
    sender_token = issue_dev_token(
        MOM_ID,
        DEV_SECRET,
        ttl_seconds=100,
        now=1_000,
    )
    socket_headers = {"Authorization": f"Bearer {short_token}"}
    sender_headers = {"Authorization": f"Bearer {sender_token}"}

    with (
        TestClient(app) as client,
        client.websocket_connect(
            f"/api/v1/families/{FAMILY_ID}/events",
            headers=socket_headers,
        ) as websocket,
    ):
        assert websocket.receive_json()["event_type"] == "connected"
        clock[0] = 1_003.0
        sent = client.post(
            f"/api/v1/families/{FAMILY_ID}/messages",
            headers=sender_headers,
            json={"client_id": str(uuid4()), "body": "After expiry"},
        )
        assert sent.status_code == 201
        with pytest.raises(WebSocketDisconnect) as disconnected:
            websocket.receive_json()
        assert disconnected.value.code == 4401


def test_revoked_member_cannot_receive_later_websocket_events() -> None:
    store = seeded_store()
    client = make_client(store=store)
    route = f"/api/v1/families/{FAMILY_ID}/events"

    with client.websocket_connect(route, headers=auth(ABDULLAH_ID)) as websocket:
        assert websocket.receive_json()["event_type"] == "connected"
        membership = store.membership(FAMILY_ID, ABDULLAH_ID)
        family = store.families.get(FAMILY_ID)
        assert membership is not None and family is not None
        store.memberships.delete(membership.id)
        store.families.save(
            family.model_copy(
                update={
                    "member_ids": [
                        member_id
                        for member_id in family.member_ids
                        if member_id != ABDULLAH_ID
                    ]
                }
            )
        )
        sent = client.post(
            f"/api/v1/families/{FAMILY_ID}/messages",
            headers=auth(MOM_ID),
            json={"client_id": str(uuid4()), "body": "After removal"},
        )
        assert sent.status_code == 201
        with pytest.raises(WebSocketDisconnect) as disconnected:
            websocket.receive_json()
        assert disconnected.value.code == 4403


@pytest.mark.parametrize(
    ("resource", "payload", "secret"),
    [
        (
            "statuses",
            {
                "summary": "At a private appointment",
                "detail": "Back later",
            },
            "At a private appointment",
        ),
        (
            "journeys",
            {
                "summary": "Heading to a private errand",
                "status": "on_the_way",
            },
            "Heading to a private errand",
        ),
    ],
)
def test_status_and_journey_selected_audiences_are_enforced(
    resource: str,
    payload: dict[str, str],
    secret: str,
) -> None:
    client = make_client()
    route = f"/api/v1/families/{FAMILY_ID}/{resource}"
    response = client.request(
        "PUT" if resource == "statuses" else "POST",
        f"{route}/me" if resource == "statuses" else route,
        headers=auth(DAD_ID),
        json={
            **payload,
            "expires_at": (utc_now() + timedelta(hours=1)).isoformat(),
            "audience": "selected_people",
            "selected_member_ids": [str(MOM_ID)],
        },
    )
    assert response.status_code in {200, 201}

    assert secret in client.get(route, headers=auth(DAD_ID)).text
    assert secret in client.get(route, headers=auth(MOM_ID)).text
    assert secret not in client.get(route, headers=auth(ABDULLAH_ID)).text
    assert client.get(route, headers=auth(OUTSIDER_ID)).status_code == 403


def test_status_and_journey_reject_ambiguous_audience_shapes() -> None:
    client = make_client()
    expiry = (utc_now() + timedelta(hours=1)).isoformat()

    for method, route, payload in (
        (
            "PUT",
            f"/api/v1/families/{FAMILY_ID}/statuses/me",
            {"summary": "Home", "expires_at": expiry},
        ),
        (
            "POST",
            f"/api/v1/families/{FAMILY_ID}/journeys",
            {"summary": "Heading home", "status": "on_the_way", "expires_at": expiry},
        ),
    ):
        whole_family_with_recipients = client.request(
            method,
            route,
            headers=auth(DAD_ID),
            json={
                **payload,
                "audience": "whole_family",
                "selected_member_ids": [str(MOM_ID)],
            },
        )
        selected_without_recipients = client.request(
            method,
            route,
            headers=auth(DAD_ID),
            json={
                **payload,
                "audience": "selected_people",
                "selected_member_ids": [],
            },
        )
        assert whole_family_with_recipients.status_code == 422
        assert selected_without_recipients.status_code == 422


def test_expired_status_and_journey_context_is_physically_deleted() -> None:
    store = seeded_store()
    expired_at = utc_now() - timedelta(minutes=1)
    expired_status = store.statuses.save(
        MemberStatus(
            family_id=FAMILY_ID,
            subject_user_id=DAD_ID,
            summary="Expired status secret",
            expires_at=expired_at,
        )
    )
    expired_journey = store.journeys.save(
        Journey(
            family_id=FAMILY_ID,
            subject_user_id=DAD_ID,
            summary="Expired journey secret",
            status="on_the_way",
            expires_at=expired_at,
        )
    )
    client = make_client(store=store)

    statuses = client.get(
        f"/api/v1/families/{FAMILY_ID}/statuses", headers=auth(MOM_ID)
    )
    journeys = client.get(
        f"/api/v1/families/{FAMILY_ID}/journeys", headers=auth(MOM_ID)
    )

    assert statuses.status_code == journeys.status_code == 200
    assert "Expired status secret" not in statuses.text
    assert "Expired journey secret" not in journeys.text
    assert store.statuses.get(expired_status.id) is None
    assert store.journeys.get(expired_journey.id) is None


def test_plan_creation_and_nudges_are_idempotent() -> None:
    store = seeded_store()
    notifications = InMemoryNotificationService()
    client = make_client(store=store, notifications=notifications)
    device = client.post(
        "/api/v1/me/device-tokens",
        headers=auth(MOM_ID),
        json={"token": "mom-device-token-long-enough", "platform": "ios"},
    )
    assert device.status_code == 201
    now = utc_now()
    plan_id = uuid4()
    payload = {
        "client_id": str(plan_id),
        "title": "Idempotent family walk",
        "participant_ids": [str(DAD_ID), str(MOM_ID)],
        "candidate_times": [
            {
                "id": "tomorrow-evening",
                "starts_at": (now + timedelta(hours=3)).isoformat(),
                "time_zone": "Asia/Dubai",
            }
        ],
        "decision_deadline": (now + timedelta(hours=1)).isoformat(),
    }
    route = f"/api/v1/families/{FAMILY_ID}/plans"

    first = client.post(route, headers=auth(DAD_ID), json=payload)
    second = client.post(route, headers=auth(DAD_ID), json=payload)

    assert first.status_code == second.status_code == 201
    assert first.json()["id"] == second.json()["id"] == str(plan_id)
    assert len([plan for plan in store.plans.all() if plan.id == plan_id]) == 1
    assert (
        len(
            [
                delivery
                for delivery in notifications.deliveries
                if delivery.payload.event_type == "plan.created"
                and delivery.payload.resource_id == plan_id
            ]
        )
        == 1
    )

    nudge_route = f"{route}/{plan_id}/nudge"
    first_nudge = client.post(nudge_route, headers=auth(DAD_ID))
    nudge_deliveries = len(
        [
            delivery
            for delivery in notifications.deliveries
            if delivery.payload.event_type == "plan.nudged"
            and delivery.payload.resource_id == plan_id
        ]
    )
    second_nudge = client.post(nudge_route, headers=auth(DAD_ID))

    assert first_nudge.status_code == second_nudge.status_code == 200
    assert first_nudge.json()["notified_member_ids"] == [str(MOM_ID)]
    assert second_nudge.json()["notified_member_ids"] == []
    assert (
        len(
            [
                delivery
                for delivery in notifications.deliveries
                if delivery.payload.event_type == "plan.nudged"
                and delivery.payload.resource_id == plan_id
            ]
        )
        == nudge_deliveries
        == 1
    )


class CapturingProvider(AIProvider):
    uses_external_processing = False
    name = "capturing-local"

    def __init__(self) -> None:
        self.requests: list[AuthorizedAIRequest] = []

    async def answer(self, request: AuthorizedAIRequest) -> AIResponse:
        self.requests.append(request)
        return AIResponse(
            answer="captured",
            provider=self.name,
            grounded_facts=request.facts,
            suggested_actions=[],
            has_permitted_information=bool(request.facts),
            answer_kind=request.question_scope,
        )


def test_unrelated_shared_memory_and_past_plans_never_enter_ai_context() -> None:
    store = seeded_store()
    now = utc_now()
    old_plan = Plan(
        family_id=FAMILY_ID,
        title="Old secret reunion",
        coordinator_id=DAD_ID,
        participant_ids=[DAD_ID, MOM_ID],
        candidate_times=[
            CandidateTime(
                id="already-finished",
                starts_at=now - timedelta(days=2),
                time_zone="Asia/Dubai",
            )
        ],
        phase=PlanPhase.CONFIRMED,
        confirmed_candidate_id="already-finished",
        decision_deadline=now - timedelta(days=3),
        updated_at=now - timedelta(days=3),
    )
    store.plans.save(old_plan)
    provider = CapturingProvider()
    client = make_client(store=store, provider=provider)
    route = f"/api/v1/families/{FAMILY_ID}/compass"

    memory = client.post(
        route,
        headers=auth(MOM_ID),
        json={"prompt": "How does shared memory work in an operating system?"},
    )
    assert memory.status_code == 200
    memory_request = provider.requests[-1]
    assert memory_request.question_scope == "general"
    assert memory_request.facts == []

    plans = client.post(
        route,
        headers=auth(MOM_ID),
        json={"prompt": "What family plans are active?"},
    )
    assert plans.status_code == 200
    plan_request = provider.requests[-1]
    fact_text = " ".join(fact.text for fact in plan_request.facts)
    assert "Family dinner" in fact_text
    assert "Old secret reunion" not in fact_text
