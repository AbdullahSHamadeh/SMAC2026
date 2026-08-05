from fastapi.testclient import TestClient

from app.main import create_app
from app.seed import ABDULLAH_ID, FAMILY_ID


def test_family_vertical_slice() -> None:
    client = TestClient(create_app())
    assert client.get("/health").json() == {"status": "ok"}
    assert len(client.get(f"/api/v1/families/{FAMILY_ID}/members").json()) == 3
    assert len(client.get("/api/v1/statuses", params={"family_id": str(FAMILY_ID)}).json()) == 3
    assert client.get("/api/v1/journeys", params={"family_id": str(FAMILY_ID)}).json()[0]["assessment"] == "normal"


def test_invitation_reminder_check_in_and_ai() -> None:
    client = TestClient(create_app())
    invitation = client.post("/api/v1/invitations", json={"family_id": str(FAMILY_ID), "invited_by": str(ABDULLAH_ID), "phone_number": "+971501234567", "role": "adult"})
    assert invitation.status_code == 201
    reminder = client.post("/api/v1/reminders", json={"family_id": str(FAMILY_ID), "title": "Family walk", "when": "Friday · 7:00 PM", "assignee": "Everyone"})
    assert reminder.status_code == 201
    check_in = client.post("/api/v1/check-ins", json={"family_id": str(FAMILY_ID), "user_id": str(ABDULLAH_ID), "state": "I arrived"})
    assert check_in.status_code == 201
    ai = client.post("/api/v1/ai/assistant", json={"family_id": str(FAMILY_ID), "user_id": str(ABDULLAH_ID), "prompt": "Plan a family dinner"})
    assert ai.status_code == 200
    assert ai.json()["provider"] == "mock"
    assert ai.json()["grounded_facts"]
