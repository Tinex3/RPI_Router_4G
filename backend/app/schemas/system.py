from pydantic import BaseModel


class SystemInfoResponse(BaseModel):
    hostname: str
    uptime: str
    cpu_usage: float
    ram_usage: float
    ram_total: float
    temperature: float | None = None
    storage_used: float
    storage_total: float
    app_version: str


class HealthResponse(BaseModel):
    status: str
    services: dict[str, str]


class RebootResponse(BaseModel):
    message: str
    restarting: bool = True
