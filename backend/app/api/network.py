from fastapi import APIRouter, Depends

from ..core.deps import get_current_active_user
from ..models.user import User
from ..schemas.network import WANStatusResponse
from ..schemas.token import MessageResponse
from ..services.network import get_active_wan, get_ip_address

router = APIRouter(prefix="/api/network", tags=["network"])


@router.get("/status", response_model=WANStatusResponse)
async def get_network_status(current_user: User = Depends(get_current_active_user)):
    wan = get_active_wan()
    ip = get_ip_address(wan.get("active_interface")) if wan.get("active_interface") else None

    return WANStatusResponse(
        wan_mode="auto",
        active_interface=wan.get("active_interface"),
        internet=wan.get("internet", False),
        ethernet_wan=wan.get("ethernet_wan", False),
        lte_connected=wan.get("lte_connected", False),
        ip_address=ip,
        gateway=None,
    )


@router.post("/check", response_model=MessageResponse)
async def check_internet(current_user: User = Depends(get_current_active_user)):
    from ..services.network import check_connectivity

    online = check_connectivity()
    return MessageResponse(message="Internet OK" if online else "No internet connectivity")
