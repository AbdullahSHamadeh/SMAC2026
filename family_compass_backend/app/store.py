from collections.abc import Iterable
from typing import Generic, TypeVar
from uuid import UUID

from pydantic import BaseModel

from .models import CheckIn, Family, Invitation, Journey, MemberStatus, Message, Permission, Reminder, User

T = TypeVar("T", bound=BaseModel)


class Repository(Generic[T]):
    """Replace this adapter with Firestore without changing route handlers."""

    def __init__(self, values: Iterable[T] = ()) -> None:
        self.items: dict[UUID, T] = {}
        for value in values:
            self.save(value)

    def _key(self, value: T) -> UUID:
        return getattr(value, "id", None) or getattr(value, "user_id")

    def all(self) -> list[T]:
        return list(self.items.values())

    def get(self, item_id: UUID) -> T | None:
        return self.items.get(item_id)

    def save(self, value: T) -> T:
        self.items[self._key(value)] = value
        return value


class Store:
    def __init__(self) -> None:
        self.users = Repository[User]()
        self.families = Repository[Family]()
        self.invitations = Repository[Invitation]()
        self.messages = Repository[Message]()
        self.statuses = Repository[MemberStatus]()
        self.journeys = Repository[Journey]()
        self.reminders = Repository[Reminder]()
        self.permissions = Repository[Permission]()
        self.check_ins = Repository[CheckIn]()
