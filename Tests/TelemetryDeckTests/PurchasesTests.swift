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
        #expect(params[DefaultParams.Purchase.type.rawValue] as? String == "subscription")
    }

    @Test
    func purchaseParametersOneTimePurchaseType() {
        let params = TelemetryDeck.purchaseParameters(
            productID: "com.example.pro",
            type: .oneTimePurchase,
            currencyCode: "USD",
            countryCode: nil
        )
        #expect(params[DefaultParams.Purchase.type.rawValue] as? String == "one-time-purchase")
    }

    @Test
    func purchaseParametersContainsProductIDAndCurrencyCode() {
        let params = TelemetryDeck.purchaseParameters(
            productID: "com.example.pro",
            type: .oneTimePurchase,
            currencyCode: "EUR",
            countryCode: nil
        )
        #expect(params[DefaultParams.Purchase.productID.rawValue] as? String == "com.example.pro")
        #expect(params[DefaultParams.Purchase.currencyCode.rawValue] as? String == "EUR")
    }

    @Test
    func purchaseParametersOmitsCountryCodeWhenNil() {
        let params = TelemetryDeck.purchaseParameters(
            productID: "com.example.pro",
            type: .subscription,
            currencyCode: "USD",
            countryCode: nil
        )
        #expect(params[DefaultParams.Purchase.countryCode.rawValue] == nil)
    }

    @Test
    func purchaseParametersIncludesCountryCodeWhenProvided() {
        let params = TelemetryDeck.purchaseParameters(
            productID: "com.example.pro",
            type: .subscription,
            currencyCode: "USD",
            countryCode: "US"
        )
        #expect(params[DefaultParams.Purchase.countryCode.rawValue] as? String == "US")
    }
}
