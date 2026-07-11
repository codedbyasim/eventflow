# API Reference

This document outlines the API endpoints exposed by the EventFlow FastAPI backend. All secure endpoints require a Bearer Firebase ID token passed in the `Authorization` header.

---

## 1. Authentication Header
Every secure request must include:
```http
Authorization: Bearer <Firebase_JWT_ID_Token>
```

---

## 2. Events Endpoints (`/events`)

### POST `/events`
Creates a plan and kicks off the background multi-agent pipeline.
* **Request Body**:
  ```json
  {
    "event_type": "Wedding",
    "event_date": "2026-08-10",
    "city": "islamabad",
    "guest_count": 260,
    "venue_preference": "Indoor",
    "total_budget": 300000,
    "categories": ["Caterer", "Decorator"]
  }
  ```
* **Response (201 Created)**:
  ```json
  {
    "status": "success",
    "event_id": "e550d267-e047-4780-8560-6285c34d3036",
    "firestore_id": "evt_e550d267e0474780"
  }
  ```

---

## 3. Negotiations Endpoints (`/negotiations`)

### POST `/negotiations/reply`
Allows a vendor to respond to an ongoing negotiation offer.
* **Request Body**:
  ```json
  {
    "negotiation_id": "5d609969-b1e8-4e82-a94f-99529e6c3ab4",
    "action": "counter",
    "offer_amount": 160000,
    "message": "We can offer a custom menu for 160,000 PKR."
  }
  ```
  *Note: `action` can be `"accept"`, `"counter"`, or `"reject"`.*
* **Response (200 OK)**:
  ```json
  {
    "status": "ok",
    "message": "Reply processed successfully."
  }
  ```

---

## 4. Bookings Endpoints (`/bookings`)

### POST `/bookings/confirm`
Locks the final package of deals, updating Postgres and creating client receipt records.
* **Request Body**:
  ```json
  {
    "event_id": "e550d267-e047-4780-8560-6285c34d3036"
  }
  ```
* **Response (200 OK)**:
  ```json
  {
    "status": "ok",
    "message": "Booking confirmed for all vendors in the package."
  }
  ```

---

## 5. Users Endpoints (`/users`)

### POST `/users/onboard-vendor`
Saves or updates a vendor profile, claiming matched PostgreSQL seeded records and linking Firebase Auth.
* **Request Body**:
  ```json
  {
    "business_name": "Twin City Caterers",
    "category": "Caterer",
    "city": "islamabad",
    "base_price": 200000,
    "min_price": 140000
  }
  ```
* **Response (200 OK)**:
  ```json
  {
    "status": "ok",
    "vendor_id": "2cde1ff1-2df9-4b03-89be-087f60d5f91e"
  }
  ```

### POST `/users/fcm-token`
Updates the FCM registration token for a customer or vendor.
* **Request Body**:
  ```json
  {
    "fcm_token": "fcm-registration-token-string"
  }
  ```
* **Response (200 OK)**:
  ```json
  {
    "status": "ok",
    "message": "FCM token updated successfully."
  }
  ```
