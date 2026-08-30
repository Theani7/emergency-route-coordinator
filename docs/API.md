# API Documentation

Base URL: `http://localhost:8000` (development)

Interactive docs: `/docs` (Swagger) and `/redoc`

## Authentication

All protected endpoints require header:

```
Authorization: Bearer <access_token>
```

### Register

```http
POST /api/v1/auth/register
Content-Type: application/json

{
  "name": "John Driver",
  "email": "john@example.com",
  "password": "SecurePass123",
  "role": "driver",
  "vehicle_number": "AMB-002"
}
```

Officers track live location dynamically (optional assigned_zone).

### Login

```http
POST /api/v1/auth/login

{
  "email": "driver@ambulance.gov",
  "password": "Driver@12345"
}
```

Response:

```json
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "user_id": 2,
  "role": "driver",
  "name": "John Driver"
}
```

## Emergency Flow (Driver)

### 1. Activate Emergency

```http
POST /api/v1/emergencies/activate
Authorization: Bearer <driver_token>

{
  "destination": "City General Hospital",
  "dest_latitude": 27.7100,
  "dest_longitude": 85.3200,
  "current_latitude": 27.7172,
  "current_longitude": 85.3240
}
```

Triggers:
- Route optimization via OSRM
- Officer notifications in nearby zones
- WebSocket broadcast to admin

### 2. Stream GPS Updates

```http
POST /api/v1/gps/update

{
  "emergency_session_id": 1,
  "latitude": 27.7160,
  "longitude": 85.3230,
  "speed_kmh": 45.5,
  "heading": 180
}
```

Send every 5-10 seconds during active emergency.

### 3. End Emergency

```http
POST /api/v1/emergencies/1/end

{ "reason": "completed" }
```

## Route Optimization

```http
POST /api/v1/routes/optimize

{
  "origin_lat": 27.7172,
  "origin_lon": 85.3240,
  "dest_lat": 27.7100,
  "dest_lon": 85.3200,
  "emergency_session_id": 1
}
```

Response includes `eta_minutes`, `congestion_score`, `polyline`, `coordinates`, `reroute_recommended`.

## WebSocket Protocol

Connect:

```
ws://localhost:8000/ws/live?token=<jwt>&channel=admin
ws://localhost:8000/ws/live?token=<jwt>&channel=driver&identifier=1
ws://localhost:8000/ws/live?token=<jwt>&channel=officer&identifier=3
```

Messages:

```json
{ "type": "connected", "channel": "admin", "message": "..." }
{ "type": "gps_update", "data": { "ambulance_id": 1, "latitude": 27.71, ... } }
{ "type": "emergency_activated", "data": { ... } }
{ "type": "emergency_ended", "data": { ... } }
{ "type": "notification_acknowledged", "data": { ... } }
```

Send `ping` for keepalive; server responds with `{ "type": "pong" }`.

## Error Responses

```json
{ "detail": "Error message" }
```

Status codes: 400, 401, 403, 404, 500, 502 (routing failure)
