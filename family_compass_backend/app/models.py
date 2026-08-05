from datetime import datetime, timezone
from enum import StrEnum
from typing import Any
from uuid import UUID, uuid4

from pydantic import BaseModel, Field


class FamilyRole(StrEnum):
    OWNER = "owner"
    ADMIN = "admin"
    ADULT = "adult"
    CHILD = "child"


class User(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    name: str
    phone_number: str


class Family(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    name: str
    owner_id: UUID
    member_ids: list[UUID] = Field(default_factory=list)


class Invitation(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    family_id: UUID
    invited_by: UUID
    phone_number: str
    role: FamilyRole = FamilyRole.ADULT
    state: str = "pending"
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class Message(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    family_id: UUID
    sender_id: UUID
    body: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class MemberStatus(BaseModel):
    user_id: UUID
    activity: str
    status: str
    detail: str
    battery: int = Field(ge=0, le=100)
    latitude: float | None = None
    longitude: float | None = None
    sharing: str = "precise"
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class Journey(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    family_id: UUID
    user_id: UUID
    origin: str
    destination: str
    eta: datetime
    delay_minutes: int = 0
    assessment: str = "normal"
    sharing_active: bool = True


class Reminder(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    family_id: UUID
    title: str
    when: str
    assignee: str
    completed: bool = False


class Permission(BaseModel):
    user_id: UUID
    family_id: UUID
    role: FamilyRole
    can_invite: bool = False
    can_manage_plans: bool = True
    location_sharing: str = "precise"


class CheckIn(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    family_id: UUID
    user_id: UUID
    state: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class FamilySuggestion(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    family_id: UUID
    title: str
    reason: str
    options: list[str]


class InvitationCreate(BaseModel):
    family_id: UUID
    invited_by: UUID
    phone_number: str = Field(min_length=7, max_length=20)
    role: FamilyRole = FamilyRole.ADULT


class MessageCreate(BaseModel):
    family_id: UUID
    sender_id: UUID
    body: str = Field(min_length=1, max_length=2000)


class ReminderCreate(BaseModel):
    family_id: UUID
    title: str
    when: str
    assignee: str


class CheckInCreate(BaseModel):
    family_id: UUID
    user_id: UUID
    state: str


class PermissionUpdate(BaseModel):
    role: FamilyRole | None = None
    can_invite: bool | None = None
    can_manage_plans: bool | None = None
    location_sharing: str | None = None


class AIRequest(BaseModel):
    family_id: UUID
    user_id: UUID
    prompt: str = Field(min_length=1, max_length=2000)
    context: dict[str, Any] = Field(default_factory=dict)


class AIResponse(BaseModel):
    answer: str
    provider: str
    grounded_facts: list[str]
    suggested_actions: list[str]
