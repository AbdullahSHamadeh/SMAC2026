from __future__ import annotations

import json
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from pathlib import Path
from threading import Barrier
from typing import Any
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.ai_service import AIProvider
from app.database import SqlAlchemyStore
from app.main import create_app
from app.models import (
    AIResponse,
    AuthorizedAIRequest,
    CandidateTime,
    CheckIn,
    Invitation,
    InvitationState,
    Journey,
    MemberStatus,
    Plan,
    PlanPhase,
    Reminder,
    SharedUpdateAudience,
    utc_now,
)
from app.notification_service import InMemoryNotificationService
from app.seed import (
    ABDULLAH_ID,
    DAD_ID,
    FAMILY_ID,
    MOM_ID,
    OTHER_FAMILY_ID,
    OUTSIDER_ID,
    seed_store,
    seeded_store,
)


def auth(user_id: UUID = ABDULLAH_ID) -> dict[str, str]:
    return {"X-Demo-User": str(user_id)}


def make_app(*, store=None, notifications=None, provider=None):
    resolved_store = store or seeded_store()
    return create_app(
        store_factory=lambda: resolved_store,
        allow_demo_auth=True,
        notification_service=notifications,
        ai_provider=provider,
    )


class RecordingSocket:
    def __init__(self) -> None:
        self.events: list[dict[str, Any]] = []
        self.close_codes: list[int] = []

    async def send_json(self, payload: dict[str, Any]) -> None:
        self.events.append(payload)

    async def close(self, code: int) -> None:
        self.close_codes.append(code)


class DisconnectingSocket(RecordingSocket):
    async def send_json(self, payload: dict[str, Any]) -> None:
        del payload
        raise WebSocketDisconnect(code=1006)


def attach_socket(app, user_id: UUID, socket: RecordingSocket) -> None:
    app.state.events._connections[FAMILY_ID][socket] = (
        user_id,
        lambda: None,
    )


def test_invitation_created_event_reaches_only_members_with_invite_access() -> None:
    app = make_app()
    client = TestClient(app)
    inviter_peer = RecordingSocket()
    ordinary_member = RecordingSocket()
    attach_socket(app, MOM_ID, inviter_peer)
    attach_socket(app, ABDULLAH_ID, ordinary_member)

    response = client.post(
        f"/api/v1/families/{FAMILY_ID}/invitations",
        headers=auth(DAD_ID),
        json={"phone_number": "+971501234567", "role": "adult"},
    )

    assert response.status_code == 201
    assert [event["event_type"] for event in inviter_peer.events] == [
        "invitation.created"
    ]
    assert ordinary_member.events == []


@pytest.mark.parametrize(
    ("action", "event_type", "expected_state", "invitee_receives_event"),
    [
        ("accept", "invitation.accepted", "accepted", True),
        ("decline", "invitation.declined", "declined", False),
        ("revoke", "invitation.revoked", "revoked", False),
    ],
)
def test_invitation_lifecycle_events_exclude_uninvolved_ordinary_members(
    action: str,
    event_type: str,
    expected_state: str,
    invitee_receives_event: bool,
) -> None:
    app = make_app()
    client = TestClient(app)
    organizer = RecordingSocket()
    invite_manager = RecordingSocket()
    ordinary_member = RecordingSocket()
    invitee = RecordingSocket()
    attach_socket(app, DAD_ID, organizer)
    attach_socket(app, MOM_ID, invite_manager)
    attach_socket(app, ABDULLAH_ID, ordinary_member)
    attach_socket(app, OUTSIDER_ID, invitee)

    created = client.post(
        f"/api/v1/families/{FAMILY_ID}/invitations",
        headers=auth(DAD_ID),
        json={"phone_number": "+12025550104", "role": "adult"},
    )
    assert created.status_code == 201
    invitation_id = created.json()["id"]
    for socket in (organizer, invite_manager, ordinary_member, invitee):
        socket.events.clear()

    if action == "revoke":
        response = client.post(
            f"/api/v1/families/{FAMILY_ID}/invitations/{invitation_id}/revoke",
            headers=auth(DAD_ID),
        )
    else:
        response = client.post(
            f"/api/v1/invitations/{invitation_id}/{action}",
            headers=auth(OUTSIDER_ID),
        )

    assert response.status_code == 200
    assert response.json()["state"] == expected_state
    assert [event["event_type"] for event in organizer.events] == [event_type]
    assert [event["event_type"] for event in invite_manager.events] == [event_type]
    assert ordinary_member.events == []
    assert [event["event_type"] for event in invitee.events] == (
        [event_type] if invitee_receives_event else []
    )


def test_concurrent_device_token_claims_have_one_owner(tmp_path: Path) -> None:
    database_url = f"sqlite+pysqlite:///{tmp_path / 'device-claim.db'}"
    bootstrap = SqlAlchemyStore.from_url(database_url)
    seed_store(bootstrap)
    bootstrap.close()

    first_app = create_app(
        database_url=database_url,
        seed_development_data=False,
        allow_demo_auth=True,
    )
    second_app = create_app(
        database_url=database_url,
        seed_development_data=False,
        allow_demo_auth=True,
    )
    read_barrier = Barrier(2)
    for app in (first_app, second_app):
        repository = app.state.store.device_tokens
        original_all = repository.all

        def synchronized_all(original_all=original_all):
            values = original_all()
            read_barrier.wait(timeout=5)
            return values

        repository.all = synchronized_all

    clients = (TestClient(first_app), TestClient(second_app))
    request_barrier = Barrier(2)
    token = "one-fcm-registration-token-for-two-accounts"

    def claim(client: TestClient, user_id: UUID):
        request_barrier.wait(timeout=5)
        return client.post(
            "/api/v1/me/device-tokens",
            headers=auth(user_id),
            json={"token": token, "platform": "ios"},
        )

    try:
        with ThreadPoolExecutor(max_workers=2) as pool:
            responses = list(
                pool.map(
                    lambda args: claim(*args),
                    ((clients[0], DAD_ID), (clients[1], MOM_ID)),
                )
            )
    finally:
        for client in clients:
            client.close()

    assert sorted(response.status_code for response in responses) == [201, 409]
    verifier = SqlAlchemyStore.from_url(database_url)
    try:
        matches = [
            device for device in verifier.device_tokens.all() if device.token == token
        ]
    finally:
        verifier.close()
    assert len(matches) == 1
    assert matches[0].user_id in {DAD_ID, MOM_ID}


def test_organizer_can_atomically_delete_the_family_aggregate() -> None:
    store = seeded_store()
    now = utc_now()
    store.invitations.save(
        Invitation(
            family_id=FAMILY_ID,
            invited_by=DAD_ID,
            phone_number="+971501234567",
            expires_at=now + timedelta(hours=1),
        )
    )
    store.check_ins.save(
        CheckIn(
            family_id=FAMILY_ID,
            requester_id=DAD_ID,
            subject_user_id=MOM_ID,
        )
    )
    store.reminders.save(
        Reminder(
            family_id=FAMILY_ID,
            created_by=DAD_ID,
            label="Delete this reminder with its family",
            at=now + timedelta(hours=1),
        )
    )
    store.statuses.save(
        MemberStatus(
            family_id=FAMILY_ID,
            subject_user_id=DAD_ID,
            summary="Delete this status with its family",
            expires_at=now + timedelta(hours=1),
            audience=SharedUpdateAudience.WHOLE_FAMILY,
        )
    )
    store.journeys.save(
        Journey(
            family_id=FAMILY_ID,
            subject_user_id=DAD_ID,
            summary="Delete this journey with its family",
            status="on_the_way",
            expires_at=now + timedelta(hours=1),
            audience=SharedUpdateAudience.WHOLE_FAMILY,
        )
    )
    client = TestClient(make_app(store=store))

    response = client.delete(f"/api/v1/families/{FAMILY_ID}", headers=auth(DAD_ID))

    assert response.status_code == 204
    assert store.families.get(FAMILY_ID) is None
    family_repositories = (
        store.memberships,
        store.invitations,
        store.messages,
        store.shared_updates,
        store.plans,
        store.check_ins,
        store.reminders,
        store.statuses,
        store.journeys,
    )
    for repository in family_repositories:
        assert all(value.family_id != FAMILY_ID for value in repository.all())
    assert store.families.get(OTHER_FAMILY_ID) is not None
    assert store.users.get(DAD_ID) is not None
    assert (
        client.get(f"/api/v1/families/{FAMILY_ID}", headers=auth(DAD_ID)).status_code
        == 404
    )


def test_disconnected_websocket_does_not_fail_an_accepted_http_mutation() -> None:
    store = seeded_store()
    app = make_app(store=store)
    attach_socket(app, DAD_ID, DisconnectingSocket())
    client = TestClient(app, raise_server_exceptions=False)
    client_id = uuid4()

    response = client.post(
        f"/api/v1/families/{FAMILY_ID}/messages",
        headers=auth(MOM_ID),
        json={"client_id": str(client_id), "body": "Persist despite stale socket"},
    )

    assert response.status_code == 201
    matching = [
        message
        for message in store.messages.all()
        if message.family_id == FAMILY_ID
        and message.sender_id == MOM_ID
        and message.client_id == client_id
    ]
    assert len(matching) == 1


@pytest.mark.parametrize(
    ("method", "route", "payload"),
    [
        (
            "PUT",
            f"/api/v1/families/{FAMILY_ID}/statuses/me",
            {"summary": "Audience must be explicit"},
        ),
        (
            "POST",
            f"/api/v1/families/{FAMILY_ID}/journeys",
            {"summary": "Audience must be explicit", "status": "on_the_way"},
        ),
    ],
)
def test_status_and_journey_require_an_explicit_audience(
    method: str,
    route: str,
    payload: dict[str, str],
) -> None:
    client = TestClient(make_app())

    response = client.request(
        method,
        route,
        headers=auth(DAD_ID),
        json={
            **payload,
            "expires_at": (utc_now() + timedelta(hours=1)).isoformat(),
        },
    )

    assert response.status_code == 422
    assert any(error["loc"][-1] == "audience" for error in response.json()["detail"])


def test_narrowing_status_audience_redacts_former_recipients() -> None:
    app = make_app()
    client = TestClient(app)
    secret = "Former recipients must evict this status"
    route = f"/api/v1/families/{FAMILY_ID}/statuses/me"
    expiry = (utc_now() + timedelta(hours=1)).isoformat()
    initial = client.put(
        route,
        headers=auth(DAD_ID),
        json={
            "summary": secret,
            "expires_at": expiry,
            "audience": "whole_family",
        },
    )
    assert initial.status_code == 200
    status_id = initial.json()["id"]

    retained_recipient = RecordingSocket()
    former_recipient = RecordingSocket()
    attach_socket(app, MOM_ID, retained_recipient)
    attach_socket(app, ABDULLAH_ID, former_recipient)

    narrowed = client.put(
        route,
        headers=auth(DAD_ID),
        json={
            "summary": secret,
            "expires_at": expiry,
            "audience": "selected_people",
            "selected_member_ids": [str(MOM_ID)],
        },
    )

    assert narrowed.status_code == 200
    assert narrowed.json()["id"] == status_id
    redactions = [
        event
        for event in former_recipient.events
        if event["resource_id"] == status_id and "redact" in event["event_type"]
    ]
    assert len(redactions) == 1
    assert secret not in json.dumps(redactions)
    assert any(event["resource_id"] == status_id for event in retained_recipient.events)
    former_view = client.get(
        f"/api/v1/families/{FAMILY_ID}/statuses",
        headers=auth(ABDULLAH_ID),
    )
    assert former_view.status_code == 200
    assert secret not in former_view.text


def test_concurrent_nudges_deliver_exactly_once() -> None:
    store = seeded_store()
    notifications = InMemoryNotificationService()
    app = make_app(store=store, notifications=notifications)
    setup_client = TestClient(app)
    registered = setup_client.post(
        "/api/v1/me/device-tokens",
        headers=auth(MOM_ID),
        json={"token": "mom-concurrent-nudge-device-token", "platform": "ios"},
    )
    assert registered.status_code == 201
    now = utc_now()
    plan = store.plans.save(
        Plan(
            family_id=FAMILY_ID,
            title="One concurrent nudge",
            coordinator_id=DAD_ID,
            participant_ids=[DAD_ID, MOM_ID],
            candidate_times=[
                CandidateTime(
                    id="later",
                    starts_at=now + timedelta(hours=2),
                    time_zone="Asia/Dubai",
                )
            ],
            phase=PlanPhase.POLL_OPEN,
            decision_deadline=now + timedelta(hours=1),
        )
    )
    original_get = store.plans.get
    read_barrier = Barrier(2)

    def synchronized_get(item_id: UUID):
        value = original_get(item_id)
        if item_id == plan.id and value is not None and value.nudged_at is None:
            read_barrier.wait(timeout=5)
        return value

    store.plans.get = synchronized_get  # type: ignore[method-assign]
    clients = (TestClient(app), TestClient(app))
    start_barrier = Barrier(2)

    def nudge(client: TestClient):
        start_barrier.wait(timeout=5)
        return client.post(
            f"/api/v1/families/{FAMILY_ID}/plans/{plan.id}/nudge",
            headers=auth(DAD_ID),
        )

    try:
        with ThreadPoolExecutor(max_workers=2) as pool:
            responses = list(pool.map(nudge, clients))
    finally:
        store.plans.get = original_get  # type: ignore[method-assign]
        for client in clients:
            client.close()

    assert [response.status_code for response in responses] == [200, 200]
    assert sorted(
        len(response.json()["notified_member_ids"]) for response in responses
    ) == [
        0,
        1,
    ]
    deliveries = [
        delivery
        for delivery in notifications.deliveries
        if delivery.payload.event_type == "plan.nudged"
        and delivery.payload.resource_id == plan.id
    ]
    assert len(deliveries) == 1
    assert deliveries[0].user_id == MOM_ID


def test_concurrent_invitation_acceptance_creates_one_membership() -> None:
    store = seeded_store()
    app = make_app(store=store)
    setup_client = TestClient(app)
    invitation_response = setup_client.post(
        f"/api/v1/families/{FAMILY_ID}/invitations",
        headers=auth(DAD_ID),
        json={"phone_number": "+12025550104", "role": "adult"},
    )
    assert invitation_response.status_code == 201
    invitation_id = UUID(invitation_response.json()["id"])

    original_get = store.invitations.get
    invitation_barrier = Barrier(2)

    def synchronized_get(item_id: UUID):
        value = original_get(item_id)
        if item_id == invitation_id and value is not None:
            invitation_barrier.wait(timeout=5)
        return value

    store.invitations.get = synchronized_get  # type: ignore[method-assign]
    original_accept = store.accept_invitation
    acceptance_barrier = Barrier(2)

    def synchronized_accept(membership, family, invitation):
        acceptance_barrier.wait(timeout=5)
        return original_accept(membership, family, invitation)

    store.accept_invitation = synchronized_accept  # type: ignore[method-assign]
    clients = (TestClient(app), TestClient(app))
    request_barrier = Barrier(2)

    def accept(client: TestClient):
        request_barrier.wait(timeout=5)
        return client.post(
            f"/api/v1/invitations/{invitation_id}/accept",
            headers=auth(OUTSIDER_ID),
        )

    try:
        with ThreadPoolExecutor(max_workers=2) as pool:
            responses = list(pool.map(accept, clients))
    finally:
        store.invitations.get = original_get  # type: ignore[method-assign]
        store.accept_invitation = original_accept  # type: ignore[method-assign]
        for client in clients:
            client.close()

    assert all(response.status_code in {200, 409} for response in responses)
    assert any(response.status_code == 200 for response in responses)
    memberships = [
        membership
        for membership in store.memberships.all()
        if membership.family_id == FAMILY_ID and membership.user_id == OUTSIDER_ID
    ]
    assert len(memberships) == 1
    family = store.families.get(FAMILY_ID)
    assert family is not None
    assert family.member_ids.count(OUTSIDER_ID) == 1
    invitation = store.invitations.get(invitation_id)
    assert invitation is not None
    assert invitation.state == InvitationState.ACCEPTED


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


def test_family_planning_question_never_receives_a_family_plan() -> None:
    provider = CapturingProvider()
    client = TestClient(make_app(provider=provider))

    response = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(MOM_ID),
        json={"prompt": "What is family planning?"},
    )

    assert response.status_code == 200
    request = provider.requests[-1]
    assert request.question_scope == "general"
    assert request.facts == []
