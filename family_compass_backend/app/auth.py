"""Authentication providers for development tokens and Firebase ID tokens."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import re
import time
from abc import ABC, abstractmethod
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from typing import Any
from uuid import UUID

DEV_TOKEN_AUDIENCE = "family-compass-development"
DEV_TOKEN_PREFIX = "fc_dev"


class AuthenticationError(RuntimeError):
    pass


class AuthenticationRequired(AuthenticationError):
    pass


class AuthenticationInvalid(AuthenticationError):
    pass


class IdentityProviderUnavailable(AuthenticationError):
    pass


@dataclass(frozen=True)
class AuthCredentials:
    authorization: str | None = None
    demo_user: str | None = None


@dataclass(frozen=True)
class VerifiedIdentity:
    subject: str
    user_id: UUID | None = None
    phone_number: str | None = None
    sign_in_provider: str | None = None


class IdentityVerifier(ABC):
    @abstractmethod
    def verify(self, credentials: AuthCredentials) -> VerifiedIdentity:
        raise NotImplementedError


class DisabledIdentityVerifier(IdentityVerifier):
    def verify(self, credentials: AuthCredentials) -> VerifiedIdentity:
        del credentials
        raise IdentityProviderUnavailable("No identity verifier is configured.")


class LegacyDemoIdentityVerifier(IdentityVerifier):
    """Compatibility verifier available only through explicit app construction."""

    def verify(self, credentials: AuthCredentials) -> VerifiedIdentity:
        if not credentials.demo_user:
            raise AuthenticationRequired(
                "The prototype requires an X-Demo-User header."
            )
        try:
            user_id = UUID(credentials.demo_user)
        except ValueError as error:
            raise AuthenticationInvalid("Invalid demo user.") from error
        return VerifiedIdentity(subject=str(user_id), user_id=user_id)


class DevTokenIdentityVerifier(IdentityVerifier):
    """Verify short-lived HMAC tokens for local multi-device development."""

    def __init__(
        self,
        secret: str,
        *,
        max_ttl_seconds: int = 86_400,
        now: Callable[[], float] = time.time,
    ) -> None:
        if len(secret.encode("utf-8")) < 32:
            raise ValueError(
                "FAMILY_COMPASS_DEV_AUTH_SECRET must be at least 32 bytes."
            )
        self._secret = secret.encode("utf-8")
        self._max_ttl_seconds = max_ttl_seconds
        self._now = now

    def verify(self, credentials: AuthCredentials) -> VerifiedIdentity:
        token = _bearer_token(credentials.authorization)
        parts = token.split(".")
        if len(parts) != 3 or parts[0] != DEV_TOKEN_PREFIX:
            raise AuthenticationInvalid("Invalid development token.")
        prefix, encoded_payload, encoded_signature = parts
        signed = f"{prefix}.{encoded_payload}".encode("ascii")
        expected = hmac.new(self._secret, signed, hashlib.sha256).digest()
        try:
            received = _b64url_decode(encoded_signature)
        except ValueError as error:
            raise AuthenticationInvalid("Invalid development token.") from error
        if not hmac.compare_digest(received, expected):
            raise AuthenticationInvalid("Invalid development token.")
        try:
            claims = json.loads(_b64url_decode(encoded_payload))
            subject = claims["sub"]
            issued_at = int(claims["iat"])
            expires_at = int(claims["exp"])
        except (
            ValueError,
            UnicodeDecodeError,
            json.JSONDecodeError,
            KeyError,
            TypeError,
        ) as error:
            raise AuthenticationInvalid("Invalid development token.") from error
        now = int(self._now())
        if (
            claims.get("aud") != DEV_TOKEN_AUDIENCE
            or claims.get("v") != 1
            or not isinstance(subject, str)
            or not subject
            or issued_at > now + 60
            or expires_at <= now
            or expires_at <= issued_at
            or expires_at - issued_at > self._max_ttl_seconds
        ):
            raise AuthenticationInvalid("Expired or invalid development token.")
        try:
            user_id = UUID(subject)
        except ValueError:
            user_id = None
        return VerifiedIdentity(subject=subject, user_id=user_id)


class FirebaseIdentityVerifier(IdentityVerifier):
    """Verify Firebase ID tokens, including tokens issued by the Auth emulator."""

    def __init__(
        self,
        project_id: str | None = None,
        *,
        verify_token: Callable[[str], Mapping[str, Any]] | None = None,
        check_revoked: bool = True,
    ) -> None:
        self.project_id = (project_id or os.getenv("FIREBASE_PROJECT_ID", "")).strip()
        self._verify_token = verify_token
        self.check_revoked = check_revoked

    def verify(self, credentials: AuthCredentials) -> VerifiedIdentity:
        token = _bearer_token(credentials.authorization)
        verifier = self._verify_token or self._firebase_verifier()
        try:
            claims = verifier(token)
        except AuthenticationError:
            raise
        except Exception as error:
            raise AuthenticationInvalid("Invalid Firebase ID token.") from error
        return self._identity_from_claims(claims)

    @staticmethod
    def _identity_from_claims(claims: Mapping[str, Any]) -> VerifiedIdentity:
        subject = claims.get("uid") or claims.get("sub")
        if not isinstance(subject, str) or not subject:
            raise AuthenticationInvalid("Firebase token has no subject.")
        firebase_claim = claims.get("firebase")
        sign_in_provider = (
            firebase_claim.get("sign_in_provider")
            if isinstance(firebase_claim, Mapping)
            else None
        )
        phone_number = claims.get("phone_number")
        if sign_in_provider != "phone" or not isinstance(phone_number, str):
            phone_number = None
        # Firebase identities are linked only through User.auth_subject. A UID that
        # happens to resemble an internal UUID must not bind an account implicitly.
        return VerifiedIdentity(
            subject=subject,
            phone_number=phone_number,
            sign_in_provider=(
                sign_in_provider if isinstance(sign_in_provider, str) else None
            ),
        )

    def _firebase_verifier(self) -> Callable[[str], Mapping[str, Any]]:
        try:
            import firebase_admin
            from firebase_admin import auth
        except ImportError as error:
            raise IdentityProviderUnavailable(
                "Firebase authentication is configured but firebase-admin is not "
                "installed."
            ) from error
        try:
            firebase_app = firebase_admin.get_app()
        except ValueError:
            options = {"projectId": self.project_id} if self.project_id else None
            try:
                firebase_app = firebase_admin.initialize_app(options=options)
            except Exception as error:
                raise IdentityProviderUnavailable(
                    "Firebase Admin could not be initialized."
                ) from error

        def verify(token: str) -> Mapping[str, Any]:
            return auth.verify_id_token(
                token,
                app=firebase_app,
                check_revoked=self.check_revoked,
            )

        return verify


class FirebaseLocalTestIdentityVerifier(FirebaseIdentityVerifier):
    """Verify one fictional phone account without Firebase Admin credentials.

    This verifier is intentionally available only through the explicit
    ``firebase_local_test`` authentication mode. It verifies Google's signature
    and standard token dates, then independently checks the Firebase project,
    issuer, phone provider, and allowlisted fictional phone digest. It cannot
    check revocation and must never be used by a production deployment.
    """

    def __init__(
        self,
        project_id: str | None = None,
        *,
        expected_phone_sha256: str | None = None,
        verify_token: Callable[[str], Mapping[str, Any]] | None = None,
        now: Callable[[], float] = time.time,
    ) -> None:
        resolved_project_id = (
            project_id or os.getenv("FIREBASE_PROJECT_ID", "")
        ).strip()
        expected_digest = (
            expected_phone_sha256
            or os.getenv("FAMILY_COMPASS_FIREBASE_LOCAL_TEST_PHONE_SHA256", "")
        ).strip()
        if not resolved_project_id:
            raise ValueError(
                "FIREBASE_PROJECT_ID is required for firebase_local_test mode."
            )
        if re.fullmatch(r"[0-9a-f]{64}", expected_digest) is None:
            raise ValueError(
                "FAMILY_COMPASS_FIREBASE_LOCAL_TEST_PHONE_SHA256 must be a "
                "lowercase SHA-256 digest."
            )
        super().__init__(
            project_id=resolved_project_id,
            verify_token=verify_token,
            check_revoked=False,
        )
        self._expected_phone_sha256 = expected_digest
        self._now = now
        self._resolved_verifier: Callable[[str], Mapping[str, Any]] | None = None

    def verify(self, credentials: AuthCredentials) -> VerifiedIdentity:
        token = _bearer_token(credentials.authorization)
        verifier = self._verify_token or self._resolved_verifier
        if verifier is None:
            verifier = self._firebase_verifier()
            self._resolved_verifier = verifier
        try:
            claims = verifier(token)
        except IdentityProviderUnavailable:
            raise
        except AuthenticationError:
            raise
        except Exception as error:
            raise AuthenticationInvalid("Invalid Firebase ID token.") from error
        self._validate_local_test_claims(claims)
        return self._identity_from_claims(claims)

    def _validate_local_test_claims(self, claims: Mapping[str, Any]) -> None:
        now = int(self._now())
        subject = claims.get("sub")
        issued_at = claims.get("iat")
        expires_at = claims.get("exp")
        auth_time = claims.get("auth_time")
        expected_issuer = f"https://securetoken.google.com/{self.project_id}"
        firebase_claim = claims.get("firebase")
        sign_in_provider = (
            firebase_claim.get("sign_in_provider")
            if isinstance(firebase_claim, Mapping)
            else None
        )
        phone_number = claims.get("phone_number")

        numeric_dates = (issued_at, expires_at, auth_time)
        valid_dates = all(
            isinstance(value, int) and not isinstance(value, bool)
            for value in numeric_dates
        )
        valid_phone = (
            isinstance(phone_number, str)
            and re.fullmatch(r"\+[1-9][0-9]{7,14}", phone_number) is not None
        )
        phone_digest = (
            hashlib.sha256(phone_number.encode("utf-8")).hexdigest()
            if valid_phone
            else ""
        )
        if (
            claims.get("aud") != self.project_id
            or claims.get("iss") != expected_issuer
            or not isinstance(subject, str)
            or not subject
            or len(subject) > 128
            or not valid_dates
            or issued_at > now + 60
            or auth_time > now + 60
            or expires_at <= now - 60
            or expires_at <= issued_at
            or sign_in_provider != "phone"
            or not hmac.compare_digest(phone_digest, self._expected_phone_sha256)
        ):
            raise AuthenticationInvalid(
                "Firebase token is not valid for the configured local test account."
            )

    def _firebase_verifier(self) -> Callable[[str], Mapping[str, Any]]:
        try:
            from cachecontrol import CacheControl
            from google.auth import exceptions as google_auth_exceptions
            from google.auth.transport.requests import Request
            from google.oauth2 import id_token
            from requests import RequestException, Session
        except ImportError as error:
            raise IdentityProviderUnavailable(
                "Firebase local test authentication requires google-auth."
            ) from error

        request = Request(session=CacheControl(Session()))

        def verify(token: str) -> Mapping[str, Any]:
            self._validate_token_header(token)
            try:
                return id_token.verify_firebase_token(
                    token,
                    request,
                    audience=self.project_id,
                    clock_skew_in_seconds=60,
                )
            except (google_auth_exceptions.TransportError, RequestException) as error:
                raise IdentityProviderUnavailable(
                    "Firebase public signing keys are temporarily unavailable."
                ) from error

        return verify

    @staticmethod
    def _validate_token_header(token: str) -> None:
        try:
            header_part, _, _ = token.split(".")
            header = json.loads(_b64url_decode(header_part))
        except (
            ValueError,
            UnicodeDecodeError,
            json.JSONDecodeError,
            TypeError,
        ) as error:
            raise AuthenticationInvalid("Invalid Firebase ID token.") from error
        if (
            not isinstance(header, Mapping)
            or header.get("alg") != "RS256"
            or not isinstance(header.get("kid"), str)
            or not header["kid"]
        ):
            raise AuthenticationInvalid("Invalid Firebase ID token.")


def verifier_from_environment(
    allow_demo_auth: bool | None = None,
) -> IdentityVerifier:
    if allow_demo_auth is True:
        return LegacyDemoIdentityVerifier()
    if allow_demo_auth is False:
        return DisabledIdentityVerifier()

    mode = os.getenv("FAMILY_COMPASS_AUTH_MODE", "disabled").strip().casefold()
    if mode == "disabled":
        return DisabledIdentityVerifier()
    if mode == "dev":
        secret = os.getenv("FAMILY_COMPASS_DEV_AUTH_SECRET", "")
        return DevTokenIdentityVerifier(secret)
    if mode == "firebase":
        return FirebaseIdentityVerifier(check_revoked=True)
    if mode == "firebase_local_test":
        return FirebaseLocalTestIdentityVerifier()
    raise ValueError(f"Unknown FAMILY_COMPASS_AUTH_MODE: {mode}")


def issue_dev_token(
    user_id: UUID,
    secret: str,
    *,
    ttl_seconds: int = 3_600,
    now: int | None = None,
) -> str:
    if len(secret.encode("utf-8")) < 32:
        raise ValueError("Development token secret must be at least 32 bytes.")
    if ttl_seconds < 1 or ttl_seconds > 86_400:
        raise ValueError("Development tokens must last between 1 and 86400 seconds.")
    issued_at = int(time.time() if now is None else now)
    payload = {
        "aud": DEV_TOKEN_AUDIENCE,
        "exp": issued_at + ttl_seconds,
        "iat": issued_at,
        "sub": str(user_id),
        "v": 1,
    }
    encoded_payload = _b64url_encode(
        json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
    )
    signed = f"{DEV_TOKEN_PREFIX}.{encoded_payload}"
    signature = hmac.new(
        secret.encode("utf-8"), signed.encode("ascii"), hashlib.sha256
    ).digest()
    return f"{signed}.{_b64url_encode(signature)}"


def _bearer_token(authorization: str | None) -> str:
    if not authorization:
        raise AuthenticationRequired("A bearer token is required.")
    scheme, separator, token = authorization.partition(" ")
    if separator != " " or scheme.casefold() != "bearer" or not token.strip():
        raise AuthenticationInvalid("Use an Authorization: Bearer token header.")
    return token.strip()


def _b64url_encode(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def _b64url_decode(value: str) -> bytes:
    try:
        padding = "=" * (-len(value) % 4)
        return base64.b64decode(value + padding, altchars=b"-_", validate=True)
    except (ValueError, UnicodeEncodeError) as error:
        raise ValueError("Invalid base64url value.") from error
