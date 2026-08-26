"""API routes for the calculator service."""

from fastapi import APIRouter, HTTPException, status

from src.api.schemas import CalculatorRequest, CalculatorResponse, HealthResponse
from src.services.calculator import calculate, CalculatorError, DivisionByZeroError, InvalidOperationError

router = APIRouter()


@router.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint."""
    return HealthResponse(service="FastAPI Example")


@router.post("/calculate", response_model=CalculatorResponse)
async def calculate_endpoint(request: CalculatorRequest):
    """
    Perform a calculation operation.

    Supports: add, subtract, multiply, divide
    """
    try:
        result = calculate(request.a, request.b, request.operation)
        return CalculatorResponse(
            result=result,
            operation=request.operation,
            a=request.a,
            b=request.b,
        )
    except DivisionByZeroError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except InvalidOperationError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except CalculatorError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Calculation error: {e.message}",
        )