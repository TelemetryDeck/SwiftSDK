import Foundation
import Testing

@testable import TelemetryDeck

struct PurchasesTests {
    // MARK: - priceInUSD

    @Test
    func priceInUSDPassthroughForUSD() {
        let result = TelemetryDeck.priceInUSD(Decimal(9.99), currencyCode: "USD")
        #expect(abs(result - 9.99) < 0.001)
    }

    @Test
    func priceInUSDConvertsDividesByTableRate() {
        let eurRate = 0.9533
        let price = Decimal(9.99)
        let expected = NSDecimalNumber(decimal: price).doubleValue / eurRate
        let result = TelemetryDeck.priceInUSD(price, currencyCode: "EUR")
        #expect(abs(result - expected) < 0.001)
    }

    @Test
    func priceInUSDReturnsZeroForUnknownCode() {
        let result = TelemetryDeck.priceInUSD(Decimal(9.99), currencyCode: "ZZZ")
        #expect(result == 0)
    }

    // MARK: - purchaseParameters

    @Test
    func purchaseParametersSubscriptionType() {
        let params = TelemetryDeck.purchaseParameters(
            productID: "com.example.monthly",
            type: .subscription,
            currencyCode: "USD",
            countryCode: nil
        )
        #expect(params["TelemetryDeck.Purchase.type"] == "subscription")
    }

    @Test
    func purchaseParametersOneTimePurchaseType() {
        let params = TelemetryDeck.purchaseParameters(
            productID: "com.example.pro",
            type: .oneTimePurchase,
            currencyCode: "USD",
            countryCode: nil
        )
        #expect(params["TelemetryDeck.Purchase.type"] == "one-time-purchase")
    }

    @Test
    func purchaseParametersContainsProductIDAndCurrencyCode() {
        let params = TelemetryDeck.purchaseParameters(
            productID: "com.example.pro",
            type: .oneTimePurchase,
            currencyCode: "EUR",
            countryCode: nil
        )
        #expect(params["TelemetryDeck.Purchase.productID"] == "com.example.pro")
        #expect(params["TelemetryDeck.Purchase.currencyCode"] == "EUR")
    }

    @Test
    func purchaseParametersOmitsCountryCodeWhenNil() {
        let params = TelemetryDeck.purchaseParameters(
            productID: "com.example.pro",
            type: .subscription,
            currencyCode: "USD",
            countryCode: nil
        )
        #expect(params["TelemetryDeck.Purchase.countryCode"] == nil)
    }

    @Test
    func purchaseParametersIncludesCountryCodeWhenProvided() {
        let params = TelemetryDeck.purchaseParameters(
            productID: "com.example.pro",
            type: .subscription,
            currencyCode: "USD",
            countryCode: "US"
        )
        #expect(params["TelemetryDeck.Purchase.countryCode"] == "US")
    }
}
