"""Tests for API endpoints."""

import pytest
from httpx import AsyncClient

from src.main import app


@pytest.fixture
async def client():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac


class TestHealthEndpoint:
    """Tests for health check endpoint."""

    async def test_health_check(self, client: AsyncClient):
        response = await client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert "service" in data


class TestCalculateEndpoint:
    """Tests for calculate endpoint."""

    async def test_add(self, client: AsyncClient):
        response = await client.post(
            "/api/v1/calculate",
            json={"a": 10, "b": 5, "operation": "add"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["result"] == 15
        assert data["operation"] == "add"

    async def test_subtract(self, client: AsyncClient):
        response = await client.post(
            "/api/v1/calculate",
            json={"a": 10, "b": 5, "operation": "subtract"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["result"] == 5

    async def test_multiply(self, client: AsyncClient):
        response = await client.post(
            "/api/v1/calculate",
            json={"a": 10, "b": 5, "operation": "multiply"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["result"] == 50

    async def test_divide(self, client: AsyncClient):
        response = await client.post(
            "/api/v1/calculate",
            json={"a": 10, "b": 5, "operation": "divide"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["result"] == 2

    async def test_divide_by_zero(self, client: AsyncClient):
        response = await client.post(
            "/api/v1/calculate",
            json={"a": 10, "b": 0, "operation": "divide"},
        )
        assert response.status_code == 400
        assert "Cannot divide by zero" in response.json()["detail"]

    async def test_invalid_operation(self, client: AsyncClient):
        response = await client.post(
            "/api/v1/calculate",
            json={"a": 10, "b": 5, "operation": "modulo"},
        )
        assert response.status_code == 400
        assert "Invalid operation" in response.json()["detail"]

    async def test_invalid_schema(self, client: AsyncClient):
        response = await client.post(
            "/api/v1/calculate",
            json={"a": 10},  # missing b and operation
        )
        assert response.status_code == 422  # Validation error