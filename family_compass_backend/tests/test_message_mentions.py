from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.database import SqlAlchemyStore
from app.main import create_app
from app.models import FamilyCompassQuestionCreate, Message, MessageCreate
from app.seed import ABDULLAH_ID, DAD_ID, FAMILY_ID, OUTSIDER_ID, seeded_store


def _auth(user_id=ABDULLAH_ID) -> dict[str, str]:
    return {"X-Demo-User": str(user_id)}


def test_message_mentions_are_optional_unique_and_bounded() -> None:
    member_id = uuid4()

    assert MessageCreate(body="Hello").mentioned_member_ids == []
    assert MessageCreate(
        body="Hello @Dad",
        mentioned_member_ids=[member_id],
    ).mentioned_member_ids == [member_id]
    assert FamilyCompassQuestionCreate(
        prompt="@Compass What did @Dad say?",
        mentioned_member_ids=[member_id],
    ).mentioned_member_ids == [member_id]

    with pytest.raises(ValidationError, match="must be unique"):
        MessageCreate(
            body="Hello @Dad",
            mentioned_member_ids=[member_id, member_id],
        )

    with pytest.raises(ValidationError):
        MessageCreate(
            body="Too many mentions",
            mentioned_member_ids=[uuid4() for _ in range(21)],
        )


def test_message_mapping_accepts_legacy_payload_without_mentions() -> None:
    legacy = Message.model_validate(
        {
            "id": uuid4(),
            "client_id": uuid4(),
            "family_id": uuid4(),
            "sender_id": uuid4(),
            "body": "A message saved before structured mentions.",
        }
    )

    assert legacy.mentioned_member_ids == []


def test_sqlite_round_trip_preserves_structured_mentions(tmp_path) -> None:
    database_url = f"sqlite+pysqlite:///{tmp_path / 'mentions.db'}"
    mentioned_member_ids = [uuid4(), uuid4()]
    message = Message(
        client_id=uuid4(),
        family_id=uuid4(),
        sender_id=uuid4(),
        body="@Dad and @Mom, dinner is ready.",
        mentioned_member_ids=mentioned_member_ids,
    )

    first = SqlAlchemyStore.from_url(database_url)
    first.messages.save(message)
    first.close()

    second = SqlAlchemyStore.from_url(database_url)
    try:
        restored = second.messages.get(message.id)
        assert restored is not None
        assert restored.mentioned_member_ids == mentioned_member_ids
    finally:
        second.close()


def test_message_api_persists_only_current_family_mentions() -> None:
    client = TestClient(create_app(store_factory=seeded_store, allow_demo_auth=True))
    route = f"/api/v1/families/{FAMILY_ID}/messages"

    created = client.post(
        route,
        headers=_auth(),
        json={
            "body": "@Dad Dinner is ready.",
            "mentioned_member_ids": [str(DAD_ID)],
        },
    )
    legacy = client.post(
        route,
        headers=_auth(),
        json={"body": "A message without structured mentions."},
    )
    outsider = client.post(
        route,
        headers=_auth(),
        json={
            "body": "This cannot mention someone outside the family.",
            "mentioned_member_ids": [str(OUTSIDER_ID)],
        },
    )

    assert created.status_code == 201
    assert created.json()["mentioned_member_ids"] == [str(DAD_ID)]
    assert legacy.status_code == 201
    assert legacy.json()["mentioned_member_ids"] == []
    assert outsider.status_code == 422
    assert "current family members" in outsider.json()["detail"]
