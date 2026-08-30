# Admin Account Confirmation and Approval Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement an admin confirmation workflow where self-registered Drivers and Traffic Officers start in a `PENDING` approval state, preventing access until an Administrator confirms/approves their account via the Web Dashboard.

**Architecture:** Extend the `User` model with `approval_status` (`PENDING`, `APPROVED`, `REJECTED`), `approved_at`, and `approved_by`. Guard the login endpoint to reject unapproved accounts with `403 Forbidden`. Add admin endpoints `/api/v1/users/{id}/approve` and `/api/v1/users/{id}/reject`. Build a "Pending Approvals" tab in the React Dashboard and a dedicated `RegistrationPendingScreen` in Flutter.

**Tech Stack:** FastAPI, SQLAlchemy 2.0 (asyncpg), Alembic, React / TypeScript / Tailwind CSS / Tabler Icons, Flutter / Dart / Provider.

## Global Constraints
- Commit and push after each task using conventional commits.
- Follow existing codebase patterns and design language.
- Preserve backward compatibility for existing users and automated test suites.

---

### Task 1: Database Model & Alembic Migration for Approval Status

**Files:**
- Modify: `backend/app/models/user.py`
- Modify: `backend/app/schemas/auth.py`
- Modify: `backend/app/schemas/profile.py`
- Create: `backend/alembic/versions/012_add_user_approval_status.py`

**Interfaces:**
- Produces: `UserApprovalStatus` enum (`pending`, `approved`, `rejected`), `User.approval_status`, `User.approved_at`, `User.approved_by`.
- Produces: `UserResponse.approval_status`, `ProfileResponse.approval_status`.

- [ ] **Step 1: Update `User` model and schemas**

```python
# backend/app/models/user.py
class UserApprovalStatus(str, enum.Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"

# In User model:
approval_status: Mapped[UserApprovalStatus] = mapped_column(
    Enum(
        UserApprovalStatus,
        name="user_approval_status",
        values_callable=lambda x: [e.value for e in x],
        native_enum=False,
    ),
    default=UserApprovalStatus.APPROVED,
    server_default="approved",
    nullable=False,
    index=True,
)
approved_at: Mapped[datetime | None] = mapped_column(
    DateTime(timezone=True), nullable=True, default=None
)
approved_by: Mapped[int | None] = mapped_column(
    Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, default=None
)
```

- [ ] **Step 2: Create and run Alembic migration `012_add_user_approval_status.py`**

```python
# backend/alembic/versions/012_add_user_approval_status.py
revision: str = "012_add_user_approval_status"
down_revision: Union[str, None] = "011_make_assigned_zone_nullable"
# op.add_column users approval_status, approved_at, approved_by
```

Run: `./venv/bin/alembic upgrade head`
Expected: `Running upgrade 011_make_assigned_zone_nullable -> 012_add_user_approval_status`

- [ ] **Step 3: Commit and Push**

```bash
git add backend/app/models/user.py backend/app/schemas/auth.py backend/app/schemas/profile.py backend/alembic/versions/012_add_user_approval_status.py
git commit -m "feat(models): add approval_status and audit columns to User model"
git push origin main
```

---

### Task 2: Backend Auth Registration & Login Guard

**Files:**
- Modify: `backend/app/api/v1/auth.py`
- Test: `backend/tests/test_auth_security.py`

**Interfaces:**
- Consumes: `UserApprovalStatus`, `User.approval_status`.
- Produces: `POST /api/v1/auth/register` (defaults to `PENDING` for drivers/officers), `POST /api/v1/auth/login` (blocks pending/rejected users with 403).

- [ ] **Step 1: Write the failing tests in `test_auth_security.py`**

```python
async def test_pending_driver_registration_blocks_login_until_approved():
    # test registering driver receives approval_status == "pending"
    # test login returns 403 Forbidden "Your account is pending administrator approval."
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./venv/bin/pytest tests/test_auth_security.py -k test_pending_driver_registration_blocks_login_until_approved -v`
Expected: FAIL

- [ ] **Step 3: Implement registration and login guard in `auth.py`**

```python
# In register:
user = User(
    name=payload.name,
    email=clean_email,
    password_hash=await hash_password(payload.password),
    role=payload.role,
    approval_status=UserApprovalStatus.PENDING if payload.role != UserRole.ADMIN else UserApprovalStatus.APPROVED,
)

# In login:
if user.approval_status == UserApprovalStatus.PENDING:
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Your account is pending administrator approval.",
    )
if user.approval_status == UserApprovalStatus.REJECTED:
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Your registration request was rejected by an administrator.",
    )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./venv/bin/pytest tests/test_auth_security.py -k test_pending_driver_registration_blocks_login_until_approved -v`
Expected: PASS

- [ ] **Step 5: Commit and Push**

```bash
git add backend/app/api/v1/auth.py backend/tests/test_auth_security.py
git commit -m "feat(auth): enforce pending approval on registration and guard login"
git push origin main
```

---

### Task 3: Backend Admin Approval & Listing Endpoints

**Files:**
- Modify: `backend/app/api/v1/users.py`
- Test: `backend/tests/test_admin_approvals.py`

**Interfaces:**
- Produces: `POST /api/v1/users/{user_id}/approve`
- Produces: `POST /api/v1/users/{user_id}/reject`
- Produces: `GET /api/v1/users/?approval_status=pending`

- [ ] **Step 1: Write integration tests in `test_admin_approvals.py`**

```python
async def test_admin_approve_and_reject_user_flow():
    # Register pending driver
    # Admin approves user -> status becomes approved
    # Approved driver logs in successfully
    # Admin rejects user -> status becomes rejected, login returns 403
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./venv/bin/pytest tests/test_admin_approvals.py -v`
Expected: FAIL with 404 / 405 on approve endpoint

- [ ] **Step 3: Implement approve, reject, and status filter in `users.py`**

```python
@router.post("/{user_id}/approve", response_model=UserResponse)
async def approve_user(user_id: int, current_user: RequireAdmin, db: AsyncSession = Depends(get_db)):
    ...

@router.post("/{user_id}/reject", response_model=UserResponse)
async def reject_user(user_id: int, current_user: RequireAdmin, db: AsyncSession = Depends(get_db)):
    ...
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./venv/bin/pytest tests/test_admin_approvals.py -v`
Expected: PASS

- [ ] **Step 5: Commit and Push**

```bash
git add backend/app/api/v1/users.py backend/tests/test_admin_approvals.py
git commit -m "feat(users): add admin approve, reject, and pending status filter endpoints"
git push origin main
```

---

### Task 4: Dashboard UI for Pending Approvals

**Files:**
- Modify: `dashboard/src/services/api.ts`
- Modify: `dashboard/src/pages/UsersPage.tsx`

**Interfaces:**
- Consumes: `usersApi.list()`, `usersApi.approve(id)`, `usersApi.reject(id)`.
- Produces: User directory tab bar (`All Users` / `Pending Approvals`), approval/rejection action buttons, status pills.

- [ ] **Step 1: Add approve & reject methods to `usersApi` in `dashboard/src/services/api.ts`**

```typescript
export const usersApi = {
  ...
  approve: (id: number) => api.post(`/users/${id}/approve`),
  reject: (id: number) => api.post(`/users/${id}/reject`),
};
```

- [ ] **Step 2: Update `dashboard/src/pages/UsersPage.tsx` with Tabs and Approval Actions**
  - Add active tab state: `'all' | 'pending'`.
  - Calculate pending count badge.
  - Render pending requests list with applicant details and Approve/Reject buttons.
  - Render status pills on user list items.

- [ ] **Step 3: Commit and Push**

```bash
git add dashboard/src/services/api.ts dashboard/src/pages/UsersPage.tsx
git commit -m "feat(dashboard): add pending registration approvals tab and actions"
git push origin main
```

---

### Task 5: Mobile App Pending Registration Screen & Login Handling

**Files:**
- Create: `mobile/lib/screens/registration_pending_screen.dart`
- Modify: `mobile/lib/screens/signup_otp_screen.dart`
- Modify: `mobile/lib/screens/login_screen.dart`
- Modify: `mobile/lib/providers/auth_provider.dart`
- Test: `mobile/test/screens/registration_pending_screen_test.dart`

**Interfaces:**
- Consumes: Registration submission.
- Produces: `RegistrationPendingScreen` view and 403 login error guidance banner.

- [ ] **Step 1: Create `RegistrationPendingScreen`**
  - Displays icon, clear heading "Registration Submitted", message about waiting for admin approval, and "Back to Sign In" button.

- [ ] **Step 2: Update `SignupOtpScreen`**
  - On successful registration, navigate to `RegistrationPendingScreen` (replacing stack).

- [ ] **Step 3: Update `LoginScreen` and `AuthProvider`**
  - Detect 403 `"pending administrator approval"` and present informative amber pending message with a link/action to view status or contact admin.

- [ ] **Step 4: Add Widget Tests for `RegistrationPendingScreen`**
  - Verify screen renders message and back button.

- [ ] **Step 5: Run mobile test suite**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 6: Commit and Push**

```bash
git add mobile/lib/screens/registration_pending_screen.dart mobile/lib/screens/signup_otp_screen.dart mobile/lib/screens/login_screen.dart mobile/lib/providers/auth_provider.dart mobile/test/screens/registration_pending_screen_test.dart
git commit -m "feat(mobile): add registration pending approval screen and login handling"
git push origin main
```

---

### Task 6: Full System Verification & Regression Suite

**Files:**
- Test all backend suites: `./venv/bin/pytest`
- Test all mobile suites: `flutter test`

- [ ] **Step 1: Run full backend pytest suite**
Run: `./venv/bin/pytest`
Expected: All tests pass.

- [ ] **Step 2: Run full mobile test suite**
Run: `flutter test`
Expected: All tests pass.
