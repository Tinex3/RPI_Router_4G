import pytest


@pytest.mark.anyio
async def test_health_check(client):
    response = await client.get("/api/system/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["services"]["database"] == "ok"


@pytest.mark.anyio
async def test_login_success(client):
    response = await client.post(
        "/api/auth/login",
        json={"username": "admin", "password": "admin1234"},
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"


@pytest.mark.anyio
async def test_login_wrong_password(client):
    response = await client.post(
        "/api/auth/login",
        json={"username": "admin", "password": "wrong"},
    )
    assert response.status_code == 401


@pytest.mark.anyio
async def test_get_me_authenticated(client):
    login_resp = await client.post(
        "/api/auth/login",
        json={"username": "admin", "password": "admin1234"},
    )
    token = login_resp.json()["access_token"]

    response = await client.get(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["username"] == "admin"
    assert data["role"] == "admin"


@pytest.mark.anyio
async def test_get_me_unauthenticated(client):
    response = await client.get("/api/auth/me")
    assert response.status_code == 401


@pytest.mark.anyio
async def test_system_info_authenticated(client):
    login_resp = await client.post(
        "/api/auth/login",
        json={"username": "admin", "password": "admin1234"},
    )
    token = login_resp.json()["access_token"]

    response = await client.get(
        "/api/system/info",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert "hostname" in data
    assert "uptime" in data
    assert "app_version" in data


@pytest.mark.anyio
async def test_list_users_admin(client):
    login_resp = await client.post(
        "/api/auth/login",
        json={"username": "admin", "password": "admin1234"},
    )
    token = login_resp.json()["access_token"]

    response = await client.get(
        "/api/auth/users",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["total"] >= 1


@pytest.mark.anyio
async def test_create_user_admin(client):
    login_resp = await client.post(
        "/api/auth/login",
        json={"username": "admin", "password": "admin1234"},
    )
    token = login_resp.json()["access_token"]

    response = await client.post(
        "/api/auth/users",
        json={"username": "testuser", "password": "test1234", "role": "user"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["username"] == "testuser"
    assert data["role"] == "user"


@pytest.mark.anyio
async def test_refresh_token(client):
    login_resp = await client.post(
        "/api/auth/login",
        json={"username": "admin", "password": "admin1234"},
    )
    refresh_token = login_resp.json()["refresh_token"]

    response = await client.post(
        "/api/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data


@pytest.mark.anyio
async def test_delete_cannot_self(client):
    login_resp = await client.post(
        "/api/auth/login",
        json={"username": "admin", "password": "admin1234"},
    )
    token = login_resp.json()["access_token"]

    response = await client.delete(
        "/api/auth/users/1",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 400
