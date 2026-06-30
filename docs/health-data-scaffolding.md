# Health Data Scaffolding

AI Nutrition Companion V1 includes health-data permission scaffolding without a
native HealthKit or Health Connect dependency.

## Current Behavior

- Health connection is opt-in from the Me tab.
- App startup can check local connection state, but it does not request health
  authorization.
- The default provider is a deterministic internal provider for development and
  tests.
- Supported MVP signal categories are weight, activity, workouts, and sleep.
- Connected internal test signals may personalize deterministic meal
  suggestions.
- Disconnecting clears the app's local health connection state.

## Permission States

The app can render these states:

- `disconnected`: health connection is off and manual nutrition logging still
  works.
- `connected`: selected internal test signals are available to recommendation
  fixtures.
- `denied`: permission was denied and the app remains usable without health
  data.
- `unavailable`: no HealthKit or Health Connect bridge is available for this
  build or platform.

## Native Bridge Boundary

No HealthKit entitlement, Android Health Connect permission, or platform health
plugin is enabled by this scaffolding. A native bridge should be added behind
the `HealthDataProvider` interface only after store disclosures, privacy policy,
and platform permission copy are updated for the final data flow.

The native bridge must preserve these rules:

- Request health permission only after explicit user intent.
- Request only the MVP data types that are supported on the platform.
- Keep the app useful when permission is denied or unavailable.
- Make disconnect behavior visible and reversible from Me.
- Update App Store privacy details and Google Play Data safety before release.
