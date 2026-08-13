from __future__ import annotations

import base64
import hashlib
import json
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.auth import (
    AuthCredentials,
    AuthenticationInvalid,
    FirebaseIdentityVerifier,
    FirebaseLocalTestIdentityVerifier,
    IdentityProviderUnavailable,
    verifier_from_environment,
)
from app.database import SqlAlchemyStore
from app.main import create_app
from app.models import User
from app.store import Store, StoreConflict


def _client(claims_by_token: dict[str, dict]) -> TestClient:
    def verify(token: str):
        return claims_by_token[token]

    store = Store()
    return TestClient(
        create_app(
            store_factory=lambda: store,
            identity_verifier=FirebaseIdentityVerifier(verify_token=verify),
            seed_development_data=False,
        )
    )


def _phone_claims(uid: str, phone: str = "+971501112233") -> dict:
    return {
        "uid": uid,
        "phone_number": phone,
        "firebase": {"sign_in_provider": "phone"},
    }


LOCAL_TEST_PROJECT = "family-compass-local-test"
LOCAL_TEST_PHONE = "+12025550199"
LOCAL_TEST_NOW = 2_000_000_000


def _local_test_claims() -> dict:
    return {
        "aud": LOCAL_TEST_PROJECT,
        "iss": f"https://securetoken.google.com/{LOCAL_TEST_PROJECT}",
        "sub": "firebase-local-test-user",
        "iat": LOCAL_TEST_NOW - 60,
        "exp": LOCAL_TEST_NOW + 3_600,
        "auth_time": LOCAL_TEST_NOW - 120,
        "phone_number": LOCAL_TEST_PHONE,
        "firebase": {"sign_in_provider": "phone"},
    }


def _local_test_verifier(claims: dict) -> FirebaseLocalTestIdentityVerifier:
    return FirebaseLocalTestIdentityVerifier(
        project_id=LOCAL_TEST_PROJECT,
        expected_phone_sha256=hashlib.sha256(
            LOCAL_TEST_PHONE.encode("utf-8")
        ).hexdigest(),
        verify_token=lambda _: claims,
        now=lambda: LOCAL_TEST_NOW,
    )


def _fake_signed_token(header: dict | None = None) -> str:
    encoded_header = base64.urlsafe_b64encode(
        json.dumps(
            header if header is not None else {"alg": "RS256", "kid": "test-key"}
        ).encode("utf-8")
    ).rstrip(b"=")
    return f"{encoded_header.decode('ascii')}.payload.signature"


def test_firebase_environment_modes_are_secure_by_default(monkeypatch) -> None:
    monkeypatch.setenv("FAMILY_COMPASS_AUTH_MODE", "firebase")
    monkeypatch.setenv("FAMILY_COMPASS_FIREBASE_CHECK_REVOKED", "false")

    default_verifier = verifier_from_environment()
    assert isinstance(default_verifier, FirebaseIdentityVerifier)
    assert default_verifier.check_revoked is True

    monkeypatch.setenv("FAMILY_COMPASS_AUTH_MODE", "firebase_local_test")
    monkeypatch.setenv("FIREBASE_PROJECT_ID", LOCAL_TEST_PROJECT)
    monkeypatch.setenv(
        "FAMILY_COMPASS_FIREBASE_LOCAL_TEST_PHONE_SHA256",
        hashlib.sha256(LOCAL_TEST_PHONE.encode("utf-8")).hexdigest(),
    )
    local_test_verifier = verifier_from_environment()
    assert isinstance(local_test_verifier, FirebaseLocalTestIdentityVerifier)
    assert local_test_verifier.check_revoked is False


def test_local_test_verifier_accepts_only_the_configured_phone_account() -> None:
    identity = _local_test_verifier(_local_test_claims()).verify(
        AuthCredentials(authorization="Bearer signed-token")
    )

    assert identity.subject == "firebase-local-test-user"
    assert identity.phone_number == LOCAL_TEST_PHONE
    assert identity.sign_in_provider == "phone"


@pytest.mark.parametrize(
    ("claim", "invalid_value"),
    (
        ("aud", "another-project"),
        ("iss", "https://securetoken.google.com/another-project"),
        ("exp", LOCAL_TEST_NOW - 61),
    ),
)
def test_local_test_verifier_rejects_invalid_standard_claims(
    claim: str,
    invalid_value: str | int,
) -> None:
    claims = _local_test_claims()
    claims[claim] = invalid_value

    with pytest.raises(AuthenticationInvalid):
        _local_test_verifier(claims).verify(
            AuthCredentials(authorization="Bearer signed-token")
        )


def test_local_test_verifier_rejects_non_phone_provider() -> None:
    claims = _local_test_claims()
    claims["firebase"] = {"sign_in_provider": "password"}

    with pytest.raises(AuthenticationInvalid):
        _local_test_verifier(claims).verify(
            AuthCredentials(authorization="Bearer signed-token")
        )


def test_local_test_verifier_rejects_another_phone_account() -> None:
    claims = _local_test_claims()
    claims["phone_number"] = "+12025550198"

    with pytest.raises(AuthenticationInvalid):
        _local_test_verifier(claims).verify(
            AuthCredentials(authorization="Bearer signed-token")
        )


def test_local_test_verifier_uses_google_public_key_verification(monkeypatch) -> None:
    from google.oauth2 import id_token

    calls: dict[str, object] = {}

    def verify(token, request, *, audience, clock_skew_in_seconds):
        calls.update(
            token=token,
            request=request,
            audience=audience,
            clock_skew_in_seconds=clock_skew_in_seconds,
        )
        return _local_test_claims()

    monkeypatch.setattr(id_token, "verify_firebase_token", verify)
    verifier = FirebaseLocalTestIdentityVerifier(
        project_id=LOCAL_TEST_PROJECT,
        expected_phone_sha256=hashlib.sha256(
            LOCAL_TEST_PHONE.encode("utf-8")
        ).hexdigest(),
        now=lambda: LOCAL_TEST_NOW,
    )

    identity = verifier.verify(
        AuthCredentials(authorization=f"Bearer {_fake_signed_token()}")
    )

    assert identity.subject == "firebase-local-test-user"
    assert calls["token"] == _fake_signed_token()
    assert calls["audience"] == LOCAL_TEST_PROJECT
    assert calls["clock_skew_in_seconds"] == 60


@pytest.mark.parametrize(
    "header",
    (
        {"alg": "HS256", "kid": "test-key"},
        {"alg": "RS256"},
        {"alg": "RS256", "kid": ""},
    ),
)
def test_local_test_public_key_verifier_rejects_invalid_headers(
    monkeypatch,
    header: dict,
) -> None:
    from google.oauth2 import id_token

    monkeypatch.setattr(
        id_token,
        "verify_firebase_token",
        lambda *args, **kwargs: _local_test_claims(),
    )
    verifier = FirebaseLocalTestIdentityVerifier(
        project_id=LOCAL_TEST_PROJECT,
        expected_phone_sha256=hashlib.sha256(
            LOCAL_TEST_PHONE.encode("utf-8")
        ).hexdigest(),
        now=lambda: LOCAL_TEST_NOW,
    )

    with pytest.raises(AuthenticationInvalid):
        verifier.verify(
            AuthCredentials(authorization=f"Bearer {_fake_signed_token(header)}")
        )


def test_local_test_public_key_transport_failure_is_unavailable(monkeypatch) -> None:
    from google.auth import exceptions as google_auth_exceptions
    from google.oauth2 import id_token

    def fail(*args, **kwargs):
        raise google_auth_exceptions.TransportError("offline")

    monkeypatch.setattr(id_token, "verify_firebase_token", fail)
    verifier = FirebaseLocalTestIdentityVerifier(
        project_id=LOCAL_TEST_PROJECT,
        expected_phone_sha256=hashlib.sha256(
            LOCAL_TEST_PHONE.encode("utf-8")
        ).hexdigest(),
        now=lambda: LOCAL_TEST_NOW,
    )

    with pytest.raises(IdentityProviderUnavailable):
        verifier.verify(AuthCredentials(authorization=f"Bearer {_fake_signed_token()}"))


def test_verified_phone_user_registers_then_authenticates_idempotently() -> None:
    client = _client({"first": _phone_claims("firebase-user-one")})
    headers = {"Authorization": "Bearer first"}

    created = client.post(
        "/api/v1/auth/phone/register",
        headers=headers,
        json={"name": "Abdullah"},
    )
    repeated = client.post(
        "/api/v1/auth/phone/register",
        headers=headers,
        json={"name": "A changed client value"},
    )
    me = client.get("/api/v1/me", headers=headers)

    assert created.status_code == 201
    assert repeated.status_code == 201
    assert repeated.json()["id"] == created.json()["id"]
    assert repeated.json()["name"] == "Abdullah"
    assert me.status_code == 200
    assert me.json() == created.json()
    assert "phone" not in created.text.casefold()


def test_registration_requires_phone_provider_claims() -> None:
    client = _client(
        {
            "password": {
                "uid": "firebase-password-user",
                "firebase": {"sign_in_provider": "password"},
            }
        }
    )

    response = client.post(
        "/api/v1/auth/phone/register",
        headers={"Authorization": "Bearer password"},
        json={"name": "Someone"},
    )

    assert response.status_code == 403


def test_phone_number_cannot_be_linked_to_two_firebase_subjects() -> None:
    client = _client(
        {
            "first": _phone_claims("firebase-user-one"),
            "second": _phone_claims("firebase-user-two"),
        }
    )
    assert (
        client.post(
            "/api/v1/auth/phone/register",
            headers={"Authorization": "Bearer first"},
            json={"name": "First"},
        ).status_code
        == 201
    )

    conflict = client.post(
        "/api/v1/auth/phone/register",
        headers={"Authorization": "Bearer second"},
        json={"name": "Second"},
    )

    assert conflict.status_code == 409
    assert "501112233" not in conflict.text


def test_incoming_invitations_support_private_recipient_choice_and_decline() -> None:
    client = _client(
        {
            "organizer-one": _phone_claims("firebase-organizer-one", "+12025550101"),
            "organizer-two": _phone_claims("firebase-organizer-two", "+12025550104"),
            "recipient": _phone_claims("firebase-recipient", "+12025550102"),
            "outsider": _phone_claims("firebase-outsider", "+12025550103"),
        }
    )
    organizer_one_headers = {"Authorization": "Bearer organizer-one"}
    organizer_two_headers = {"Authorization": "Bearer organizer-two"}
    recipient_headers = {"Authorization": "Bearer recipient"}
    outsider_headers = {"Authorization": "Bearer outsider"}
    for headers, name in (
        (organizer_one_headers, "Amina"),
        (organizer_two_headers, "Layla"),
        (recipient_headers, "Recipient"),
        (outsider_headers, "Outsider"),
    ):
        assert (
            client.post(
                "/api/v1/auth/phone/register",
                headers=headers,
                json={"name": name},
            ).status_code
            == 201
        )

    family_one = client.post(
        "/api/v1/families",
        headers=organizer_one_headers,
        json={"name": "Friday family"},
    ).json()
    family_two = client.post(
        "/api/v1/families",
        headers=organizer_two_headers,
        json={"name": "Sunday family"},
    ).json()
    invitation_one = client.post(
        f"/api/v1/families/{family_one['id']}/invitations",
        headers=organizer_one_headers,
        json={"phone_number": "+12025550102", "role": "adult"},
    ).json()
    invitation_two = client.post(
        f"/api/v1/families/{family_two['id']}/invitations",
        headers=organizer_two_headers,
        json={"phone_number": "+12025550102", "role": "adult"},
    ).json()
    outsider_invitation = client.post(
        f"/api/v1/families/{family_one['id']}/invitations",
        headers=organizer_one_headers,
        json={"phone_number": "+12025550103", "role": "adult"},
    ).json()

    incoming = client.get("/api/v1/invitations", headers=recipient_headers)
    outsider_incoming = client.get("/api/v1/invitations", headers=outsider_headers)

    assert incoming.status_code == 200
    assert [value["id"] for value in incoming.json()] == [
        invitation_two["id"],
        invitation_one["id"],
    ]
    assert [
        (value["family_name"], value["inviter_name"]) for value in incoming.json()
    ] == [("Sunday family", "Layla"), ("Friday family", "Amina")]
    assert outsider_incoming.status_code == 200
    assert [value["id"] for value in outsider_incoming.json()] == [
        outsider_invitation["id"]
    ]
    assert "+12025550102" not in incoming.text

    declined = client.post(
        f"/api/v1/invitations/{invitation_two['id']}/decline",
        headers=recipient_headers,
    )
    assert declined.status_code == 200
    assert declined.json()["state"] == "declined"
    assert [
        value["id"]
        for value in client.get("/api/v1/invitations", headers=recipient_headers).json()
    ] == [invitation_one["id"]]

    accepted = client.post(
        f"/api/v1/invitations/{invitation_one['id']}/accept",
        headers=recipient_headers,
    )
    assert accepted.status_code == 200
    assert client.get("/api/v1/invitations", headers=recipient_headers).json() == []


def test_persistent_store_enforces_phone_and_subject_claims(tmp_path) -> None:
    database_path = tmp_path / "phone-claims.db"
    store = SqlAlchemyStore.from_url(f"sqlite:///{database_path}")
    first = User(
        id=uuid4(),
        name="First",
        phone_number="+971501112233",
        auth_subject="firebase-user-one",
    )

    claimed = store.claim_authenticated_user(first)
    repeated = store.claim_authenticated_user(
        first.model_copy(update={"id": uuid4(), "name": "Changed"})
    )

    assert repeated.id == claimed.id
    assert repeated.name == "First"
    with pytest.raises(StoreConflict):
        store.claim_authenticated_user(
            first.model_copy(
                update={
                    "id": uuid4(),
                    "name": "Second",
                    "auth_subject": "firebase-user-two",
                }
            )
        )
