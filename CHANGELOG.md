# Changelog

## [0.3.1] - 2026-03-17

### Changed
- Redirect status changed from 301 (`:moved_permanently`) to 302 (`:found`). 301s are cached permanently by browsers, which prevents click re-tracking on subsequent visits.
- IPv6 anonymization: `anonymize_ip` now handles IPv6 addresses by zeroing the last 80 bits (last 5 groups), in addition to the existing IPv4 last-octet zeroing.
- CI matrix expanded to test Ruby 3.2, 3.3, and 3.4.
- Gem prepared for RubyGems.org publication: added LICENSE.txt, CHANGELOG.md to gem files, MFA requirement, upper-bound Rails dependency (`< 10`).

## [0.3.0] - 2026-03-17

### Added
- URL normalization: URLs without a protocol (e.g. `shop.com/page`) are automatically prepended with `https://` both at URL generation time and at redirect time. Prevents broken redirects for malformed destination URLs.
- Tests for URL normalization in `UrlGenerator` and `ClicksController`.

### Changed
- `UrlGenerator#initialize` now normalizes destination URLs before encoding.
- `ClicksController#redirect` normalizes destination URLs before appending UTM params and redirecting.

## [0.2.0] - 2026-01-24

- Per-link metadata override for UTM params (`utm_source`, `utm_medium`).
- Configurable `after_click` callback.
- Proc-based `fallback_url` with untrusted payload data.
- Click deduplication (same IP + URL within 5s).

## [0.1.0] - 2025-12-15

- Initial release with click tracking, UTM injection, and redirect.
