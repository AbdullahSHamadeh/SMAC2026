from __future__ import annotations

from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.dialects import postgresql
from sqlalchemy.schema import CreateTable

from app.auth import (
    DevTokenIdentityVerifier,
    FirebaseIdentityVerifier,
    issue_dev_token,
)
from app.database import (
    SCHEMA_VERSION,
    Base,
    SqlAlchemyStore,
    initialize_schema,
    normalize_database_url,
    schema_versions,
)
from app.firebase_emulator_seed import _is_loopback_host
from app.main import create_app
from app.seed import (
    ABDULLAH_ID,
    DAD_ID,
    FAMILY_ID,
    MOM_ID,
    OUTSIDER_ID,
    seeded_store,
)

DEV_SECRET = "family-compass-test-secret-with-32-bytes"


def bearer(user_id=ABDULLAH_ID) -> dict[str, str]:
    token = issue_dev_token(user_id, DEV_SECRET)
    return {"Authorization": f"Bearer {token}"}


def persistent_app(database_url: str):
    return create_app(
        database_url=database_url,
        seed_development_data=True,
        identity_verifier=DevTokenIdentityVerifier(DEV_SECRET),
    )


def test_sqlite_state_survives_an_application_restart(tmp_path) -> None:
    database_url = f"sqlite+pysqlite:///{tmp_path / 'family-compass.db'}"
    client_id = uuid4()
    message_route = f"/api/v1/families/{FAMILY_ID}/messages"
    permissions_route = f"/api/v1/families/{FAMILY_ID}/permissions/{ABDULLAH_ID}"

    with TestClient(persistent_app(database_url)) as first:
        permission = first.patch(
            permissions_route,
            headers=bearer(DAD_ID),
            json={"can_invite": True},
        )
        assert permission.status_code == 200
        created = first.post(
            message_route,
            headers=bearer(),
            json={"client_id": str(client_id), "body": "Saved across restarts."},
        )
        assert created.status_code == 201
        message_id = created.json()["id"]

    with TestClient(persistent_app(database_url)) as second:
        messages = second.get(message_route, headers=bearer())
        assert messages.status_code == 200
        assert any(message["id"] == message_id for message in messages.json())

        invitation = second.post(
            f"/api/v1/families/{FAMILY_ID}/invitations",
            headers=bearer(),
            json={"phone_number": "+971501119999", "role": "adult"},
        )
        assert invitation.status_code == 201

    with TestClient(persistent_app(database_url)) as third:
        invitations = third.get(
            f"/api/v1/families/{FAMILY_ID}/invitations",
            headers=bearer(),
        )
        assert invitations.status_code == 200
        assert any(
            item["masked_phone_number"] == "•••• 9999" for item in invitations.json()
        )


def test_schema_initialization_is_versioned_and_idempotent(tmp_path) -> None:
    database_url = f"sqlite+pysqlite:///{tmp_path / 'schema.db'}"
    store = SqlAlchemyStore.from_url(database_url)
    try:
        initialize_schema(store.engine)
        assert schema_versions(store.engine) == [SCHEMA_VERSION]
        assert set(Base.metadata.tables) == {
            "schema_versions",
            "users",
            "families",
            "memberships",
            "invitations",
            "messages",
            "shared_updates",
            "plans",
            "check_ins",
            "reminders",
            "member_statuses",
            "journeys",
            "device_tokens",
            "family_compass_artifacts",
            "device_token_claims",
            "membership_claims",
            "auth_subject_claims",
            "phone_number_claims",
        }
    finally:
        store.close()


def test_schema_and_common_postgres_urls_are_postgresql_compatible() -> None:
    assert normalize_database_url("postgres://user:pass@db.example/family") == (
        "postgresql+psycopg://user:pass@db.example/family"
    )
    assert normalize_database_url("postgresql://user:pass@db.example/family") == (
        "postgresql+psycopg://user:pass@db.example/family"
    )
    for table in Base.metadata.sorted_tables:
        ddl = str(CreateTable(table).compile(dialect=postgresql.dialect()))
        assert "CREATE TABLE" in ddl


def test_development_bearer_tokens_are_signed_expiring_and_header_isolated() -> None:
    verifier = DevTokenIdentityVerifier(DEV_SECRET)
    client = TestClient(
        create_app(
            store_factory=seeded_store,
            identity_verifier=verifier,
        )
    )

    assert client.get("/api/v1/me", headers=bearer()).status_code == 200
    assert (
        client.get("/api/v1/me", headers={"X-Demo-User": str(ABDULLAH_ID)}).status_code
        == 401
    )

    valid = issue_dev_token(ABDULLAH_ID, DEV_SECRET)
    prefix, payload, signature = valid.split(".")
    tampered_signature = ("A" if signature[0] != "A" else "B") + signature[1:]
    tampered = f"{prefix}.{payload}.{tampered_signature}"
    assert (
        client.get(
            "/api/v1/me", headers={"Authorization": f"Bearer {tampered}"}
        ).status_code
        == 401
    )

    expired = issue_dev_token(ABDULLAH_ID, DEV_SECRET, ttl_seconds=1, now=1)
    assert (
        client.get(
            "/api/v1/me", headers={"Authorization": f"Bearer {expired}"}
        ).status_code
        == 401
    )

    with pytest.raises(ValueError, match="at least 32 bytes"):
        DevTokenIdentityVerifier("too-short")


def test_firebase_identity_subjects_map_to_local_users() -> None:
    store = seeded_store()
    user = store.users.get(ABDULLAH_ID)
    assert user is not None
    store.users.save(user.model_copy(update={"auth_subject": "firebase-abdullah"}))

    accepted = FirebaseIdentityVerifier(
        verify_token=lambda token: {"uid": "firebase-abdullah"}
    )
    client = TestClient(
        create_app(
            store_factory=lambda: store,
            identity_verifier=accepted,
        )
    )
    response = client.get(
        "/api/v1/me", headers={"Authorization": "Bearer firebase-token"}
    )
    assert response.status_code == 200
    assert response.json()["id"] == str(ABDULLAH_ID)

    uuid_store = seeded_store()
    uuid_user = uuid_store.users.get(ABDULLAH_ID)
    assert uuid_user is not None
    uuid_store.users.save(
        uuid_user.model_copy(update={"auth_subject": "a-different-firebase-uid"})
    )
    uuid_shaped_uid = TestClient(
        create_app(
            store_factory=lambda: uuid_store,
            identity_verifier=FirebaseIdentityVerifier(
                verify_token=lambda token: {"uid": str(ABDULLAH_ID)}
            ),
        )
    )
    assert (
        uuid_shaped_uid.get(
            "/api/v1/me", headers={"Authorization": "Bearer firebase-token"}
        ).status_code
        == 401
    )

    def reject(_: str):
        raise ValueError("bad token")

    rejected = TestClient(
        create_app(
            store_factory=seeded_store,
            identity_verifier=FirebaseIdentityVerifier(verify_token=reject),
        )
    )
    assert (
        rejected.get(
            "/api/v1/me", headers={"Authorization": "Bearer invalid"}
        ).status_code
        == 401
    )


def test_firebase_emulator_seed_guard_accepts_only_loopback_hosts() -> None:
    assert _is_loopback_host("127.0.0.1:9099")
    assert _is_loopback_host("localhost:9099")
    assert not _is_loopback_host("firebase.example.com:9099")
    assert not _is_loopback_host("https://127.0.0.1:9099")


def test_family_roles_bound_privileged_writes() -> None:
    client = TestClient(create_app(store_factory=seeded_store, allow_demo_auth=True))
    permission_route = f"/api/v1/families/{FAMILY_ID}/permissions/{ABDULLAH_ID}"

    adult_denied = client.patch(
        permission_route,
        headers={"X-Demo-User": str(MOM_ID)},
        json={"can_invite": True},
    )
    assert adult_denied.status_code == 403

    outsider_denied = client.post(
        f"/api/v1/families/{FAMILY_ID}/messages",
        headers={"X-Demo-User": str(OUTSIDER_ID)},
        json={"client_id": str(uuid4()), "body": "Cross-family write"},
    )
    assert outsider_denied.status_code == 403

    organizer_allowed = client.patch(
        permission_route,
        headers={"X-Demo-User": str(DAD_ID)},
        json={"can_invite": True},
    )
    assert organizer_allowed.status_code == 200
