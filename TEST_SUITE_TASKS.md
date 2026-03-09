# Test Suite Tasks

## Goal

Bring the gem's test suite closer to real user flows, cover missing edge cases, and reduce low-value duplication.

## Priority 1: Cover the real runtime flow

### Task 1: Add integration tests for click redirect happy path

- Add request or integration tests for `AffiliateTracker::ClicksController#redirect`.
- Verify valid signed URLs:
  - decode correctly,
  - create a click record,
  - redirect to the destination URL,
  - append expected UTM params,
  - preserve existing query params.
- Verify response status and redirect target exactly.

**Why**

Current tests mostly cover URL generation, but not the main production flow after a user clicks a link.

**Suggested assertions**

- click count increases by 1
- saved `destination_url` matches decoded payload
- redirect URL contains `utm_source`, `utm_medium`, optional `utm_campaign`, optional `utm_content`
- existing query params are preserved

### Task 2: Add integration tests for invalid or missing signature

- Test invalid signature redirects to fallback URL.
- Test missing signature redirects to fallback URL.
- Test tampered payload redirects to fallback URL.
- Test fallback works for:
  - static string config,
  - proc-based config with decoded untrusted payload,
  - corrupt payload passed into proc fallback.

**Why**

This is a key resilience path documented in the gem, but it is not covered end-to-end.

### Task 3: Add integration tests for click deduplication

- Exercise two requests through the controller, not directly through `Rails.cache`.
- Verify same IP + same destination within 5 seconds creates only one click.
- Verify different IP still records a second click.
- Verify different destination still records a second click.
- Verify click is recorded again after dedup window expires or is cleared.

**Why**

Current deduplication tests check cache primitives, not actual dedup behavior in production code.

### Task 4: Add integration tests for `after_click`

- Verify configured `after_click` handler is called after a successful click record.
- Verify handler receives the created `AffiliateTracker::Click`.
- Verify exceptions in handler do not break redirect flow.

**Why**

`after_click` is part of the public configuration API and should be regression-safe.

### Task 5: Add integration tests for request metadata handling

- Verify IP is anonymized before persisting.
- Verify `user_agent` is truncated to 500 chars.
- Verify `referer` is truncated to 500 chars.
- Verify metadata is stored as expected.

**Why**

This logic exists in the controller and affects privacy and database safety, but is currently untested.

## Priority 2: Cover dashboard and model behavior

### Task 6: Add controller/integration tests for dashboard access

- Verify `/a/dashboard` resolves correctly.
- Verify dashboard renders when no auth proc is configured.
- Verify configured `authenticate_dashboard` proc is executed.
- Verify auth proc can redirect unauthenticated users.

**Why**

Dashboard access is a user-facing feature and currently has no behavioral coverage.

### Task 7: Add dashboard stats tests

- Seed clicks across different timestamps.
- Verify:
  - `total_clicks`
  - `today_clicks`
  - `week_clicks`
  - `unique_destinations`
  - recent clicks ordering
  - top destinations counts

**Why**

The dashboard is mostly aggregation logic. That kind of logic regresses easily when queries change.

### Task 8: Add model tests for `AffiliateTracker::Click`

- Test validations for `destination_url` and `clicked_at`.
- Test `domain` with:
  - valid URL,
  - invalid URL,
  - URL without host if relevant.
- Test scopes:
  - `.today`
  - `.this_week`
  - `.this_month`

**Why**

The model has public behavior that is not currently covered at all.

## Priority 3: Fix test architecture issues

### Task 9: Stop stubbing the gem's public API in `test/test_helper.rb`

- Load the real `lib/affiliate_tracker.rb` where possible.
- Remove duplicated test-only implementations of:
  - `AffiliateTracker.configure`
  - `AffiliateTracker.track_url`
  - `AffiliateTracker.url`
- Keep only the minimal Rails test scaffolding needed by the gem.

**Why**

Current tests can pass even if the real entry point breaks, especially around `default_metadata`.

### Task 10: Add tests for `default_metadata`

- Verify configured `default_metadata` is merged into generated tracking URLs.
- Verify explicit per-link metadata overrides default values where expected.
- Verify non-hash return value falls back to `{}`.
- Verify exceptions inside `default_metadata` do not break URL generation.

**Why**

This is real logic in the gem entry point and is currently untested because the suite bypasses it.

## Priority 4: Replace low-value indirect tests

### Task 11: Replace route file parsing tests with routing behavior tests

- Replace string-based assertions against `config/routes.rb`.
- Add routing tests that verify:
  - `/a/dashboard` routes to dashboard controller,
  - `/a/:payload` routes to click redirect,
  - dashboard route is not swallowed by payload route.

**Why**

Parsing the routes file as text is brittle and does not prove the router behaves correctly.

### Task 12: Remove or rewrite the Base64 `dashboard` test

- Delete or replace the test asserting `"dashboard"` is not valid Base64 payload.
- If kept, justify it with actual runtime behavior.

**Why**

That test does not meaningfully protect routing behavior.

## Priority 5: Reduce redundant coverage

### Task 13: Consolidate overlapping URL generation tests

- Review overlap between:
  - `ConfigurationTest`
  - `UrlGeneratorTest`
  - `ViewHelpersTest`
- Keep one focused place for:
  - signature format,
  - `/a/` URL structure,
  - same input => same output,
  - different input => different signature.

**Why**

The suite repeats the same contract several times with little extra protection.

### Task 14: Trim repetitive helper tests

- Keep tests that cover real helper-specific behavior:
  - HTML escaping,
  - block syntax,
  - HTML attributes vs tracking metadata split,
  - default `target` and `rel`,
  - overriding `target` and `rel`.
- Reduce repeated cases that only re-prove `UrlGenerator.decode`.

**Why**

`ViewHelpersTest` is large, but much of it duplicates lower-level URL generator coverage.

## Optional: Installer and engine coverage

### Task 15: Add tests for engine helper inclusion

- Verify helpers are available in Action View.
- Verify helpers are available in Action Mailer if the gem promises that behavior.

### Task 16: Add generator tests

- Verify install generator:
  - creates initializer,
  - creates migration,
  - mounts engine route.

**Why**

For a gem, installation and framework integration are part of the product surface.

## Suggested execution order

1. Add redirect integration tests.
2. Add deduplication and fallback tests.
3. Add dashboard and model tests.
4. Fix `test_helper` to use the real gem entry point.
5. Replace indirect route tests.
6. Remove redundant helper and URL tests.

## Definition of done

- Main click flow is covered end-to-end.
- Failure paths are covered end-to-end.
- Public config hooks are covered.
- Dashboard behavior is covered.
- Model behavior is covered.
- Tests execute against real production entry points, not test-only rewrites.
- Redundant tests are reduced without losing regression protection.
