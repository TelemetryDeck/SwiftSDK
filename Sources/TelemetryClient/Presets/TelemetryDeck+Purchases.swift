#if canImport(StoreKit)
import StoreKit
import Foundation

@available(iOS 15, macOS 12, tvOS 15, visionOS 1, watchOS 8, *)
extension TelemetryDeck {
    public static func purchaseCompleted(
        transaction: StoreKit.Transaction,
        parameters: [String: String] = [:],
        customUserID: String? = nil
    ) {
        let priceValueInNativeCurrency = NSDecimalNumber(decimal: transaction.price ?? Decimal()).doubleValue

        let priceValueInUSD: Double
        if transaction.currency == Locale.Currency("USD") {
            priceValueInUSD = priceValueInNativeCurrency
        } else {
            priceValueInUSD = priceValueInNativeCurrency * 1.0  // TODO: implement hard-coded lookup table
        }

        var purchaseParameters: [String: String] = [
            "TelemetryDeck.Purchase.type": transaction.subscriptionGroupID != nil ? "subscription" : "one-time-purchase",
            "TelemetryDeck.Purchase.countryCode": transaction.storefront.countryCode,
        ]

        if let currency = transaction.currency {
            purchaseParameters["TelemetryDeck.Purchase.currencyCode"] = currency.identifier
        }

        self.signal(
            "TelemetryDeck.Purchase.completed",
            parameters: purchaseParameters.merging(parameters) { $1 },
            floatValue: priceValueInUSD,
            customUserID: customUserID
        )
    }
}
#endif
