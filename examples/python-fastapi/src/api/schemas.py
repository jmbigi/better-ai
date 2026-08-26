"""Pydantic schemas for API request/response models."""

from pydantic import BaseModel, Field
from typing import Annotated


class CalculatorRequest(BaseModel):
    """Request model for calculator operations."""

    a: Annotated[float, Field(..., description="First operand")]
    b: Annotated[float, Field(..., description="Second operand")]
    operation: Annotated[str, Field(..., pattern="^(add|subtract|multiply|divide)$")]


class CalculatorResponse(BaseModel):
    """Response model for calculator operations."""

    result: float
    operation: str
    a: float
    b: float


class HealthResponse(BaseModel):
    """Health check response."""

    status: str = "ok"
    service: str