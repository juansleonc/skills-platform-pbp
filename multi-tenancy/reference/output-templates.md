# Audit Output Templates & Worked Example

> All paths below are HYPOTHETICAL placeholders for illustration — they do not correspond to real
> files. For real, repo-verified instances see Step 3 ("Identify Violations") in `SKILL.md`.

## Audit Output Template

```markdown
## Multi-Tenancy Audit

### Files Analyzed
- app/services/example_service.rb
- app/controllers/api/example_controller.rb

### Data Access Points Found: 5

### Properly Scoped: 4
| Location | Pattern | Status |
|----------|---------|--------|
| example_service.rb:23 | facility.reservations | OK |
| api/example_controller.rb:15 | current_facility.reservations | OK |

### Violations Found: 1
| Location | Code | Risk | Fix |
|----------|------|------|-----|
| example_service.rb:45 | `User.find(user_id)` | HIGH | Use `facility.users.find(user_id)` |

### Recommendations
1. Fix violation at example_service.rb:45
2. Add facility scope to User lookup
```

## Worked Example

```
User: /multi-tenancy

Claude:
## Multi-Tenancy Audit

### Scanning changed files...
Files: app/services/hypothetical_booking_service.rb  # <-- HYPOTHETICAL PATH

### Data Access Points
Line 23: facility.memberships.active              [OK]   Properly scoped (via membership_plans chain)
Line 45: User.find_by(email: params[:email])      [CHECK] users are global; OK for login/magic-link, NOT OK for facility-scoped lookups
Line 67: current_facility.payments.create         [OK]   Properly scoped (payments has facility_id)
Line 89: Reservation.find(params[:id])            [FAIL] UNSCOPED — reservations has no facility_id; scope via facility.reservations.find(...)

### Patterns Requiring Review: 2

#### Line 45 — User lookup (check intent)
   # Global lookup — correct for cross-facility auth flows (magic link, login)
   user = User.find_by(email: params[:email])
   # If this is a facility-scoped lookup ("does this user belong to MY facility"):
   user = facility.users.find_by(email: params[:email])

#### Line 89 — Reservation without facility scope
   # UNSCOPED
   reservation = Reservation.find(params[:id])
   # SCOPED (reservations has no facility_id; go through facility association)
   reservation = current_facility.reservations.find(params[:id])

### Action Required
Verify intent on User lookup; fix Reservation scope.
```
