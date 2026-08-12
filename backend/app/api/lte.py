from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse

from ..core.deps import get_current_active_user
from ..models.user import User
from ..schemas.lte import APNRequest, LTEStatusResponse, ModemCommandRequest
from ..schemas.token import MessageResponse
from ..services.ec25_monitor import get_latest_data
from ..services.modem import reset_modem, send_at, set_apn

router = APIRouter(prefix="/api/lte", tags=["lte"])


@router.get("/status", response_model=LTEStatusResponse)
async def get_lte_status(current_user: User = Depends(get_current_active_user)):
    return get_latest_data()


@router.get("/stream")
async def stream_lte(current_user: User = Depends(get_current_active_user)):
    import asyncio
    import json

    from ..services.ec25_monitor import ec25_data_queue

    async def event_generator():
        while True:
            try:
                data = await asyncio.to_thread(ec25_data_queue.get, timeout=10)
                yield f"data: {json.dumps(data, default=str)}\n\n"
            except Exception:
                yield ": keepalive\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@router.post("/apn", response_model=MessageResponse)
async def configure_apn(
    request: APNRequest,
    current_user: User = Depends(get_current_active_user),
):
    result = set_apn(request.apn)
    if result and "OK" in result:
        return MessageResponse(message=f"APN configured: {request.apn}")
    return MessageResponse(message=f"Failed to configure APN. Response: {result}")


@router.post("/reset", response_model=MessageResponse)
async def reset_modem_endpoint(current_user: User = Depends(get_current_active_user)):
    result = reset_modem()
    if result:
        return MessageResponse(message="Modem reset command sent")
    return MessageResponse(message="Failed to send reset command")


@router.post("/command", response_model=MessageResponse)
async def send_at_command(
    request: ModemCommandRequest,
    current_user: User = Depends(get_current_active_user),
):
    if not request.command.upper().startswith("AT"):
        request.command = f"AT{request.command}"
    result = send_at(request.command)
    return MessageResponse(message=f"Response: {result}" if result else "No response")
