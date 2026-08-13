"""SQLAlchemy-backed storage with the same boundary as the in-memory store."""

from __future__ import annotations

import hashlib
import os
from collections.abc import Callable
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Generic, TypeVar, cast
from uuid import UUID

from pydantic import BaseModel
from sqlalchemy import (
    JSON,
    DateTime,
    Integer,
    String,
    Uuid,
    create_engine,
    select,
    text,
)
from sqlalchemy.engine import URL, Engine, make_url
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker
from sqlalchemy.pool import StaticPool

from .models import (
    CheckIn,
    DeviceToken,
    Family,
    FamilyCompassArtifact,
    Invitation,
    InvitationState,
    Journey,
    Membership,
    MemberStatus,
    Message,
    Plan,
    Reminder,
    SharedUpdate,
    User,
)
from .store import StoreConflict

DEFAULT_DATABASE_URL = "sqlite+pysqlite:///./.data/family_compass.db"
SCHEMA_VERSION = 4


class Base(DeclarativeBase):
    pass


class SchemaVersionRow(Base):
    __tablename__ = "schema_versions"

    version: Mapped[int] = mapped_column(Integer, primary_key=True)
    applied_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )


class _AggregateRow:
    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True)
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)


class UserRow(_AggregateRow, Base):
    __tablename__ = "users"


class FamilyRow(_AggregateRow, Base):
    __tablename__ = "families"


class MembershipRow(_AggregateRow, Base):
    __tablename__ = "memberships"


class InvitationRow(_AggregateRow, Base):
    __tablename__ = "invitations"


class MessageRow(_AggregateRow, Base):
    __tablename__ = "messages"


class SharedUpdateRow(_AggregateRow, Base):
    __tablename__ = "shared_updates"


class PlanRow(_AggregateRow, Base):
    __tablename__ = "plans"


class CheckInRow(_AggregateRow, Base):
    __tablename__ = "check_ins"


class ReminderRow(_AggregateRow, Base):
    __tablename__ = "reminders"


class MemberStatusRow(_AggregateRow, Base):
    __tablename__ = "member_statuses"


class JourneyRow(_AggregateRow, Base):
    __tablename__ = "journeys"


class DeviceTokenRow(_AggregateRow, Base):
    __tablename__ = "device_tokens"


class FamilyCompassArtifactRow(_AggregateRow, Base):
    __tablename__ = "family_compass_artifacts"


class DeviceTokenClaimRow(Base):
    __tablename__ = "device_token_claims"

    token_hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    device_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), unique=True)
    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)


class MembershipClaimRow(Base):
    __tablename__ = "membership_claims"

    family_user_key: Mapped[str] = mapped_column(String(73), primary_key=True)
    membership_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), unique=True)


class AuthSubjectClaimRow(Base):
    __tablename__ = "auth_subject_claims"

    auth_subject: Mapped[str] = mapped_column(String(256), primary_key=True)
    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), unique=True)


class PhoneNumberClaimRow(Base):
    __tablename__ = "phone_number_claims"

    phone_digits: Mapped[str] = mapped_column(String(32), primary_key=True)
    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), unique=True)


ModelT = TypeVar("ModelT", bound=BaseModel)
RowT = TypeVar("RowT", bound=_AggregateRow)


class SqlAlchemyRepository(Generic[ModelT, RowT]):
    """Persist one Pydantic aggregate without leaking ORM objects upward."""

    def __init__(
        self,
        session_factory: Callable[[], Session],
        row_type: type[RowT],
        model_type: type[ModelT],
    ) -> None:
        self._session_factory = session_factory
        self._row_type = row_type
        self._model_type = model_type

    def all(self) -> list[ModelT]:
        with self._session_factory() as session:
            rows = session.scalars(select(self._row_type)).all()
            return [self._decode(row.payload) for row in rows]

    def get(self, item_id: UUID) -> ModelT | None:
        with self._session_factory() as session:
            row = session.get(self._row_type, item_id)
            return self._decode(row.payload) if row else None

    def save(self, value: ModelT) -> ModelT:
        payload = cast(dict[str, Any], value.model_dump(mode="json"))
        with self._session_factory.begin() as session:
            row = session.get(self._row_type, value.id)
            if row is None:
                session.add(self._row_type(id=value.id, payload=payload))
            else:
                row.payload = payload
        return value

    def delete(self, item_id: UUID) -> bool:
        with self._session_factory.begin() as session:
            row = session.get(self._row_type, item_id)
            if row is None:
                return False
            session.delete(row)
            return True

    def _decode(self, payload: dict[str, Any]) -> ModelT:
        return self._model_type.model_validate(payload)


class _SerializedSession:
    """One transaction, with SQLite writes serialized before their first read."""

    def __init__(
        self,
        session_factory: Callable[[], Session],
        is_sqlite: bool,
    ) -> None:
        self._session_factory = session_factory
        self._is_sqlite = is_sqlite
        self._session: Session | None = None

    def __enter__(self) -> Session:
        session = self._session_factory()
        self._session = session
        if self._is_sqlite:
            session.execute(text("BEGIN IMMEDIATE"))
        else:
            session.begin()
        return session

    def __exit__(self, error_type, error, traceback) -> bool:
        del error, traceback
        assert self._session is not None
        try:
            if error_type is None:
                self._session.commit()
            else:
                self._session.rollback()
        finally:
            self._session.close()
        return False


class SqlAlchemyStore:
    """Persistent repository bundle used by development and later PostgreSQL."""

    def __init__(self, engine: Engine) -> None:
        self.engine = engine
        self._sessions = sessionmaker(bind=engine, expire_on_commit=False)
        self.users = SqlAlchemyRepository(self._sessions, UserRow, User)
        self.families = SqlAlchemyRepository(self._sessions, FamilyRow, Family)
        self.memberships = SqlAlchemyRepository(
            self._sessions, MembershipRow, Membership
        )
        self.invitations = SqlAlchemyRepository(
            self._sessions, InvitationRow, Invitation
        )
        self.messages = SqlAlchemyRepository(self._sessions, MessageRow, Message)
        self.shared_updates = SqlAlchemyRepository(
            self._sessions, SharedUpdateRow, SharedUpdate
        )
        self.plans = SqlAlchemyRepository(self._sessions, PlanRow, Plan)
        self.check_ins = SqlAlchemyRepository(self._sessions, CheckInRow, CheckIn)
        self.reminders = SqlAlchemyRepository(self._sessions, ReminderRow, Reminder)
        self.statuses = SqlAlchemyRepository(
            self._sessions, MemberStatusRow, MemberStatus
        )
        self.journeys = SqlAlchemyRepository(self._sessions, JourneyRow, Journey)
        self.device_tokens = SqlAlchemyRepository(
            self._sessions, DeviceTokenRow, DeviceToken
        )
        self.compass_artifacts = SqlAlchemyRepository(
            self._sessions, FamilyCompassArtifactRow, FamilyCompassArtifact
        )
        self._backfill_integrity_claims()

    @classmethod
    def from_url(cls, database_url: str | None = None) -> SqlAlchemyStore:
        engine = create_database_engine(database_url)
        initialize_schema(engine)
        return cls(engine)

    def membership(self, family_id: UUID, user_id: UUID) -> Membership | None:
        return next(
            (
                membership
                for membership in self.memberships.all()
                if membership.family_id == family_id and membership.user_id == user_id
            ),
            None,
        )

    def claim_authenticated_user(self, value: User) -> User:
        if value.auth_subject is None:
            raise ValueError("An authenticated user requires an auth subject.")
        phone_digits = self._phone_digits(value.phone_number)
        try:
            with self._serialized_session() as session:
                subject_claim = session.get(
                    AuthSubjectClaimRow,
                    value.auth_subject,
                )
                if subject_claim is not None:
                    row = session.get(UserRow, subject_claim.user_id)
                    if row is None:
                        raise RuntimeError("An auth subject claim has no user.")
                    return User.model_validate(row.payload)

                phone_claim = session.get(PhoneNumberClaimRow, phone_digits)
                if phone_claim is not None:
                    row = session.get(UserRow, phone_claim.user_id)
                    if row is None:
                        raise RuntimeError("A phone number claim has no user.")
                    existing = User.model_validate(row.payload)
                    if existing.auth_subject not in (None, value.auth_subject):
                        raise StoreConflict(
                            "Phone number is linked to another account."
                        )
                    linked = existing.model_copy(
                        update={"auth_subject": value.auth_subject}
                    )
                    self._upsert(session, UserRow, linked)
                    session.add(
                        AuthSubjectClaimRow(
                            auth_subject=value.auth_subject,
                            user_id=linked.id,
                        )
                    )
                    return linked

                self._upsert(session, UserRow, value)
                session.add(
                    AuthSubjectClaimRow(
                        auth_subject=value.auth_subject,
                        user_id=value.id,
                    )
                )
                session.add(
                    PhoneNumberClaimRow(
                        phone_digits=phone_digits,
                        user_id=value.id,
                    )
                )
                return value
        except StoreConflict:
            raise
        except IntegrityError as error:
            raise StoreConflict("Authenticated account is already linked.") from error

    def create_family(self, family: Family, membership: Membership) -> Family:
        with self._serialized_session() as session:
            self._upsert(session, FamilyRow, family)
            self._upsert(session, MembershipRow, membership)
            session.add(
                MembershipClaimRow(
                    family_user_key=self._membership_key(
                        membership.family_id, membership.user_id
                    ),
                    membership_id=membership.id,
                )
            )
        return family

    def accept_invitation(
        self,
        membership: Membership,
        family: Family,
        invitation: Invitation,
    ) -> Invitation:
        try:
            with self._serialized_session() as session:
                invitation_row = session.scalar(
                    select(InvitationRow)
                    .where(InvitationRow.id == invitation.id)
                    .with_for_update()
                )
                if invitation_row is None:
                    raise StoreConflict("Invitation no longer exists.")
                current_invitation = Invitation.model_validate(invitation_row.payload)
                if current_invitation.state != InvitationState.PENDING:
                    raise StoreConflict("Invitation has already been handled.")
                membership_key = self._membership_key(
                    membership.family_id, membership.user_id
                )
                if session.get(MembershipClaimRow, membership_key) is not None:
                    raise StoreConflict("Account is already a family member.")
                family_row = session.scalar(
                    select(FamilyRow).where(FamilyRow.id == family.id).with_for_update()
                )
                if family_row is None:
                    raise StoreConflict("Family no longer exists.")
                current_family = Family.model_validate(family_row.payload)
                accepted_family = current_family.model_copy(
                    update={
                        "member_ids": list(
                            dict.fromkeys(
                                [*current_family.member_ids, membership.user_id]
                            )
                        )
                    }
                )
                self._upsert(session, MembershipRow, membership)
                session.add(
                    MembershipClaimRow(
                        family_user_key=membership_key,
                        membership_id=membership.id,
                    )
                )
                self._upsert(session, FamilyRow, accepted_family)
                self._upsert(session, InvitationRow, invitation)
            return invitation
        except StoreConflict:
            raise
        except IntegrityError as error:
            raise StoreConflict("Account is already a family member.") from error

    def remove_family_member(
        self,
        membership_id: UUID,
        family: Family,
        user_id: UUID,
    ) -> Family:
        with self._serialized_session() as session:
            membership_row = session.get(MembershipRow, membership_id)
            if membership_row is not None:
                session.delete(membership_row)
            claim = session.get(
                MembershipClaimRow, self._membership_key(family.id, user_id)
            )
            if claim is not None:
                session.delete(claim)
            self._upsert(session, FamilyRow, family)
            self._delete_subject_rows(session, MemberStatusRow, family.id, user_id)
            self._delete_subject_rows(session, JourneyRow, family.id, user_id)
            self._delete_subject_rows(session, SharedUpdateRow, family.id, user_id)
        return family

    def delete_family(self, family_id: UUID) -> bool:
        with self._serialized_session() as session:
            family_row = session.get(FamilyRow, family_id)
            if family_row is None:
                return False
            scoped_rows: tuple[type[_AggregateRow], ...] = (
                MembershipRow,
                InvitationRow,
                MessageRow,
                SharedUpdateRow,
                PlanRow,
                CheckInRow,
                ReminderRow,
                MemberStatusRow,
                JourneyRow,
                FamilyCompassArtifactRow,
            )
            for row_type in scoped_rows:
                for row in session.scalars(select(row_type)).all():
                    if row.payload.get("family_id") == str(family_id):
                        session.delete(row)
            prefix = f"{family_id}:"
            for claim in session.scalars(select(MembershipClaimRow)).all():
                if claim.family_user_key.startswith(prefix):
                    session.delete(claim)
            session.delete(family_row)
            return True

    def claim_device_token(self, value: DeviceToken) -> DeviceToken:
        token_hash = self._token_hash(value.token)
        try:
            with self._serialized_session() as session:
                claim = session.get(DeviceTokenClaimRow, token_hash)
                if claim is not None and claim.user_id != value.user_id:
                    raise StoreConflict("Device token is already claimed.")
                if claim is not None:
                    current_row = session.get(DeviceTokenRow, claim.device_id)
                    if current_row is None:
                        session.delete(claim)
                        claim = None
                    else:
                        value = value.model_copy(update={"id": claim.device_id})
                if claim is None:
                    session.add(
                        DeviceTokenClaimRow(
                            token_hash=token_hash,
                            device_id=value.id,
                            user_id=value.user_id,
                        )
                    )
                self._upsert(session, DeviceTokenRow, value)
            return value
        except StoreConflict:
            raise
        except IntegrityError as error:
            raise StoreConflict("Device token is already claimed.") from error

    def claim_compass_question(
        self,
        question: Message,
    ) -> tuple[Message, bool]:
        try:
            with self._serialized_session() as session:
                for row in session.scalars(select(MessageRow)).all():
                    existing = Message.model_validate(row.payload)
                    if existing.client_id != question.client_id:
                        continue
                    if self._same_compass_question(existing, question):
                        return existing, False
                    raise StoreConflict("Compass request identifier is already in use.")
                self._upsert(session, MessageRow, question)
            return question, True
        except StoreConflict:
            raise
        except IntegrityError as error:
            raise StoreConflict(
                "Compass request identifier is already in use."
            ) from error

    def save_compass_artifact(
        self,
        question: Message,
        artifact: FamilyCompassArtifact,
    ) -> tuple[FamilyCompassArtifact, bool]:
        try:
            with self._serialized_session() as session:
                artifact_row = session.get(FamilyCompassArtifactRow, artifact.id)
                if artifact_row is not None:
                    existing = FamilyCompassArtifact.model_validate(
                        artifact_row.payload
                    )
                    if self._same_compass_artifact_request(existing, question):
                        return existing, False
                    raise StoreConflict("Compass request identifier is already in use.")
                question_row = session.get(MessageRow, question.id)
                if question_row is None or not self._same_compass_question(
                    Message.model_validate(question_row.payload),
                    question,
                ):
                    raise StoreConflict("Compass question must be saved first.")
                self._upsert(session, FamilyCompassArtifactRow, artifact)
            return artifact, True
        except StoreConflict:
            raise
        except IntegrityError as error:
            raise StoreConflict(
                "Compass request identifier is already in use."
            ) from error

    def delete_device_token(self, item_id: UUID, user_id: UUID) -> bool:
        with self._serialized_session() as session:
            row = session.get(DeviceTokenRow, item_id)
            if row is None:
                return False
            value = DeviceToken.model_validate(row.payload)
            if value.user_id != user_id:
                return False
            claim = session.get(DeviceTokenClaimRow, self._token_hash(value.token))
            if claim is not None:
                session.delete(claim)
            session.delete(row)
            return True

    def claim_plan_nudge(
        self,
        plan_id: UUID,
        recipient_ids: list[UUID],
    ) -> Plan | None:
        with self._serialized_session() as session:
            row = session.scalar(
                select(PlanRow).where(PlanRow.id == plan_id).with_for_update()
            )
            if row is None:
                return None
            plan = Plan.model_validate(row.payload)
            now = datetime.now(timezone.utc)
            dispatch_is_fresh = (
                plan.nudge_dispatch_started_at is not None
                and plan.nudge_dispatch_started_at > now - timedelta(minutes=5)
            )
            if plan.nudge_delivered_at is not None or dispatch_is_fresh:
                return None
            recipients = plan.nudge_recipient_ids or recipient_ids
            claimed = plan.model_copy(
                update={
                    "nudged_at": plan.nudged_at or now,
                    "nudge_recipient_ids": recipients,
                    "nudge_dispatch_started_at": now,
                    "updated_at": now,
                }
            )
            self._upsert(session, PlanRow, claimed)
            return claimed

    def complete_plan_nudge(self, plan_id: UUID) -> None:
        with self._serialized_session() as session:
            row = session.get(PlanRow, plan_id)
            if row is None:
                return
            plan = Plan.model_validate(row.payload)
            if plan.nudge_delivered_at is None:
                self._upsert(
                    session,
                    PlanRow,
                    plan.model_copy(
                        update={"nudge_delivered_at": datetime.now(timezone.utc)}
                    ),
                )

    def release_plan_nudge(self, plan_id: UUID) -> None:
        with self._serialized_session() as session:
            row = session.scalar(
                select(PlanRow).where(PlanRow.id == plan_id).with_for_update()
            )
            if row is None:
                return
            plan = Plan.model_validate(row.payload)
            if plan.nudge_delivered_at is None:
                self._upsert(
                    session,
                    PlanRow,
                    plan.model_copy(update={"nudge_dispatch_started_at": None}),
                )

    def _backfill_integrity_claims(self) -> None:
        with self._serialized_session() as session:
            for row in session.scalars(select(UserRow)).all():
                user = User.model_validate(row.payload)
                phone_digits = self._phone_digits(user.phone_number)
                phone_claim = session.get(PhoneNumberClaimRow, phone_digits)
                if phone_claim is None:
                    session.add(
                        PhoneNumberClaimRow(
                            phone_digits=phone_digits,
                            user_id=user.id,
                        )
                    )
                elif phone_claim.user_id != user.id:
                    raise RuntimeError("A phone number has multiple persisted users.")
                if user.auth_subject is not None:
                    subject_claim = session.get(
                        AuthSubjectClaimRow,
                        user.auth_subject,
                    )
                    if subject_claim is None:
                        session.add(
                            AuthSubjectClaimRow(
                                auth_subject=user.auth_subject,
                                user_id=user.id,
                            )
                        )
                    elif subject_claim.user_id != user.id:
                        raise RuntimeError(
                            "An auth subject has multiple persisted users."
                        )
            for row in session.scalars(select(MembershipRow)).all():
                membership = Membership.model_validate(row.payload)
                key = self._membership_key(membership.family_id, membership.user_id)
                if session.get(MembershipClaimRow, key) is None:
                    session.add(
                        MembershipClaimRow(
                            family_user_key=key,
                            membership_id=membership.id,
                        )
                    )
            for row in session.scalars(select(DeviceTokenRow)).all():
                device = DeviceToken.model_validate(row.payload)
                token_hash = self._token_hash(device.token)
                claim = session.get(DeviceTokenClaimRow, token_hash)
                if claim is None:
                    session.add(
                        DeviceTokenClaimRow(
                            token_hash=token_hash,
                            device_id=device.id,
                            user_id=device.user_id,
                        )
                    )
                elif claim.user_id != device.user_id:
                    raise RuntimeError("A device token has multiple persisted owners.")

    @staticmethod
    def _membership_key(family_id: UUID, user_id: UUID) -> str:
        return f"{family_id}:{user_id}"

    @staticmethod
    def _token_hash(token: str) -> str:
        return hashlib.sha256(token.encode("utf-8")).hexdigest()

    @staticmethod
    def _phone_digits(value: str) -> str:
        return "".join(character for character in value if character.isdigit())

    @staticmethod
    def _same_compass_question(existing: Message, requested: Message) -> bool:
        return (
            existing.client_id == requested.client_id
            and existing.family_id == requested.family_id
            and existing.sender_id == requested.sender_id
            and existing.kind == requested.kind
            and existing.body == requested.body
        )

    @staticmethod
    def _same_compass_artifact_request(
        existing: FamilyCompassArtifact,
        question: Message,
    ) -> bool:
        return (
            existing.id == question.client_id
            and existing.family_id == question.family_id
            and existing.requested_by == question.sender_id
            and existing.request_message_id == question.id
        )

    def _serialized_session(self):
        return _SerializedSession(self._sessions, self.engine.dialect.name == "sqlite")

    @staticmethod
    def _upsert(
        session: Session,
        row_type: type[_AggregateRow],
        value: BaseModel,
    ) -> None:
        payload = cast(dict[str, Any], value.model_dump(mode="json"))
        row = session.get(row_type, value.id)
        if row is None:
            session.add(row_type(id=value.id, payload=payload))
        else:
            row.payload = payload

    @staticmethod
    def _delete_subject_rows(
        session: Session,
        row_type: type[_AggregateRow],
        family_id: UUID,
        user_id: UUID,
    ) -> None:
        for row in session.scalars(select(row_type)).all():
            payload = row.payload
            if payload.get("family_id") == str(family_id) and payload.get(
                "subject_user_id"
            ) == str(user_id):
                session.delete(row)

    def close(self) -> None:
        self.engine.dispose()


def normalize_database_url(value: str | None = None) -> str:
    """Accept common hosted PostgreSQL URLs and select SQLite for development."""

    raw = (value or os.getenv("DATABASE_URL") or DEFAULT_DATABASE_URL).strip()
    if raw.startswith("postgres://"):
        return "postgresql+psycopg://" + raw.removeprefix("postgres://")
    if raw.startswith("postgresql://"):
        return "postgresql+psycopg://" + raw.removeprefix("postgresql://")
    return raw


def create_database_engine(database_url: str | None = None) -> Engine:
    normalized = normalize_database_url(database_url)
    url = make_url(normalized)
    options: dict[str, Any] = {"pool_pre_ping": True}
    if url.get_backend_name() == "sqlite":
        options["connect_args"] = {"check_same_thread": False}
        if _is_memory_sqlite(url):
            options["poolclass"] = StaticPool
        else:
            _ensure_sqlite_parent(url)
    return create_engine(normalized, **options)


def initialize_schema(engine: Engine) -> None:
    """Create or migrate the aggregate schema and reject unknown newer versions."""

    Base.metadata.create_all(engine)
    with Session(engine) as session, session.begin():
        versions = session.scalars(select(SchemaVersionRow.version)).all()
        if not versions:
            session.add(
                SchemaVersionRow(
                    version=SCHEMA_VERSION,
                    applied_at=datetime.now(timezone.utc),
                )
            )
            return
        if versions in ([1], [2], [3]):
            previous_version = versions[0]
            session.add(
                SchemaVersionRow(
                    version=SCHEMA_VERSION,
                    applied_at=datetime.now(timezone.utc),
                )
            )
            previous = session.get(SchemaVersionRow, previous_version)
            assert previous is not None
            session.delete(previous)
            return
        if versions != [SCHEMA_VERSION]:
            raise RuntimeError(
                "Unsupported database schema version(s): "
                + ", ".join(str(version) for version in versions)
            )


def schema_versions(engine: Engine) -> list[int]:
    with Session(engine) as session:
        return list(session.scalars(select(SchemaVersionRow.version)).all())


def _is_memory_sqlite(url: URL) -> bool:
    return url.database in {None, "", ":memory:"}


def _ensure_sqlite_parent(url: URL) -> None:
    database = url.database
    if not database or database.startswith("file:"):
        return
    Path(database).expanduser().resolve().parent.mkdir(parents=True, exist_ok=True)
