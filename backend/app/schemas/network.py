from pydantic import BaseModel


class WANStatusResponse(BaseModel):
    wan_mode: str
    active_interface: str | None = None
    internet: bool
    ethernet_wan: bool
    lte_connected: bool
    ip_address: str | None = None
    gateway: str | None = None


class WANModeRequest(BaseModel):
    mode: str
