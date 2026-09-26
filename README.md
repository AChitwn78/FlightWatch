# FlightWatch — Mac prototype

Native SwiftUI prototype for comparing and tracking flight prices. Requires macOS 13+ and Xcode 15+. No external dependencies.

## Test on Mac

Run `bash scripts/build-mac.sh`, then open `../FlightWatch.app`.

1. Search the sample ORD → LHR route (one adult, economy, one way, USD).
2. Sort by price, stops or departure. Filter connections and departure hours.
3. Track multiple flights and open Tracking.
4. Enable notifications in Preferences and allow the macOS permission prompt.
5. Simulate a 10% drop from Tracking. Verify the history and notification.
6. Quit and reopen; the watchlist and summary preference should persist.

All prices and providers are explicitly simulated. No actual travel availability is asserted. No automatic polling, scheduled summary delivery, remote push, or account synchronization is active. Summary frequency is stored for future service integration. Local notifications require OS permission; Focus settings may suppress banners.

Run core tests with `swift test`.

## Structure

- `Sources/FlightCore`: flight models, filters, sorting, price observations.
- `Sources/FlightWatch`: native search, tracking, charts, local notification test, JSON persistence.
- `Tests/FlightCoreTests`: filtering, sorting, drop detection and persistence encoding.

Watchlists are stored under Application Support/FlightWatch. Never commit API credentials, signing keys or user data.

## Next stages

1. Finish Mac usability testing.
2. Select and obtain authorized flight APIs. Skyscanner requires partner approval; Amadeus requires an API account. Implement server-side adapters and normalize comparable itineraries, currency, passenger count, baggage, cabin and fare conditions. Do not compare unlike fares or treat provider failure as a price drop.
3. Deploy an authenticated monitoring service with durable watchlists, per-provider polling limits, retry/backoff, price observations, and deduplicated notification jobs. Drops bypass summary frequency and notify as soon as a scheduled check detects them. Summaries include only actual changes.
4. Add APNs credentials and register device tokens per authenticated user. Deliver to each opted-in device. Apple ID alone does not broadcast app notifications. Server monitoring must continue while devices are asleep.
5. After Mac approval, add an iOS app target and signing, shared-account synchronization and device registration, then test on iPhone. Shared SwiftUI source is prepared for this; there is no installable iOS target yet.

Official integration references:
- https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns
- https://developers.skyscanner.net/docs/flights-live-prices/quick-start
- https://developers.amadeus.com/self-service
