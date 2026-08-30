# Admin Account Confirmation and Approval Workflow Specification

**Date:** 2026-08-30  
**Status:** Approved by User  
**Topic:** Registration Request & Admin Approval Workflow  

---

## 1. Overview
When a new Driver or Traffic Officer registers via the mobile application, their account is placed into a `PENDING` approval state. They cannot access system resources or log in until a System Administrator reviews and confirms their registration in the Web Dashboard.

---

## 2. Architecture & Components

### 2.1 Database & Data Model
- **`UserApprovalStatus` Enum**:
  - `PENDING`: Initial state for self-registered drivers and traffic officers.
  - `APPROVED`: Active accounts with full access. Initial state for admin-created users and existing seed accounts.
  - `REJECTED`: Declined registrations.
- **`User` Model Additions** (`backend/app/models/user.py`):
  - `approval_status: Mapped[UserApprovalStatus] = mapped_column(Enum(UserApprovalStatus, native_enum=False), default=UserApprovalStatus.APPROVED, server_default='approved', nullable=False)`
  - `approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, default=None)`
  - `approved_by: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True, default=None)`
- **Alembic Migration**:
  - Migration file `012_add_user_approval_status.py` adding `approval_status`, `approved_at`, and `approved_by` to the `users` table with default value `'approved'` for existing rows.

---

### 2.2 Backend API Endpoints

#### 1. Registration (`POST /api/v1/auth/register`)
- Self-registration for `DRIVER` and `OFFICER` sets `approval_status = UserApprovalStatus.PENDING`.
- Consumes OTP after verification.
- Returns `UserResponse` with `approval_status="pending"`.
- Does not issue access tokens directly to pending users.

#### 2. Authentication / Login (`POST /api/v1/auth/login`)
- Validates email/password credentials.
- If credentials are valid:
  - If `user.approval_status == UserApprovalStatus.PENDING`: Raises `HTTP 403 Forbidden` with detail `"Your account is pending administrator approval."`
  - If `user.approval_status == UserApprovalStatus.REJECTED`: Raises `HTTP 403 Forbidden` with detail `"Your registration request was rejected by an administrator."`
  - If `user.approval_status == UserApprovalStatus.APPROVED`: Returns standard `TokenResponse` with JWT bearer token.

#### 3. User Listing & Approval Endpoints (`backend/app/api/v1/users.py`)
- `GET /api/v1/users/`: Accepts optional query parameter `?approval_status=pending` to filter pending applications.
- `POST /api/v1/users/{user_id}/approve`:
  - Requires Admin role.
  - Updates `user.approval_status = UserApprovalStatus.APPROVED`, sets `user.approved_at = now(utc)`, and sets `user.approved_by = current_user.id`.
  - Returns updated `UserResponse`.
- `POST /api/v1/users/{user_id}/reject`:
  - Requires Admin role.
  - Updates `user.approval_status = UserApprovalStatus.REJECTED`.
  - Returns updated `UserResponse`.

---

### 2.3 Web Dashboard (Admin Portal)

- **File**: `dashboard/src/pages/UsersPage.tsx`
- **Tabs Navigation**:
  - Tab 1: **All Users** (Full directory)
  - Tab 2: **Pending Approvals (`badge count`)**
- **Pending Approvals UI**:
  - Displays pending registrations with:
    - Applicant Full Name & Email
    - Target Role (Driver / Officer)
    - Vehicle Number (for drivers)
    - Registration Date & Time
    - **Action Buttons**:
      - `Approve` button (Green, calls `/api/v1/users/{id}/approve`)
      - `Reject` button (Red, calls `/api/v1/users/{id}/reject`)
- **Directory Status Column**:
  - Main users table displays status badges: `Approved` (green), `Pending` (amber/yellow), `Rejected` (red).

---

### 2.4 Mobile Application (Driver & Officer)

- **Registration Pending Screen** (`mobile/lib/screens/registration_pending_screen.dart`):
  - Presented immediately after OTP verification on `SignupOtpScreen`.
  - Premium single-color background matching theme.
  - Verification hourglass / clock emblem.
  - Clear message: *"Registration Submitted - Your account has been submitted and is currently pending administrator confirmation. You will be able to log in once approved."*
  - Action buttons:
    - "Back to Login"
    - "Check Status" (attempts quick check or directs to login)
- **Login Screen Handling** (`mobile/lib/screens/login_screen.dart`):
  - Intercepts `403` responses containing `"pending administrator approval"`.
  - Displays an informative amber banner / navigates to `RegistrationPendingScreen` with explicit guidance.

---

## 3. Testing & Verification Plan

1. **Backend Unit & Integration Tests** (`backend/tests/test_auth_security.py`):
   - Test driver/officer registration yields `approval_status == 'pending'`.
   - Test pending user cannot login (`403 Forbidden`).
   - Test admin approving user (`POST /api/v1/users/{id}/approve`) changes status to `'approved'`.
   - Test approved user can now successfully log in and receive token.
   - Test admin rejecting user (`POST /api/v1/users/{id}/reject`) keeps login blocked with rejected message.
2. **Mobile App Widget & Flow Tests**:
   - Verify `SignupOtpScreen` navigates to `RegistrationPendingScreen` on successful registration.
   - Verify `RegistrationPendingScreen` renders message and action buttons.
3. **End-to-End Verification**:
   - Run all backend pytest tests.
   - Run all mobile flutter tests.
