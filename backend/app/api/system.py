from fastapi import APIRouter, Depends

from ..core.deps import get_current_active_user
from ..models.user import User
from ..schemas.system import HealthResponse, SystemInfoResponse
from ..schemas.token import MessageResponse
from ..services.system import get_system_info

router = APIRouter(prefix="/api/system", tags=["system"])


@router.get("/info", response_model=SystemInfoResponse)
async def system_info(current_user: User = Depends(get_current_active_user)):
    from ..config import settings

    info = get_system_info()
    info["app_version"] = settings.APP_VERSION
    return info


@router.get("/health", response_model=HealthResponse)
async def health_check():
    return HealthResponse(
        status="healthy",
        services={
            "database": "ok",
            "api": "ok",
        },
    )


@router.post("/reboot", response_model=MessageResponse)
async def reboot(current_user: User = Depends(get_current_active_user)):
    import asyncio

    async def do_reboot():
        await asyncio.sleep(1)
        import subprocess
        subprocess.run(["sudo", "reboot"], check=False)

    import asyncio
    asyncio.create_task(do_reboot())

    return MessageResponse(message="System is restarting")
