# Billing assertion audit

Reviewed all 25 declarations and every helper/JSON fixture in `Tests/Domains/Billing/BillingTests.swift` at baseline `02f98f89a19b6c079517c9aae07df7edd0e600e5`; the file matches the [legacy inventory](legacy-tests.json).

The selected native profile omits the separate `clerk.billing` root. This is a documented feature removal, not a complete Billing migration. Payment methods reachable through User and Organization remain supported. Their canonical implementation is `packages/clerk-js/src/core/modules/billing/payment-source-methods.ts` and `resources/BillingPaymentMethod.ts`; generated native resources read its projection. No native Billing service is restored.

`NativeCoreContractTests/PaymentMethodTests.swift` and Android `NativeCoreTests/Android/PaymentMethodTest.kt` execute the packaged JavaScriptCore/QuickJS bundle. Both payer routes verify HTTP GET, session context, pagination, total count, typed card fields, nullable values, date conversion, and unknown output status. Each platform passes both payer cases. These are deterministic HTTP fixtures, not live commerce requests or payment authorization.

| Old declaration | Disposition |
| --- | --- |
| `billingGetMethodsAreCallable` | The nine clerk.billing query methods are unavailable. User.getPaymentMethods and Organization.getPaymentMethods are exercised through the generated APIs on both native engines; the old test only checked injected-service callability. |
| `getPlansMapsOrganizationPayerTypeAndPagination` | The plans endpoint, payer_type/org_id/min_seats query and pagination belong to the removed Billing root. New payment-method tests independently verify page 3/size 10 as offset 20/limit 10. |
| `getPlansDefaultsToUserPayerTypeAndFirstPage` | The getPlans default query contract is unavailable; payment-method pagination is not claimed as a replacement for it. |
| `userAndOrganizationUseDistinctBillingPathPrefixes` | Subscription/statements/payment-attempts/credits routes are unavailable. New native tests verify the still-supported /me/billing/payment_methods and /organizations/org_payment/billing/payment_methods GETs with session context. |
| `getCreditHistoryOmitsPagination` | Credit history is not selected; omission of its pagination is not a supported contract. |
| `decodesFeature` | This old Feature DTO decoder and its id/name/description/slug/avatar assertions are removed with the separate Billing root. |
| `decodesBillingMoneyAmount` | The old money amount/formatted amount/currency/symbol DTO is not in this selected graph. |
| `decodesBillingPlanWithFeaturesUnitPricesAndAvailablePrices` | Plan features, seat tiers, prices, and trial fields belong to the unavailable Billing root. |
| `decodesBillingPlanUnitPriceTierWhenIdIsMissing` | Optional plan-tier IDs are part of the removed plan decoder. |
| `decodesBillingPlanDefaultsMissingFeaturesAndTrial` | Missing plan feature/trial defaults belong to the removed decoder. |
| `decodesBillingSubscriptionWithSeatsCreditsAndDiscounts` | Subscription status, seats, credits, proration, and discounts are not selected resources. |
| `decodesBillingSubscriptionWhenActiveAtIsNull` | The nullable subscription activation timestamp contract is unavailable. |
| `decodesBillingStatementWithTotals` | Statement status, totals, groups, and items are not selected resources. |
| `decodesBillingStatementGroupWhenIdIsMissing` | Optional statement group IDs belong to the removed decoder. |
| `decodesBillingPaymentWhenNestedSubscriptionItemOmitsCreatedAt` | Payment-attempt nested subscription price/date defaults are not selected. |
| `decodesBillingPaymentWhenNestedSubscriptionItemSendsEpochTimestamps` | The old payment-attempt rule mapping zero timestamps to nil is removed. Payment-method dates follow canonical TypeScript and are tested separately. |
| `decodesBillingPaymentWithTotals` | Payment-attempt status, charge type, totals, proration, seat totals, and nested payment method are not selected as a payment-attempt resource. |
| `decodesUnknownBillingEnumValuesWithoutFailingTheResource` | The tested subscription/payment-attempt enum types are removed. New generated payment-method tests separately preserve an unknown payment-method status; they do not establish those removed enum contracts. |
| `decodesBillingPaymentMethod` | New native tests assert id, last4, card type, active status, expiry month, and additional date/null/default/removable fields on resources returned by real TypeScript execution. |
| `decodesBillingCreditBalance` | Credit-balance money is not a selected resource. |
| `decodesBillingCreditLedger` | Credit-ledger ID/source/amount fields are not selected. |
| `rawEnvelopesDecodePlansAndPaymentAttempts` | Those four raw response endpoints are unavailable; their old response adapter is removed. |
| `clientResponseEnvelopesDecodeSubscriptionStatementsCreditsAndPaymentMethods` | Subscription/statements/credits are unavailable. The payment-method branch has new generated collection tests for the canonical response wrapper, total count and typed resource fields. |
| `rawPlanBodyDoesNotDecodeClientResponseWrapper` | Direct native BillingPlan decoding is removed. Its raw-versus-wrapped rejection is not a new bridge codec contract. |
| `wrappedSubscriptionBodyDoesNotDecodeRawResource` | The old ClientResponse<BillingSubscription> decoder is removed. |

The reviewed BillingTests file is retired after the replacement payment-method checks pass on macOS, iOS Simulator, and Android emulator. Removed plan/subscription/statement/credit features remain explicit availability limitations.
