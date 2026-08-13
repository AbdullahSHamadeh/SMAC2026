from datetime import datetime, timezone
from enum import StrEnum
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class APIRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")


class FamilyRole(StrEnum):
    ORGANIZER = "organizer"
    ADULT = "adult"


class InvitationState(StrEnum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    DECLINED = "declined"
    REVOKED = "revoked"
    EXPIRED = "expired"


class MessageKind(StrEnum):
    TEXT = "text"
    COMPASS_QUESTION = "compass_question"
    CHECK_IN = "check_in"
    PLAN = "plan"
    POLL = "poll"
    REMINDER = "reminder"


class SharedUpdateSource(StrEnum):
    MEMBER_SHARED = "member_shared"


class SharedUpdateAudience(StrEnum):
    WHOLE_FAMILY = "whole_family"
    SELECTED_PEOPLE = "selected_people"
    SELF_ONLY = "self_only"


class SharedUpdateState(StrEnum):
    ACTIVE = "active"
    PAUSED = "paused"
    REVOKED = "revoked"


class PlanPhase(StrEnum):
    DRAFT = "draft"
    POLL_OPEN = "poll_open"
    READY_TO_CONFIRM = "ready_to_confirm"
    CONFIRMED = "confirmed"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class RsvpChoice(StrEnum):
    GOING = "going"
    MAYBE = "maybe"
    CANNOT_MAKE_IT = "cannot_make_it"


class CompassVisibility(StrEnum):
    PRIVATE = "private"
    FAMILY_ROOM = "family_room"


class CompassFactSource(StrEnum):
    CHAT_MESSAGE = "chat_message"
    PLAN = "plan"
    REMINDER = "reminder"
    CHECK_IN = "check_in"
    SHARED_UPDATE = "shared_update"
    MEMBER_STATUS = "member_status"
    JOURNEY = "journey"


class CompassFactAudience(StrEnum):
    WHOLE_FAMILY = "whole_family"
    SELECTED_PEOPLE = "selected_people"
    SELF_ONLY = "self_only"
    REQUEST_PARTICIPANTS = "request_participants"


class CompassFactFreshness(StrEnum):
    CURRENT = "current"
    RECENT = "recent"
    SCHEDULED = "scheduled"


class CompassUncertainty(StrEnum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    NOT_APPLICABLE = "not_applicable"


class CompassActionKind(StrEnum):
    OPEN_PLAN = "open_plan"
    START_PLAN = "start_plan"
    REQUEST_CHECK_IN = "request_check_in"
    CREATE_REMINDER = "create_reminder"


class FamilyCompassArtifactKind(StrEnum):
    ANSWER = "answer"
    SUGGESTION = "suggestion"


class AIQuestionScope(StrEnum):
    GENERAL = "general"
    FAMILY_GROUNDED = "family_grounded"
    FAMILY_WITHOUT_CONTEXT = "family_without_context"


class DevicePlatform(StrEnum):
    IOS = "ios"
    ANDROID = "android"


class JourneyState(StrEnum):
    ACTIVE = "active"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class User(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    name: str = Field(min_length=1, max_length=80)
    phone_number: str = Field(min_length=7, max_length=20)
    auth_subject: str | None = Field(default=None, min_length=1, max_length=256)


class PublicUser(BaseModel):
    id: UUID
    name: str


class PhoneAccountRegistration(APIRequest):
    name: str = Field(min_length=1, max_length=80)


class Family(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    name: str = Field(min_length=1, max_length=100)
    organizer_id: UUID
    member_ids: list[UUID] = Field(default_factory=list)


class FamilyCreate(APIRequest):
    name: str = Field(min_length=1, max_length=100)


class Membership(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    family_id: UUID
    user_id: UUID
    role: FamilyRole = FamilyRole.ADULT
    can_invite: bool = False
    allow_external_ai_processing: bool = False


class MemberView(BaseModel):
    user: PublicUser
    role: FamilyRole
    can_invite: bool


class MembershipPermissionUpdate(APIRequest):
    can_invite: bool


class AIConsentUpdate(APIRequest):
    allow_external_ai_processing: bool


class Invitation(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    family_id: UUID
    invited_by: UUID
    phone_number: str
    role: FamilyRole = FamilyRole.ADULT
    state: InvitationState = InvitationState.PENDING
    created_at: datetime = Field(default_factory=utc_now)
    expires_at: datetime


class InvitationView(BaseModel):
    id: UUID
    family_id: UUID
    invited_by: UUID
    masked_phone_number: str
    role: FamilyRole
    state: InvitationState
    created_at: datetime
    expires_at: datetime


class IncomingInvitationView(InvitationView):
    family_name: str
    inviter_name: str


class Message(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    client_id: UUID
    family_id: UUID
    sender_id: UUID
    kind: MessageKind = MessageKind.TEXT
    body: str = Field(min_length=1, max_length=2000)
    mentioned_member_ids: list[UUID] = Field(default_factory=list, max_length=20)
    reference_id: UUID | None = None
    created_at: datetime = Field(default_factory=utc_now)

    @field_validator("mentioned_member_ids")
    @classmethod
    def mentioned_members_are_unique(cls, value: list[UUID]) -> list[UUID]:
        if len(set(value)) != len(value):
            raise ValueError("Mentioned family members must be unique.")
        return value


class SharedUpdate(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    family_id: UUID
    subject_user_id: UUID
    text: str = Field(min_length=1, max_length=280)
    source: SharedUpdateSource = SharedUpdateSource.MEMBER_SHARED
    updated_at: datetime = Field(default_factory=utc_now)
    expires_at: datetime
    audience: SharedUpdateAudience = SharedUpdateAudience.WHOLE_FAMILY
    selected_member_ids: list[UUID] = Field(default_factory=list)
    state: SharedUpdateState = SharedUpdateState.ACTIVE

    def is_active_at(self, now: datetime) -> bool:
        return self.state == SharedUpdateState.ACTIVE and self.expires_at > now

    def is_visible_to(self, user_id: UUID) -> bool:
        return (
            self.subject_user_id == user_id
            or self.audience == SharedUpdateAudience.WHOLE_FAMILY
            or user_id in self.selected_member_ids
        )


class CandidateTime(BaseModel):
    id: str = Field(min_length=1, max_length=80)
    starts_at: datetime
    time_zone: str = Field(default="Asia/Dubai", min_length=1, max_length=80)


class PlanResponse(BaseModel):
    member_id: UUID
    candidate_id: str
    choice: RsvpChoice
    updated_at: datetime = Field(default_factory=utc_now)


class PlanReminder(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    label: str = Field(min_length=1, max_length=160)
    at: datetime
    automatic: bool = False


class PlanContribution(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    member_id: UUID
    text: str = Field(min_length=1, max_length=160)


class Plan(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    family_id: UUID
    title: str = Field(min_length=1, max_length=120)
    location_label: str | None = Field(default=None, max_length=160)
    coordinator_id: UUID
    participant_ids: list[UUID]
    candidate_times: list[CandidateTime]
    phase: PlanPhase
    decision_deadline: datetime
    responses: dict[UUID, PlanResponse] = Field(default_factory=dict)
    confirmed_candidate_id: str | None = None
    reminders: list[PlanReminder] = Field(default_factory=list)
    contributions: list[PlanContribution] = Field(default_factory=list)
    version: int = Field(default=1, ge=1)
    created_at: datetime = Field(default_factory=utc_now)
    updated_at: datetime = Field(default_factory=utc_now)
    nudged_at: datetime | None = None
    nudge_recipient_ids: list[UUID] = Field(default_factory=list)
    nudge_dispatch_started_at: datetime | None = None
    nudge_delivered_at: datetime | None = None


class Reminder(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    family_id: UUID
    created_by: UUID
    label: str = Field(min_length=1, max_length=160)
    at: datetime
    plan_id: UUID | None = None
    completed: bool = False
    automatic: bool = False
    created_at: datetime = Field(default_factory=utc_now)
    updated_at: datetime = Field(default_factory=utc_now)


class MemberStatus(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    family_id: UUID
    subject_user_id: UUID
    summary: str = Field(min_length=1, max_length=160)
    detail: str | None = Field(default=None, max_length=280)
    updated_at: datetime = Field(default_factory=utc_now)
    expires_at: datetime
    audience: SharedUpdateAudience = SharedUpdateAudience.WHOLE_FAMILY
    selected_member_ids: list[UUID] = Field(default_factory=list)
    state: SharedUpdateState = SharedUpdateState.ACTIVE

    def is_active_at(self, now: datetime) -> bool:
        return self.state == SharedUpdateState.ACTIVE and self.expires_at > now

    def is_visible_to(self, user_id: UUID) -> bool:
        return (
            self.subject_user_id == user_id
            or self.audience == SharedUpdateAudience.WHOLE_FAMILY
            or user_id in self.selected_member_ids
        )


class Journey(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    family_id: UUID
    subject_user_id: UUID
    summary: str = Field(min_length=1, max_length=160)
    status: str = Field(min_length=1, max_length=80)
    eta: datetime | None = None
    updated_at: datetime = Field(default_factory=utc_now)
    expires_at: datetime
    audience: SharedUpdateAudience = SharedUpdateAudience.WHOLE_FAMILY
    selected_member_ids: list[UUID] = Field(default_factory=list)
    state: JourneyState = JourneyState.ACTIVE

    def is_active_at(self, now: datetime) -> bool:
        return self.state == JourneyState.ACTIVE and self.expires_at > now

    def is_visible_to(self, user_id: UUID) -> bool:
        return (
            self.subject_user_id == user_id
            or self.audience == SharedUpdateAudience.WHOLE_FAMILY
            or user_id in self.selected_member_ids
        )


class DeviceToken(BaseModel):
    """Notification destination; `token` stores the Firebase Installation ID.

    The field and endpoint retain their original names for pilot-client
    compatibility while Firebase moves targeting from registration tokens to
    FIDs.
    """

    id: UUID = Field(default_factory=uuid4)
    user_id: UUID
    token: str = Field(min_length=16, max_length=4096)
    platform: DevicePlatform
    enabled: bool = True
    created_at: datetime = Field(default_factory=utc_now)
    updated_at: datetime = Field(default_factory=utc_now)


class DeviceTokenView(BaseModel):
    id: UUID
    platform: DevicePlatform
    enabled: bool
    created_at: datetime


class FamilyEvent(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    family_id: UUID
    event_type: str = Field(min_length=1, max_length=80)
    actor_id: UUID
    resource_id: UUID
    occurred_at: datetime = Field(default_factory=utc_now)
    deep_link: str | None = Field(default=None, max_length=1000)
    data: dict[str, str | bool | int | None] = Field(default_factory=dict)


class CheckIn(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    family_id: UUID
    requester_id: UUID
    subject_user_id: UUID
    state: str = Field(default="requested", max_length=40)
    created_at: datetime = Field(default_factory=utc_now)


class FamilySuggestion(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    family_id: UUID
    title: str
    reason: str
    action_label: str


class InvitationCreate(APIRequest):
    phone_number: str = Field(min_length=7, max_length=20)
    role: FamilyRole = FamilyRole.ADULT


class MessageCreate(APIRequest):
    client_id: UUID = Field(default_factory=uuid4)
    body: str = Field(min_length=1, max_length=2000)
    mentioned_member_ids: list[UUID] = Field(default_factory=list, max_length=20)

    @field_validator("mentioned_member_ids")
    @classmethod
    def mentioned_members_are_unique(cls, value: list[UUID]) -> list[UUID]:
        if len(set(value)) != len(value):
            raise ValueError("Mentioned family members must be unique.")
        return value


class PlanCreate(APIRequest):
    client_id: UUID = Field(default_factory=uuid4)
    title: str = Field(min_length=1, max_length=120)
    location_label: str | None = Field(default=None, max_length=160)
    participant_ids: list[UUID] = Field(min_length=1)
    candidate_times: list[CandidateTime] = Field(min_length=1)
    decision_deadline: datetime
    # Existing API clients continue to create a published poll. The mobile
    # builder opts into a coordinator-only draft and publishes explicitly.
    publish: bool = True


class PlanPublish(APIRequest):
    candidate_ids: list[str] = Field(min_length=2)
    expected_version: int = Field(ge=1)


class PlanCandidateTimeAdd(APIRequest):
    candidate_time: CandidateTime
    expected_version: int = Field(ge=1)


class ReminderCreate(APIRequest):
    label: str = Field(min_length=1, max_length=160)
    at: datetime
    plan_id: UUID | None = None


class ReminderUpdate(APIRequest):
    label: str | None = Field(default=None, min_length=1, max_length=160)
    at: datetime | None = None
    completed: bool | None = None


class PlanReminderCreate(APIRequest):
    label: str = Field(min_length=1, max_length=160)
    at: datetime


class PlanContributionCreate(APIRequest):
    text: str = Field(min_length=1, max_length=160)


class PlanNudgeResult(BaseModel):
    notified_member_ids: list[UUID]


class MemberStatusUpsert(APIRequest):
    summary: str = Field(min_length=1, max_length=160)
    detail: str | None = Field(default=None, max_length=280)
    expires_at: datetime
    audience: SharedUpdateAudience
    selected_member_ids: list[UUID] = Field(default_factory=list)


class JourneyCreate(APIRequest):
    summary: str = Field(min_length=1, max_length=160)
    status: str = Field(min_length=1, max_length=80)
    eta: datetime | None = None
    expires_at: datetime
    audience: SharedUpdateAudience
    selected_member_ids: list[UUID] = Field(default_factory=list)


class JourneyStateUpdate(APIRequest):
    state: JourneyState | None = None
    audience: SharedUpdateAudience | None = None
    selected_member_ids: list[UUID] | None = None


class DeviceTokenCreate(APIRequest):
    """Compatibility payload whose `token` value is a Firebase Installation ID."""

    token: str = Field(min_length=16, max_length=4096)
    platform: DevicePlatform


class SharedUpdateCreate(APIRequest):
    text: str = Field(min_length=1, max_length=280)
    expires_at: datetime
    audience: SharedUpdateAudience = SharedUpdateAudience.WHOLE_FAMILY
    selected_member_ids: list[UUID] = Field(default_factory=list)


class SharedUpdateStateUpdate(APIRequest):
    state: SharedUpdateState | None = None
    audience: SharedUpdateAudience | None = None
    selected_member_ids: list[UUID] | None = None


class PlanResponseCreate(APIRequest):
    candidate_id: str
    choice: RsvpChoice
    expected_version: int = Field(ge=1)


class PlanConfirm(APIRequest):
    candidate_id: str
    expected_version: int = Field(ge=1)


class CheckInCreate(APIRequest):
    subject_user_id: UUID


class CompassRequest(APIRequest):
    conversation_id: UUID = Field(default_factory=uuid4)
    prompt: str = Field(min_length=1, max_length=2000)
    visibility: CompassVisibility = CompassVisibility.PRIVATE


class FamilyCompassQuestionCreate(APIRequest):
    client_id: UUID = Field(default_factory=uuid4)
    prompt: str = Field(min_length=1, max_length=2000)
    mentioned_member_ids: list[UUID] = Field(default_factory=list, max_length=20)

    @field_validator("mentioned_member_ids")
    @classmethod
    def mentioned_members_are_unique(cls, value: list[UUID]) -> list[UUID]:
        if len(set(value)) != len(value):
            raise ValueError("Mentioned family members must be unique.")
        return value


class AuthorizedFact(BaseModel):
    text: str
    source_id: UUID
    # The permitted person this fact describes, when there is one. This is a
    # backend-issued action target, not additional context for the model.
    subject_user_id: UUID | None = Field(default=None, exclude=True)
    source_type: CompassFactSource
    source_label: str
    # Chat provenance is deliberately descriptive rather than an account ID.
    # This lets Compass distinguish family members without exposing backend
    # identity fields to the model provider.
    author_label: str | None = None
    content_kind: MessageKind | None = None
    audience: CompassFactAudience
    freshness: CompassFactFreshness
    updated_at: datetime
    expires_at: datetime


class AuthorizedAIRequest(BaseModel):
    prompt: str
    visibility: CompassVisibility
    facts: list[AuthorizedFact]
    requested_subject_id: UUID | None = Field(default=None, exclude=True)
    question_scope: AIQuestionScope = AIQuestionScope.GENERAL


class CompassActionArtifact(BaseModel):
    kind: CompassActionKind
    label: str = Field(min_length=1, max_length=120)
    requires_confirmation: bool = True
    target_id: UUID | None = None

    @model_validator(mode="after")
    def consequential_actions_require_confirmation(self):
        if self.kind != CompassActionKind.OPEN_PLAN and not self.requires_confirmation:
            raise ValueError("Consequential Compass actions require confirmation.")
        return self


class AIResponse(BaseModel):
    answer: str
    provider: str
    grounded_facts: list[AuthorizedFact]
    suggested_actions: list[str]
    action_artifacts: list[CompassActionArtifact] = Field(default_factory=list)
    has_permitted_information: bool
    answer_kind: AIQuestionScope = AIQuestionScope.FAMILY_WITHOUT_CONTEXT
    audience: CompassVisibility = CompassVisibility.PRIVATE
    uncertainty: CompassUncertainty = CompassUncertainty.HIGH


class FamilyCompassArtifact(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    family_id: UUID
    request_message_id: UUID
    requested_by: UUID
    kind: FamilyCompassArtifactKind = FamilyCompassArtifactKind.ANSWER
    answer: str = Field(min_length=1, max_length=8000)
    provider: str = Field(min_length=1, max_length=120)
    grounded_facts: list[AuthorizedFact] = Field(default_factory=list)
    actions: list[CompassActionArtifact] = Field(default_factory=list)
    audience: CompassVisibility = CompassVisibility.FAMILY_ROOM
    uncertainty: CompassUncertainty
    created_at: datetime = Field(default_factory=utc_now)

    @model_validator(mode="after")
    def family_room_context_is_family_safe(self):
        if self.audience != CompassVisibility.FAMILY_ROOM:
            raise ValueError("Family Compass artifacts must be family-visible.")
        if any(
            fact.audience != CompassFactAudience.WHOLE_FAMILY
            for fact in self.grounded_facts
        ):
            raise ValueError(
                "Family Compass artifacts can cite only whole-family facts."
            )
        return self


class FamilyCompassExchange(BaseModel):
    question_message: Message
    artifact: FamilyCompassArtifact


class TodaySummary(BaseModel):
    next_plan: Plan | None
    needs_reply: list[Plan]
    shared_updates: list[SharedUpdate]
    suggestion: FamilySuggestion | None
