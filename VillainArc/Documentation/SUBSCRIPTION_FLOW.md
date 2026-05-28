# Subscription Flow

How Villain Arc Pro is defined, gated, purchased, and persisted. Mirrors the structure of `SESSION_LIFECYCLE_FLOW.md`.

## Main Files

- `Data/Services/Subscription/SubscriptionStore.swift` — StoreKit 2 store, status enum, App Group caching, product loading, purchase and restore
- `Data/Services/Subscription/SubscriptionGate.swift` — `PremiumFeature` enum, `SubscriptionGate.require()` helper, `PaywallPresenter` observable
- `Views/Subscription/PaywallView.swift` — full-screen paywall sheet, product cards, purchase/restore actions
- `Views/Subscription/PremiumLockedView.swift` — inline locked-content placeholder shown behind a gate
- `VillainArcTests/SubscriptionStoreTests.swift` — unit tests for status derivation and cache logic

## The Pro Subscription

| Field | Monthly | Yearly |
|---|---|---|
| Product ID | `com.fcttechnologies.VillainArc.Pro.Monthly` | `com.fcttechnologies.VillainArc.Pro.Yearly` |
| Price | $4.99 USD | $39.99 USD |
| Introductory offer | 7-day free trial | 7-day free trial |
| Family Sharing | Enabled | Enabled |
| ASC subscription IDs | `6773965177` | `6773965537` |
| ASC group ID | `22118154` ("Villain Arc Pro") | — |

Five premium features gated behind Pro:

| Feature | `PremiumFeature` case | Display name |
|---|---|---|
| AI plan generation | `.aiPlanGeneration` | "AI Plan Generation" |
| AI exercise replacement | `.aiExerciseReplacement` | "AI Exercise Replacement" |
| Health Trends | `.healthTrends` | "Health Trends" |
| Sleep Timing Insights | `.sleepTimingInsights` | "Sleep Timing Insights" |
| Correlation Insights | `.correlationInsights` | "Correlation Insights" |

All other features (plans, templates, logging, cardio, hydration, widgets, shortcuts) are free.

## Gate Flow

```
call site
  └─ SubscriptionGate.require(.feature) { action }
       ├─ isPro == true  → action()
       └─ isPro == false → PaywallPresenter.shared.present(for: feature)
                               └─ sets trigger = feature
                                   └─ ContentView .fullScreenCover fires → PaywallView(triggeringFeature:)
```

`SubscriptionGate.isPro`:
1. Returns `true` if `SubscriptionStore.shared.status.isPro` is true (live status: `.subscribed`, `.inFreeTrial`, `.inGracePeriod`).
2. If `status == .unknown` (first launch before StoreKit resolves), falls back to `SubscriptionStore.cachedIsPro` from the App Group — avoids a paywall flash for known-Pro users on cold launch.
3. Returns `false` otherwise (`.notSubscribed`, `.expired`).

## PaywallView Trigger

`ContentView` holds `@State private var paywallPresenter = PaywallPresenter.shared` and attaches:

```swift
.fullScreenCover(item: $paywallPresenter.trigger) { feature in
    PaywallView(triggeringFeature: feature)
}
```

`PaywallPresenter.trigger` is a `PremiumFeature?`. Setting it to a non-nil value opens the paywall. `PaywallPresenter.dismiss()` nils it out, closing the sheet. The paywall spotlights the triggering feature in its header.

## Status Transitions

```
.unknown (cold launch, before StoreKit resolves)
   │
   ├─ no cached entitlement → .notSubscribed
   └─ cached entitlement   → .subscribed (optimistic pre-warm)
         │
         └─ StoreKit resolves:
               .subscribed(productID:, expirationDate:, willAutoRenew:)
               .inFreeTrial(productID:, trialEndDate:)
               .inGracePeriod(productID:, expirationDate:)
               .expired(productID:, expirationDate:)
               .notSubscribed
```

`SubscriptionStore.start()` is called once from `VillainArcApp`. It:
1. Pre-warms from the App Group cache (`prewarmFromCache()`).
2. Attaches a `Transaction.updates` listener (background task) for real-time transaction events.
3. Calls `loadProducts()` + `refreshStatus()` on the main actor.

`refreshStatus()` walks `Transaction.currentEntitlements`, finds the first verified entitlement matching either product ID, derives the status from the transaction + `Product.SubscriptionInfo.Status`, then persists the resolved state to the cache.

## App Group Cache

Keys in `SharedModelContainer.sharedDefaults` (App Group `group.com.fcttechnologies.VillainArcCont`):

| Key | Type | Purpose |
|---|---|---|
| `subscription_is_pro_cached` | Bool | Whether user has Pro access — widget reads this |
| `subscription_cached_product_id` | String? | Which product is active |
| `subscription_cached_expiration` | Double (TimeInterval) | Expiration/renewal date as Unix timestamp |

The widget reads `SubscriptionStore.cachedIsPro` to gate any Pro-only widget content without needing a full StoreKit query.

## Testing Locally

A StoreKit configuration file is checked into the repo at `VillainArc/VillainArc.storekit`. It defines:
- Subscription group "Villain Arc Pro" with both products
- Monthly ($4.99) and yearly ($39.99) with 7-day free trial introductory offer on each
- Family Sharing enabled on both
- Default storefront: USA

To use it in the simulator:
1. In Xcode, open the scheme editor (Product → Scheme → Edit Scheme).
2. Select **Run** → **Options** tab.
3. Set **StoreKit Configuration** to `VillainArc.storekit`.

The scheme file already has a `StoreKitConfigurationFileReference` pointing at `VillainArc/VillainArc.storekit` — if Xcode doesn't pick it up automatically, wire it manually via the UI above.

Purchases in the simulator against the `.storekit` file are local-only and reset when the app is reinstalled. Use `SKTestSession` in unit tests for deterministic state.
