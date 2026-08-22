from datetime import timedelta
from uuid import UUID

from .models import (
    CandidateTime,
    Family,
    FamilyRole,
    Membership,
    Message,
    MessageKind,
    Plan,
    PlanPhase,
    PlanResponse,
    RsvpChoice,
    SharedUpdate,
    User,
    utc_now,
)
from .store import Store, StoreProtocol

FAMILY_ID = UUID("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
OTHER_FAMILY_ID = UUID("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
ABDULLAH_ID = UUID("11111111-1111-1111-1111-111111111111")
DAD_ID = UUID("22222222-2222-2222-2222-222222222222")
MOM_ID = UUID("33333333-3333-3333-3333-333333333333")
OUTSIDER_ID = UUID("44444444-4444-4444-4444-444444444444")
DINNER_PLAN_ID = UUID("55555555-5555-5555-5555-555555555555")
ABDULLAH_MEMBERSHIP_ID = UUID("77777777-7777-7777-7777-777777777771")
DAD_MEMBERSHIP_ID = UUID("77777777-7777-7777-7777-777777777772")
MOM_MEMBERSHIP_ID = UUID("77777777-7777-7777-7777-777777777773")
OUTSIDER_MEMBERSHIP_ID = UUID("77777777-7777-7777-7777-777777777774")
DAD_UPDATE_ID = UUID("88888888-8888-8888-8888-888888888888")
MOM_MESSAGE_ID = UUID("99999999-9999-9999-9999-999999999991")
DAD_MESSAGE_ID = UUID("99999999-9999-9999-9999-999999999992")


def seeded_store() -> Store:
    store = Store()
    seed_store(store)
    return store


def seed_store(store: StoreProtocol) -> StoreProtocol:
    """Populate a completely empty store with deterministic prototype data."""

    if store.users.all():
        return store
    now = utc_now()
    days_until_friday = (4 - now.weekday()) % 7 or 7
    friday = (now + timedelta(days=days_until_friday)).replace(
        hour=19, minute=0, second=0, microsecond=0
    )
    saturday = friday + timedelta(days=1)

    users = [
        User(
            id=ABDULLAH_ID,
            name="Abdullah",
            phone_number="+12025550101",
            auth_subject=str(ABDULLAH_ID),
        ),
        User(
            id=DAD_ID,
            name="Dad",
            phone_number="+12025550102",
            auth_subject=str(DAD_ID),
        ),
        User(
            id=MOM_ID,
            name="Mom",
            phone_number="+12025550103",
            auth_subject=str(MOM_ID),
        ),
        User(
            id=OUTSIDER_ID,
            name="Noura",
            phone_number="+12025550104",
            auth_subject=str(OUTSIDER_ID),
        ),
    ]
    for user in users:
        store.users.save(user)

    store.families.save(
        Family(
            id=FAMILY_ID,
            name="Hamadeh family",
            organizer_id=DAD_ID,
            member_ids=[ABDULLAH_ID, DAD_ID, MOM_ID],
        )
    )
    store.families.save(
        Family(
            id=OTHER_FAMILY_ID,
            name="Noura's family",
            organizer_id=OUTSIDER_ID,
            member_ids=[OUTSIDER_ID],
        )
    )

    memberships = [
        Membership(
            id=DAD_MEMBERSHIP_ID,
            family_id=FAMILY_ID,
            user_id=DAD_ID,
            role=FamilyRole.ORGANIZER,
            can_invite=True,
            allow_external_ai_processing=True,
        ),
        Membership(
            id=MOM_MEMBERSHIP_ID,
            family_id=FAMILY_ID,
            user_id=MOM_ID,
            role=FamilyRole.ADULT,
            can_invite=True,
            allow_external_ai_processing=True,
        ),
        Membership(
            id=ABDULLAH_MEMBERSHIP_ID,
            family_id=FAMILY_ID,
            user_id=ABDULLAH_ID,
            role=FamilyRole.ADULT,
            can_invite=False,
            allow_external_ai_processing=False,
        ),
        Membership(
            id=OUTSIDER_MEMBERSHIP_ID,
            family_id=OTHER_FAMILY_ID,
            user_id=OUTSIDER_ID,
            role=FamilyRole.ORGANIZER,
            can_invite=True,
            allow_external_ai_processing=False,
        ),
    ]
    for membership in memberships:
        store.memberships.save(membership)

    store.shared_updates.save(
        SharedUpdate(
            id=DAD_UPDATE_ID,
            family_id=FAMILY_ID,
            subject_user_id=DAD_ID,
            text="On the way to work. Expected by 8:35 AM.",
            updated_at=now - timedelta(minutes=8),
            expires_at=now + timedelta(hours=3),
        )
    )

    messages = [
        Message(
            id=MOM_MESSAGE_ID,
            client_id=UUID("66666666-6666-6666-6666-666666666661"),
            family_id=FAMILY_ID,
            sender_id=MOM_ID,
            body="Would Friday dinner work for everyone?",
        ),
        Message(
            id=DAD_MESSAGE_ID,
            client_id=UUID("66666666-6666-6666-6666-666666666662"),
            family_id=FAMILY_ID,
            sender_id=DAD_ID,
            kind=MessageKind.PLAN,
            body="I can make 7:00 PM.",
            reference_id=DINNER_PLAN_ID,
        ),
    ]
    for message in messages:
        store.messages.save(message)

    store.plans.save(
        Plan(
            id=DINNER_PLAN_ID,
            family_id=FAMILY_ID,
            title="Family dinner",
            location_label="Home",
            coordinator_id=DAD_ID,
            participant_ids=[ABDULLAH_ID, DAD_ID, MOM_ID],
            candidate_times=[
                CandidateTime(id="fri-1900", starts_at=friday),
                CandidateTime(id="sat-1900", starts_at=saturday),
            ],
            phase=PlanPhase.POLL_OPEN,
            decision_deadline=friday - timedelta(hours=2),
            responses={
                DAD_ID: PlanResponse(
                    member_id=DAD_ID,
                    candidate_id="fri-1900",
                    choice=RsvpChoice.GOING,
                ),
                MOM_ID: PlanResponse(
                    member_id=MOM_ID,
                    candidate_id="fri-1900",
                    choice=RsvpChoice.GOING,
                ),
            },
        )
    )
    return store
