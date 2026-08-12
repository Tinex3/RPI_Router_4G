from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api import auth, lte, network, system
from .config import settings
from .core.logging_config import setup_logging
from .database import init_db
from .services.ec25_monitor import start_monitor, stop_monitor


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    setup_logging()
    await init_db()
    await _seed_admin()
    if settings.EC25_ENABLED:
        start_monitor(update_interval=settings.EC25_UPDATE_INTERVAL, enabled=settings.EC25_ENABLED)
    yield
    stop_monitor()


async def _seed_admin() -> None:
    from sqlalchemy import select

    from .core.security import hash_password
    from .database import async_session
    from .models.user import User

    async with async_session() as session:
        result = await session.execute(select(User).where(User.username == "admin"))
        if result.scalar_one_or_none() is None:
            admin = User(
                username="admin",
                hashed_password=hash_password("admin1234"),
                role="admin",
            )
            session.add(admin)
            await session.commit()


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.APP_NAME,
        version=settings.APP_VERSION,
        docs_url="/docs" if settings.DEBUG else None,
        redoc_url="/redoc" if settings.DEBUG else None,
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(auth.router)
    app.include_router(lte.router)
    app.include_router(network.router)
    app.include_router(system.router)

    return app


app = create_app()
