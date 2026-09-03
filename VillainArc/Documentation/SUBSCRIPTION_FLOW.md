# Subscription Flow

How Villain Arc Pro is defined, gated, purchased, and persisted.

**The client is `FCTStoreKit`.** The verified-entitlement state machine, the App-Group cache, the
server claim, the paywall shell, the locked-feature placeholder and the gate are all the package's;
what this app owns is four things — the product catalog, the premium-feature enum, the paywall's
branding, and the account the claim rides on. There is no app-local subscription store.

## Main Files

- `Data/Services/Subscription/VAPro.swift` — the whole of this app's half: the `ProCatalog`, the
  `SubscriptionCache` over the App Group, the `PaywallBranding`, the `PremiumFeature` enum, and the
  one `SubscriptionStore` / `PaywallPresenter` / `PremiumGate` trio the app reads
- `VillainArcTests/SubscriptionStoreTests.swift` — this app's composition (catalog IDs, cache keys,
  feature copy) plus `FCTStoreKitTesting`'s live transaction scenarios against the `.storekit` file
- `FCTStoreKit` (package) — `SubscriptionStore`, `SubscriptionStatus`, `EntitlementMerge`,
  `EntitlementClient`, `SubscriptionPaywallView`, `PremiumLockedView`, `PremiumGate`

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
  └─ VAPro.gate.require(.feature) { action }
       ├─ isPro == true  → action()
       └─ isPro == false → VAPro.presenter.present(for: feature)
                               └─ sets trigger = feature
                                   └─ ContentView .fullScreenCover fires → SubscriptionPaywallView
```

`isPro` is the **union of two answers**, merged by the package's `EntitlementMerge`: what the FCT
account owns across every device it has been signed into (`entitlement_get()`), and what this
device's Apple ID owns (`Transaction.currentEntitlements`). Either one saying yes is a real
entitlement, and the server can only *add* access, never remove it — a refused claim means the
transaction belongs to a different FCT account, and the Apple ID in front of us still bought it.
The App-Group cache is a startup hint only: it applies while StoreKit itself is `.unknown`, so a
known-Pro user sees no paywall flash on cold launch and a lapsed one is never held in by it.

A gated destination something pushed *without* passing the gate — an App Intent, a restored
navigation path — renders `VAPro.lockedView(_:)` instead of the feature.

## The account half

`VAPro.accountChanged(to:)` assigns an `EntitlementClient` when the account resolves and `nil` on
sign-out, then refreshes. It is called from `RootView` at launch (after `AccountController.resume()`
restores the session) and on every account-state change. Signing out forgets the *server's* answer
and nothing else, because the device's own Apple ID purchase never depended on it.

The claim posts on purchase, on restore, and on launch, carrying `appAccountToken` so the platform
can tell a transaction bought under this account from one bought under another. Nothing is claimed
from a local `.storekit` configuration — StoreKit reports its environment as `Xcode`, and the door
verifies against Apple's root.

## App Group Cache

Keys in `SharedModelContainer.sharedDefaults` (App Group `group.com.fcttechnologies.VillainArc1`),
produced by `SubscriptionCache`'s default namespace:

| Key | Type | Purpose |
|---|---|---|
| `subscription_is_pro_cached` | Bool | Whether user has Pro access — widget reads this |
| `subscription_cached_product_id` | String? | Which product is active |
| `subscription_cached_expiration` | Double (TimeInterval) | Expiration/renewal date as Unix timestamp |

`VAProConfigurationTests` pins those three key strings, because they are a contract between the app
and the widget bundle rather than an implementation detail.

## Testing Locally

`VillainArc/VillainArc.storekit` is the one StoreKit configuration: subscription group "Villain Arc
Pro", both products at their shipping prices with a 7-day free trial each, Family Sharing on, USA
storefront. The scheme's **Run** action already points at it via `StoreKitConfigurationFileReference`.

The scheme's **Test** action deliberately names no StoreKit configuration. `VAProStoreScenarioTests`
builds its own `SKTestSession` from that same file, and a second scheme-supplied configuration is
one the session's `disableDialogs` never reaches — the first purchase then parks on a confirmation
sheet nobody will tap, and the run hangs rather than failing.

Two more conditions the suite depends on: it is `.serialized` (one `SKTestSession` is one
process-wide store), and **a simulator that has never served a purchase answers `.userCancelled` for
its whole first run**, so on a brand-new device every scenario fails once and passes on the next run.
