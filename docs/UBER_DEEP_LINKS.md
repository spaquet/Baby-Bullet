# Uber ride deep links (Station detail sheet)

Goal: "Ride to This Station with Uber" / "Ride from This Station with Uber"
buttons on `StationDetailView` (opened via the `i` button on Home) open Uber
with pickup or dropoff pre-filled to the station's coordinates.

**Built.** `StationDetailView.uberURL` (`CT/Views/PlanTrip/StationDetailView.swift`).

## What broke, and why

Two dead ends before landing on the working format:

1. **`https://m.uber.com/ul/?action=setPickup&pickup[latitude]=...`** — old
   "Ride Request Widget" deep link format. Square brackets in the query
   weren't percent-encoded, producing a syntactically invalid URL (Safari:
   "Safari cannot open the page because the address is invalid"). Fixing the
   encoding (via `URLComponents`/`URLQueryItem`) didn't fix the underlying
   problem: `m.uber.com/ul/` itself is deprecated. Confirmed live — Chrome
   silently redirects it to the generic `https://www.uber.com/us/en/ride/`
   page with no pickup/dropoff carried over.
2. **`https://m.uber.com/go/home?drop[0]={JSON}`** — guessed from a
   real-world example URL, without `client_id`. Loaded a ride page but
   pickup/dropoff stayed empty — this endpoint isn't the documented one and
   silently ignores the location params without a client_id.

## What works

Per Uber's official docs
(https://developer.uber.com/docs/riders/ride-requests/tutorials/deep-links/introduction):

```
https://m.uber.com/looking?client_id=<CLIENT_ID>&pickup={location JSON}&drop[0]={location JSON}
```

- `client_id` is required (not optional despite some blog posts omitting
  it) — without it the page loads but drops the location params, same
  symptom as the `go/home` dead end above.
- `pickup` / `drop[0]` values are a URL-encoded JSON object:
  `{"latitude":..., "longitude":..., "addressLine1":"...", "addressLine2":"..."}`.
  `addressLine1` is the location's display nickname; we pass the station
  name and skip `addressLine2` (no street address needed).
- Only one of `pickup`/`drop[0]` is set per button — the other defaults to
  the user's current location in the Uber app/web flow:
  - "Ride to This Station" (`isRideDestination == true`) → station is the
    dropoff → `drop[0]`.
  - "Ride from This Station" (`isRideDestination == false`) → station is
    the pickup → `pickup`.

`client_id` comes from an Uber developer app
(https://developer.uber.com) and lives in `CT/App/Secrets.swift`
(gitignored) as `Secrets.uberClientID`, alongside the 511 token — see
`Secrets.swift.example` for the template.

## Not done

- No `payment_method_id` / `product_id` — not relevant, we're not
  pre-selecting an Uber product or payment method.
- Not using the `UberRides` SDK (`RequestDeeplink`) shown in Uber's Swift
  example — that's a separate CocoaPod/SPM dependency; the plain
  universal-link URL above covers the same behavior (app deep link with
  mobile-web fallback) without adding a third-party dependency, matching
  this repo's no-deps-unless-asked convention.
