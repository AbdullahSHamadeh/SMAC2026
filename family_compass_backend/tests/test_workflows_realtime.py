from __future__ import annotations

from datetime import timedelta
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.main import create_app
from app.models import utc_now
from app.notification_service import InMemoryNotificationService
from app.seed import (
    ABDULLAH_ID,
    DAD_ID,
    FAMILY_ID,
    MOM_ID,
    OUTSIDER_ID,
    seeded_store,
)


def auth(user_id: UUID = ABDULLAH_ID) -> dict[str, str]:
    return {"X-Demo-User": str(user_id)}


def make_client(
    notifications: InMemoryNotificationService | None = None,
) -> TestClient:
    return TestClient(
        create_app(
            store_factory=seeded_store,
            allow_demo_auth=True,
            notification_service=notifications,
        )
    )


def test_family_creation_and_invitation_lifecycle_are_identity_bound() -> None:
    client = make_client()
    created = client.post(
        "/api/v1/families",
        headers=auth(),
        json={"name": "Weekend family"},
    )
    assert created.status_code == 201
    family_id = created.json()["id"]
    members = client.get(f"/api/v1/families/{family_id}/members", headers=auth())
    assert members.status_code == 200
    assert members.json()[0]["role"] == "organizer"
    assert members.json()[0]["can_invite"] is True

    invite = client.post(
        f"/api/v1/families/{FAMILY_ID}/invitations",
        headers=auth(DAD_ID),
        json={"phone_number": "+12025550104", "role": "adult"},
    )
    assert invite.status_code == 201
    invitation_id = invite.json()["id"]

    wrong_recipient = client.post(
        f"/api/v1/invitations/{invitation_id}/accept",
        headers=auth(ABDULLAH_ID),
    )
    assert wrong_recipient.status_code == 404
    assert wrong_recipient.json() == {"detail": "Invitation not found"}

    accepted = client.post(
        f"/api/v1/invitations/{invitation_id}/accept",
        headers=auth(OUTSIDER_ID),
    )
    assert accepted.status_code == 200
    assert accepted.json()["state"] == "accepted"
    assert (
        client.get(
            f"/api/v1/families/{FAMILY_ID}", headers=auth(OUTSIDER_ID)
        ).status_code
        == 200
    )

    decline_invite = client.post(
        f"/api/v1/families/{FAMILY_ID}/invitations",
        headers=auth(DAD_ID),
        json={"phone_number": "+12025550101", "role": "adult"},
    ).json()
    declined = client.post(
        f"/api/v1/invitations/{decline_invite['id']}/decline",
        headers=auth(),
    )
    assert declined.status_code == 200
    assert declined.json()["state"] == "declined"

    revoke_invite = client.post(
        f"/api/v1/families/{FAMILY_ID}/invitations",
        headers=auth(MOM_ID),
        json={"phone_number": "+971509998888", "role": "adult"},
    ).json()
    denied = client.post(
        f"/api/v1/families/{FAMILY_ID}/invitations/{revoke_invite['id']}/revoke",
        headers=auth(),
    )
    assert denied.status_code == 403
    revoked = client.post(
        f"/api/v1/families/{FAMILY_ID}/invitations/{revoke_invite['id']}/revoke",
        headers=auth(MOM_ID),
    )
    assert revoked.status_code == 200
    assert revoked.json()["state"] == "revoked"


def test_plan_reminder_contribution_nudge_and_completion_contracts() -> None:
    notifications = InMemoryNotificationService()
    client = make_client(notifications)
    token = client.post(
        "/api/v1/me/device-tokens",
        headers=auth(MOM_ID),
        json={"token": "ios-device-token-that-is-long-enough", "platform": "ios"},
    )
    assert token.status_code == 201
    assert "ios-device-token" not in token.text

    now = utc_now()
    plan = client.post(
        f"/api/v1/families/{FAMILY_ID}/plans",
        headers=auth(DAD_ID),
        json={
            "title": "Friday walk",
            "location_label": "The park",
            "participant_ids": [str(DAD_ID), str(MOM_ID)],
            "candidate_times": [
                {
                    "id": "friday-evening",
                    "starts_at": (now + timedelta(hours=3)).isoformat(),
                    "time_zone": "Asia/Dubai",
                }
            ],
            "decision_deadline": (now + timedelta(hours=1)).isoformat(),
        },
    )
    assert plan.status_code == 201
    plan_id = plan.json()["id"]
    assert notifications.deliveries[-1].payload.event_type == "plan.created"
    assert notifications.deliveries[-1].payload.deep_link.endswith(plan_id)

    contribution = client.post(
        f"/api/v1/families/{FAMILY_ID}/plans/{plan_id}/contributions",
        headers=auth(MOM_ID),
        json={"text": "I will bring water."},
    )
    assert contribution.status_code == 200
    assert contribution.json()["contributions"][0]["member_id"] == str(MOM_ID)

    reminder = client.post(
        f"/api/v1/families/{FAMILY_ID}/plans/{plan_id}/reminders",
        headers=auth(DAD_ID),
        json={
            "label": "Bring walking shoes",
            "at": (now + timedelta(hours=2)).isoformat(),
        },
    )
    assert reminder.status_code == 201
    reminder_id = reminder.json()["id"]
    assert notifications.deliveries[-1].payload.event_type == "reminder.created"

    updated = client.patch(
        f"/api/v1/families/{FAMILY_ID}/reminders/{reminder_id}",
        headers=auth(DAD_ID),
        json={"label": "Bring shoes and water"},
    )
    assert updated.status_code == 200
    assert updated.json()["label"] == "Bring shoes and water"
    refreshed_plan = client.get(
        f"/api/v1/families/{FAMILY_ID}/plans/{plan_id}",
        headers=auth(),
    )
    assert refreshed_plan.json()["reminders"][0]["label"] == "Bring shoes and water"

    nudge = client.post(
        f"/api/v1/families/{FAMILY_ID}/plans/{plan_id}/nudge",
        headers=auth(DAD_ID),
    )
    assert nudge.status_code == 200
    assert nudge.json()["notified_member_ids"] == [str(MOM_ID)]
    assert notifications.deliveries[-1].payload.event_type == "plan.nudged"

    deleted = client.delete(
        f"/api/v1/families/{FAMILY_ID}/reminders/{reminder_id}",
        headers=auth(DAD_ID),
    )
    assert deleted.status_code == 204
    assert (
        client.get(f"/api/v1/families/{FAMILY_ID}/reminders", headers=auth()).json()
        == []
    )


def test_private_plan_draft_is_explicitly_published_and_can_accept_a_time() -> None:
    notifications = InMemoryNotificationService()
    client = make_client(notifications)
    assert (
        client.post(
            "/api/v1/me/device-tokens",
            headers=auth(MOM_ID),
            json={
                "token": "mom-plan-pilot-installation-id",
                "platform": "ios",
            },
        ).status_code
        == 201
    )
    now = utc_now()
    deadline = now + timedelta(hours=1)
    candidates = [
        {
            "id": "early",
            "starts_at": (now + timedelta(hours=3)).isoformat(),
            "time_zone": "Asia/Dubai",
        },
        {
            "id": "middle",
            "starts_at": (now + timedelta(hours=4)).isoformat(),
            "time_zone": "Asia/Dubai",
        },
        {
            "id": "late",
            "starts_at": (now + timedelta(hours=5)).isoformat(),
            "time_zone": "Asia/Dubai",
        },
    ]
    draft = client.post(
        f"/api/v1/families/{FAMILY_ID}/plans",
        headers=auth(DAD_ID),
        json={
            "title": "Private dinner draft",
            "participant_ids": [str(DAD_ID), str(MOM_ID)],
            "candidate_times": candidates,
            "decision_deadline": deadline.isoformat(),
            "publish": False,
        },
    )
    assert draft.status_code == 201
    assert draft.json()["phase"] == "draft"
    assert notifications.deliveries == []
    plan_id = draft.json()["id"]

    creator_plans = client.get(
        f"/api/v1/families/{FAMILY_ID}/plans", headers=auth(DAD_ID)
    ).json()
    recipient_plans = client.get(
        f"/api/v1/families/{FAMILY_ID}/plans", headers=auth(MOM_ID)
    ).json()
    assert plan_id in {value["id"] for value in creator_plans}
    assert plan_id not in {value["id"] for value in recipient_plans}
    assert (
        client.get(
            f"/api/v1/families/{FAMILY_ID}/plans/{plan_id}",
            headers=auth(MOM_ID),
        ).status_code
        == 404
    )

    published = client.post(
        f"/api/v1/families/{FAMILY_ID}/plans/{plan_id}/publish",
        headers=auth(DAD_ID),
        json={"candidate_ids": ["early", "middle"], "expected_version": 1},
    )
    assert published.status_code == 200
    assert published.json()["phase"] == "poll_open"
    assert [value["id"] for value in published.json()["candidate_times"]] == [
        "early",
        "middle",
    ]
    assert notifications.deliveries[-1].payload.event_type == "plan.created"

    added = client.post(
        f"/api/v1/families/{FAMILY_ID}/plans/{plan_id}/candidate-times",
        headers=auth(MOM_ID),
        json={
            "candidate_time": {
                "id": "suggested",
                "starts_at": (now + timedelta(hours=6)).isoformat(),
                "time_zone": "Asia/Dubai",
            },
            "expected_version": published.json()["version"],
        },
    )
    assert added.status_code == 200
    assert added.json()["candidate_times"][-1]["id"] == "suggested"
    stale = client.post(
        f"/api/v1/families/{FAMILY_ID}/plans/{plan_id}/candidate-times",
        headers=auth(MOM_ID),
        json={
            "candidate_time": {
                "id": "stale",
                "starts_at": (now + timedelta(hours=7)).isoformat(),
                "time_zone": "Asia/Dubai",
            },
            "expected_version": published.json()["version"],
        },
    )
    assert stale.status_code == 409


def test_status_and_journey_summaries_are_temporary_owner_controlled() -> None:
    client = make_client()
    expiry = (utc_now() + timedelta(hours=2)).isoformat()
    shared_status = client.put(
        f"/api/v1/families/{FAMILY_ID}/statuses/me",
        headers=auth(MOM_ID),
        json={
            "summary": "Finishing groceries",
            "detail": "Home in about 20 minutes",
            "expires_at": expiry,
            "audience": "whole_family",
        },
    )
    assert shared_status.status_code == 200
    status_id = shared_status.json()["id"]
    assert client.get(f"/api/v1/families/{FAMILY_ID}/statuses", headers=auth()).json()[
        0
    ]["subject_user_id"] == str(MOM_ID)
    compass = client.post(
        f"/api/v1/families/{FAMILY_ID}/compass",
        headers=auth(),
        json={"prompt": "Where is Mom?"},
    )
    assert compass.status_code == 200
    assert compass.json()["answer_kind"] == "family_grounded"
    assert compass.json()["grounded_facts"][0]["source_label"] == "Mom shared status"
    assert (
        client.patch(
            f"/api/v1/families/{FAMILY_ID}/statuses/{status_id}",
            headers=auth(),
            json={"state": "revoked"},
        ).status_code
        == 403
    )

    journey = client.post(
        f"/api/v1/families/{FAMILY_ID}/journeys",
        headers=auth(DAD_ID),
        json={
            "summary": "Heading home",
            "status": "on_the_way",
            "eta": (utc_now() + timedelta(minutes=30)).isoformat(),
            "expires_at": expiry,
            "audience": "whole_family",
        },
    )
    assert journey.status_code == 201
    journey_id = journey.json()["id"]
    serialized = journey.text.casefold()
    assert "latitude" not in serialized
    assert "longitude" not in serialized
    assert (
        client.patch(
            f"/api/v1/families/{FAMILY_ID}/journeys/{journey_id}",
            headers=auth(MOM_ID),
            json={"state": "completed"},
        ).status_code
        == 403
    )
    completed = client.patch(
        f"/api/v1/families/{FAMILY_ID}/journeys/{journey_id}",
        headers=auth(DAD_ID),
        json={"state": "completed"},
    )
    assert completed.status_code == 200
    assert completed.json()["state"] == "completed"

    forged_coordinates = client.post(
        f"/api/v1/families/{FAMILY_ID}/journeys",
        headers=auth(DAD_ID),
        json={
            "summary": "Too precise",
            "status": "on_the_way",
            "expires_at": expiry,
            "latitude": 25.2,
            "longitude": 55.3,
        },
    )
    assert forged_coordinates.status_code == 422


def test_websocket_subscription_requires_membership_and_fans_out_events() -> None:
    client = make_client()
    route = f"/api/v1/families/{FAMILY_ID}/events"

    try:
        with client.websocket_connect(route, headers=auth(OUTSIDER_ID)):
            raise AssertionError("Outsider WebSocket should not connect")
    except WebSocketDisconnect as error:
        assert error.code == 4403

    with client.websocket_connect(route, headers=auth(DAD_ID)) as websocket:
        connected = websocket.receive_json()
        assert connected["event_type"] == "connected"

        sent = client.post(
            f"/api/v1/families/{FAMILY_ID}/messages",
            headers=auth(MOM_ID),
            json={"client_id": str(uuid4()), "body": "Dinner is ready."},
        )
        assert sent.status_code == 201
        event = websocket.receive_json()
        assert event["event_type"] == "message.created"
        assert event["resource_id"] == sent.json()["id"]
        assert event["deep_link"].endswith(sent.json()["id"])


def test_family_delete_closes_other_live_sessions_immediately() -> None:
    client = make_client()
    route = f"/api/v1/families/{FAMILY_ID}/events"

    with client.websocket_connect(route, headers=auth(MOM_ID)) as websocket:
        assert websocket.receive_json()["event_type"] == "connected"

        deleted = client.delete(
            f"/api/v1/families/{FAMILY_ID}",
            headers=auth(DAD_ID),
        )
        assert deleted.status_code == 204
        with pytest.raises(WebSocketDisconnect) as disconnected:
            websocket.receive_json()
        assert disconnected.value.code == 4403
