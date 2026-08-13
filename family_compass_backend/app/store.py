from collections.abc import Iterable
from datetime import datetime, timedelta, timezone
from threading import RLock
from typing import Generic, Protocol, TypeVar
from uuid import UUID

from pydantic import BaseModel

from .models import (
    CheckIn,
    DeviceToken,
    Family,
    FamilyCompassArtifact,
    Invitation,
    Journey,
    Membership,
    MemberStatus,
    Message,
    Plan,
    Reminder,
    SharedUpdate,
    User,
)

T = TypeVar("T", bound=BaseModel)


class StoreConflict(RuntimeError):
    """A serialized store operation lost a race or violates uniqueness."""


class RepositoryProtocol(Protocol[T]):
    """Storage operations used by the application service layer."""

    def all(self) -> list[T]: ...

    def get(self, item_id: UUID) -> T | None: ...

    def save(self, value: T) -> T: ...

    def delete(self, item_id: UUID) -> bool: ...


class Repository(Generic[T]):
    """In-memory repository retained for isolated unit tests."""

    def __init__(self, values: Iterable[T] = ()) -> None:
        self.items: dict[UUID, T] = {}
        for value in values:
            self.save(value)

    def all(self) -> list[T]:
        return list(self.items.values())

    def get(self, item_id: UUID) -> T | None:
        return self.items.get(item_id)

    def save(self, value: T) -> T:
        self.items[value.id] = value
        return value

    def delete(self, item_id: UUID) -> bool:
        return self.items.pop(item_id, None) is not None


class StoreProtocol(Protocol):
    """Repository bundle implemented by memory and SQLAlchemy stores."""

    users: RepositoryProtocol[User]
    families: RepositoryProtocol[Family]
    memberships: RepositoryProtocol[Membership]
    invitations: RepositoryProtocol[Invitation]
    messages: RepositoryProtocol[Message]
    shared_updates: RepositoryProtocol[SharedUpdate]
    plans: RepositoryProtocol[Plan]
    check_ins: RepositoryProtocol[CheckIn]
    reminders: RepositoryProtocol[Reminder]
    statuses: RepositoryProtocol[MemberStatus]
    journeys: RepositoryProtocol[Journey]
    device_tokens: RepositoryProtocol[DeviceToken]
    compass_artifacts: RepositoryProtocol[FamilyCompassArtifact]

    def membership(self, family_id: UUID, user_id: UUID) -> Membership | None: ...

    def create_family(self, family: Family, membership: Membership) -> Family: ...

    def accept_invitation(
        self,
        membership: Membership,
        family: Family,
        invitation: Invitation,
    ) -> Invitation: ...

    def remove_family_member(
        self,
        membership_id: UUID,
        family: Family,
        user_id: UUID,
    ) -> Family: ...

    def delete_family(self, family_id: UUID) -> bool: ...

    def claim_device_token(self, value: DeviceToken) -> DeviceToken: ...

    def claim_compass_question(
        self,
        question: Message,
    ) -> tuple[Message, bool]: ...

    def save_compass_artifact(
        self,
        question: Message,
        artifact: FamilyCompassArtifact,
    ) -> tuple[FamilyCompassArtifact, bool]: ...

    def delete_device_token(self, item_id: UUID, user_id: UUID) -> bool: ...

    def claim_authenticated_user(self, value: User) -> User: ...

    def claim_plan_nudge(
        self,
        plan_id: UUID,
        recipient_ids: list[UUID],
    ) -> Plan | None: ...

    def complete_plan_nudge(self, plan_id: UUID) -> None: ...

    def release_plan_nudge(self, plan_id: UUID) -> None: ...

    def close(self) -> None: ...


class Store:
    """In-memory store used by fast tests and explicit prototype fixtures."""

    def __init__(self) -> None:
        self._transaction_lock = RLock()
        self.users = Repository[User]()
        self.families = Repository[Family]()
        self.memberships = Repository[Membership]()
        self.invitations = Repository[Invitation]()
        self.messages = Repository[Message]()
        self.shared_updates = Repository[SharedUpdate]()
        self.plans = Repository[Plan]()
        self.check_ins = Repository[CheckIn]()
        self.reminders = Repository[Reminder]()
        self.statuses = Repository[MemberStatus]()
        self.journeys = Repository[Journey]()
        self.device_tokens = Repository[DeviceToken]()
        self.compass_artifacts = Repository[FamilyCompassArtifact]()

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
        normalized_phone = _phone_digits(value.phone_number)
        with self._transaction_lock:
            subject_owner = next(
                (
                    user
                    for user in self.users.all()
                    if user.auth_subject == value.auth_subject
                ),
                None,
            )
            if subject_owner is not None:
                return subject_owner
            phone_owner = next(
                (
                    user
                    for user in self.users.all()
                    if _phone_digits(user.phone_number) == normalized_phone
                ),
                None,
            )
            if phone_owner is not None:
                if phone_owner.auth_subject not in (None, value.auth_subject):
                    raise StoreConflict("Phone number is linked to another account.")
                return self.users.save(
                    phone_owner.model_copy(update={"auth_subject": value.auth_subject})
                )
            return self.users.save(value)

    def create_family(self, family: Family, membership: Membership) -> Family:
        with self._transaction_lock:
            snapshots = (dict(self.families.items), dict(self.memberships.items))
            try:
                self.families.save(family)
                self.memberships.save(membership)
                return family
            except Exception:
                self.families.items, self.memberships.items = snapshots
                raise

    def accept_invitation(
        self,
        membership: Membership,
        family: Family,
        invitation: Invitation,
    ) -> Invitation:
        with self._transaction_lock:
            current_invitation = self.invitations.items.get(invitation.id)
            if (
                current_invitation is None
                or current_invitation.state.value != "pending"
                or self.membership(membership.family_id, membership.user_id) is not None
            ):
                raise StoreConflict("Invitation has already been accepted.")
            current_family = self.families.items.get(family.id)
            if current_family is None:
                raise StoreConflict("Family no longer exists.")
            accepted_family = current_family.model_copy(
                update={
                    "member_ids": list(
                        dict.fromkeys([*current_family.member_ids, membership.user_id])
                    )
                }
            )
            snapshots = (
                dict(self.memberships.items),
                dict(self.families.items),
                dict(self.invitations.items),
            )
            try:
                self.memberships.save(membership)
                self.families.save(accepted_family)
                self.invitations.save(invitation)
                return invitation
            except Exception:
                (
                    self.memberships.items,
                    self.families.items,
                    self.invitations.items,
                ) = snapshots
                raise

    def remove_family_member(
        self,
        membership_id: UUID,
        family: Family,
        user_id: UUID,
    ) -> Family:
        with self._transaction_lock:
            repositories = (
                self.memberships,
                self.families,
                self.statuses,
                self.journeys,
                self.shared_updates,
            )
            snapshots = tuple(dict(repository.items) for repository in repositories)
            try:
                self.memberships.delete(membership_id)
                self.families.save(family)
                for repository in (self.statuses, self.journeys, self.shared_updates):
                    for item_id, value in list(repository.items.items()):
                        if (
                            value.family_id == family.id
                            and value.subject_user_id == user_id
                        ):
                            repository.delete(item_id)
                return family
            except Exception:
                for repository, snapshot in zip(repositories, snapshots, strict=True):
                    repository.items = snapshot
                raise

    def delete_family(self, family_id: UUID) -> bool:
        with self._transaction_lock:
            if self.families.get(family_id) is None:
                return False
            repositories = (
                self.families,
                self.memberships,
                self.invitations,
                self.messages,
                self.shared_updates,
                self.plans,
                self.check_ins,
                self.reminders,
                self.statuses,
                self.journeys,
                self.compass_artifacts,
            )
            snapshots = tuple(dict(repository.items) for repository in repositories)
            try:
                for repository in repositories[1:]:
                    for item_id, value in list(repository.items.items()):
                        if value.family_id == family_id:
                            repository.delete(item_id)
                self.families.delete(family_id)
                return True
            except Exception:
                for repository, snapshot in zip(repositories, snapshots, strict=True):
                    repository.items = snapshot
                raise

    def claim_device_token(self, value: DeviceToken) -> DeviceToken:
        with self._transaction_lock:
            existing = next(
                (
                    device
                    for device in self.device_tokens.all()
                    if device.token == value.token
                ),
                None,
            )
            if existing is not None and existing.user_id != value.user_id:
                raise StoreConflict("Device token is already claimed.")
            saved = (
                value
                if existing is None
                else value.model_copy(update={"id": existing.id})
            )
            return self.device_tokens.save(saved)

    def claim_compass_question(
        self,
        question: Message,
    ) -> tuple[Message, bool]:
        with self._transaction_lock:
            existing = next(
                (
                    message
                    for message in self.messages.all()
                    if message.client_id == question.client_id
                ),
                None,
            )
            if existing is not None:
                if _same_compass_question(existing, question):
                    return existing, False
                raise StoreConflict("Compass request identifier is already in use.")
            return self.messages.save(question), True

    def save_compass_artifact(
        self,
        question: Message,
        artifact: FamilyCompassArtifact,
    ) -> tuple[FamilyCompassArtifact, bool]:
        with self._transaction_lock:
            existing = self.compass_artifacts.get(artifact.id)
            if existing is not None:
                if _same_compass_artifact_request(existing, question):
                    return existing, False
                raise StoreConflict("Compass request identifier is already in use.")
            saved_question = self.messages.get(question.id)
            if saved_question is None or not _same_compass_question(
                saved_question,
                question,
            ):
                raise StoreConflict("Compass question must be saved first.")
            return self.compass_artifacts.save(artifact), True

    def delete_device_token(self, item_id: UUID, user_id: UUID) -> bool:
        with self._transaction_lock:
            value = self.device_tokens.get(item_id)
            return bool(
                value
                and value.user_id == user_id
                and self.device_tokens.delete(item_id)
            )

    def claim_plan_nudge(
        self,
        plan_id: UUID,
        recipient_ids: list[UUID],
    ) -> Plan | None:
        with self._transaction_lock:
            plan = self.plans.items.get(plan_id)
            now = datetime.now(timezone.utc)
            dispatch_is_fresh = (
                plan is not None
                and plan.nudge_dispatch_started_at is not None
                and plan.nudge_dispatch_started_at
                > now.replace(microsecond=0) - timedelta(minutes=5)
            )
            if plan is None or plan.nudge_delivered_at is not None or dispatch_is_fresh:
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
            return self.plans.save(claimed)

    def complete_plan_nudge(self, plan_id: UUID) -> None:
        with self._transaction_lock:
            plan = self.plans.items.get(plan_id)
            if plan is not None and plan.nudge_delivered_at is None:
                now = datetime.now(timezone.utc)
                self.plans.save(plan.model_copy(update={"nudge_delivered_at": now}))

    def release_plan_nudge(self, plan_id: UUID) -> None:
        with self._transaction_lock:
            plan = self.plans.items.get(plan_id)
            if plan is not None and plan.nudge_delivered_at is None:
                self.plans.save(
                    plan.model_copy(update={"nudge_dispatch_started_at": None})
                )

    def close(self) -> None:
        """Match the persistent store lifecycle without holding resources."""


def _phone_digits(value: str) -> str:
    return "".join(character for character in value if character.isdigit())


def _same_compass_question(existing: Message, requested: Message) -> bool:
    return (
        existing.client_id == requested.client_id
        and existing.family_id == requested.family_id
        and existing.sender_id == requested.sender_id
        and existing.kind == requested.kind
        and existing.body == requested.body
    )


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
