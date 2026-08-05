from collections.abc import Callable
from uuid import UUID

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware

from .ai_service import AIProvider, MockAIProvider
from .models import (
    AIRequest,
    AIResponse,
    CheckIn,
    CheckInCreate,
    Family,
    FamilySuggestion,
    Invitation,
    InvitationCreate,
    Journey,
    MemberStatus,
    Message,
    MessageCreate,
    Permission,
    PermissionUpdate,
    Reminder,
    ReminderCreate,
    User,
)
from .seed import seeded_store
from .store import Store


def create_app(store_factory: Callable[[], Store] = seeded_store, ai_provider: AIProvider | None = None) -> FastAPI:
    app = FastAPI(title="Family Compass API", version="0.1.0")
    app.state.store = store_factory()
    app.state.ai = ai_provider or MockAIProvider()
    app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"], allow_credentials=False)

    def store(request: Request) -> Store:
        return request.app.state.store

    def ai(request: Request) -> AIProvider:
        return request.app.state.ai

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/api/v1/users", response_model=list[User])
    async def users(repo: Store = Depends(store)) -> list[User]:
        return repo.users.all()

    @app.get("/api/v1/families/{family_id}", response_model=Family)
    async def family(family_id: UUID, repo: Store = Depends(store)) -> Family:
        value = repo.families.get(family_id)
        if not value:
            raise HTTPException(404, "Family not found")
        return value

    @app.get("/api/v1/families/{family_id}/members", response_model=list[User])
    async def family_members(family_id: UUID, repo: Store = Depends(store)) -> list[User]:
        value = repo.families.get(family_id)
        if not value:
            raise HTTPException(404, "Family not found")
        return [member for member_id in value.member_ids if (member := repo.users.get(member_id))]

    @app.post("/api/v1/invitations", response_model=Invitation, status_code=status.HTTP_201_CREATED)
    async def invite(payload: InvitationCreate, repo: Store = Depends(store)) -> Invitation:
        return repo.invitations.save(Invitation(**payload.model_dump()))

    @app.get("/api/v1/messages", response_model=list[Message])
    async def messages(family_id: UUID, repo: Store = Depends(store)) -> list[Message]:
        return [value for value in repo.messages.all() if value.family_id == family_id]

    @app.post("/api/v1/messages", response_model=Message, status_code=status.HTTP_201_CREATED)
    async def post_message(payload: MessageCreate, repo: Store = Depends(store)) -> Message:
        return repo.messages.save(Message(**payload.model_dump()))

    @app.get("/api/v1/statuses", response_model=list[MemberStatus])
    async def statuses(family_id: UUID, repo: Store = Depends(store)) -> list[MemberStatus]:
        family = repo.families.get(family_id)
        if not family:
            raise HTTPException(404, "Family not found")
        return [value for member_id in family.member_ids if (value := repo.statuses.get(member_id))]

    @app.get("/api/v1/journeys", response_model=list[Journey])
    async def journeys(family_id: UUID, repo: Store = Depends(store)) -> list[Journey]:
        return [value for value in repo.journeys.all() if value.family_id == family_id]

    @app.get("/api/v1/reminders", response_model=list[Reminder])
    async def reminders(family_id: UUID, repo: Store = Depends(store)) -> list[Reminder]:
        return [value for value in repo.reminders.all() if value.family_id == family_id]

    @app.post("/api/v1/reminders", response_model=Reminder, status_code=status.HTTP_201_CREATED)
    async def create_reminder(payload: ReminderCreate, repo: Store = Depends(store)) -> Reminder:
        return repo.reminders.save(Reminder(**payload.model_dump()))

    @app.post("/api/v1/check-ins", response_model=CheckIn, status_code=status.HTTP_201_CREATED)
    async def check_in(payload: CheckInCreate, repo: Store = Depends(store)) -> CheckIn:
        return repo.check_ins.save(CheckIn(**payload.model_dump()))

    @app.get("/api/v1/permissions", response_model=list[Permission])
    async def permissions(family_id: UUID, repo: Store = Depends(store)) -> list[Permission]:
        return [value for value in repo.permissions.all() if value.family_id == family_id]

    @app.patch("/api/v1/permissions/{user_id}", response_model=Permission)
    async def update_permission(user_id: UUID, payload: PermissionUpdate, repo: Store = Depends(store)) -> Permission:
        value = repo.permissions.get(user_id)
        if not value:
            raise HTTPException(404, "Permission not found")
        return repo.permissions.save(value.model_copy(update=payload.model_dump(exclude_none=True)))

    @app.get("/api/v1/suggestions", response_model=list[FamilySuggestion])
    async def suggestions(family_id: UUID) -> list[FamilySuggestion]:
        return [FamilySuggestion(family_id=family_id, title="Plan family time", reason="Everyone is free Friday after 7:00 PM", options=["Family dinner", "Movie night", "Evening walk"])]

    @app.post("/api/v1/ai/assistant", response_model=AIResponse)
    async def assistant(payload: AIRequest, provider: AIProvider = Depends(ai)) -> AIResponse:
        return await provider.answer(payload)

    return app


app = create_app()
