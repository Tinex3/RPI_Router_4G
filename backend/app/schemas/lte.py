from pydantic import BaseModel, Field


class LTESignalResponse(BaseModel):
    csq: str
    csq_raw: str | None = None
    qcsq: str
    qcsq_raw: str | None = None


class LTENetworkResponse(BaseModel):
    operator: str
    network: str
    registration: str
    sim: str


class LTEStatusResponse(BaseModel):
    enabled: bool
    detected: bool
    timestamp: float
    signal: LTESignalResponse
    network: LTENetworkResponse


class APNRequest(BaseModel):
    apn: str = Field(min_length=1, max_length=128)
    ip_type: str = Field(default="IPV4V6", pattern="^(IP|IPV6|IPV4V6)$")


class ModemCommandRequest(BaseModel):
    command: str = Field(min_length=1, max_length=256)
