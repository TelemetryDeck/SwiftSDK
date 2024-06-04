#if canImport(StoreKit)
import StoreKit
import Foundation

@available(iOS 15, macOS 12, tvOS 15, visionOS 1, watchOS 8, *)
extension TelemetryDeck {
    /// Sends a telemetry signal indicating that a purchase has been completed.
    ///
    /// - Parameters:
    ///   - transaction: The completed `StoreKit.Transaction` containing details about the purchase.
    ///   - parameters: Additional parameters to include with the signal. Default is an empty dictionary.
    ///   - customUserID: An optional custom user identifier. If provided, it overrides the default user identifier from the configuration. Default is `nil`.
    ///
    /// This function captures details about the completed purchase, including the type of purchase (subscription or one-time),
    /// the country code of the storefront, and the currency code. It also converts the price to USD if necessary and sends
    /// this information as a telemetry signal. The conversion happens with hard-coded values that might be out of date.
    public static func purchaseCompleted(
        transaction: StoreKit.Transaction,
        parameters: [String: String] = [:],
        customUserID: String? = nil
    ) {
        let priceValueInNativeCurrency = NSDecimalNumber(decimal: transaction.price ?? Decimal()).doubleValue

        let priceValueInUSD: Double
        if transaction.currencyCode == "USD" {
            priceValueInUSD = priceValueInNativeCurrency
        } else if
            let currencyCode = transaction.currencyCode,
            let oneUSDExchangeRate = self.currencyCodeToOneUSDExchangeRate[currencyCode]
        {
            priceValueInUSD = priceValueInNativeCurrency / oneUSDExchangeRate
        } else {
            priceValueInUSD = 0
        }

        #if os(visionOS)
        let countryCode = "US"  // NOTE: visionOS 1.x does not support the `storefrontCountryCode` field
        #else
        let countryCode = transaction.storefrontCountryCode
        #endif

        var purchaseParameters: [String: String] = [
            "TelemetryDeck.Purchase.type": transaction.subscriptionGroupID != nil ? "subscription" : "one-time-purchase",
            "TelemetryDeck.Purchase.countryCode": countryCode,
        ]

        if let currencyCode = transaction.currencyCode {
            purchaseParameters["TelemetryDeck.Purchase.currencyCode"] = currencyCode
        }

        self.signal(
            "TelemetryDeck.Purchase.completed",
            parameters: purchaseParameters.merging(parameters) { $1 },
            floatValue: priceValueInUSD,
            customUserID: customUserID
        )
    }

    private static let currencyCodeToOneUSDExchangeRate: [String: Double] = [
        "AED": 3.6725,
        "AFN": 72.0554,
        "ALL": 92.5513,
        "AMD": 387.7309,
        "ANG": 1.7900,
        "AOA": 847.9332,
        "ARS": 864.7500,
        "AUD": 1.4963,
        "AWG": 1.7900,
        "AZN": 1.7004,
        "BAM": 1.7996,
        "BBD": 2.0000,
        "BDT": 117.1302,
        "BGN": 1.8000,
        "BHD": 0.3760,
        "BIF": 2860.8642,
        "BMD": 1.0000,
        "BND": 1.3459,
        "BOB": 6.9316,
        "BRL": 5.1292,
        "BSD": 1.0000,
        "BTN": 83.3759,
        "BWP": 13.5564,
        "BYN": 3.2600,
        "BZD": 2.0000,
        "CAD": 1.3614,
        "CDF": 2755.7442,
        "CHF": 0.9082,
        "CLP": 900.3503,
        "CNY": 7.2284,
        "COP": 3839.9859,
        "CRC": 512.0651,
        "CUP": 24.0000,
        "CVE": 101.4558,
        "CZK": 22.7403,
        "DJF": 177.7210,
        "DKK": 6.8631,
        "DOP": 58.4759,
        "DZD": 134.6201,
        "EGP": 46.9051,
        "ERN": 15.0000,
        "ETB": 57.5246,
        "EUR": 0.9201,
        "FJD": 2.2311,
        "FKP": 0.7883,
        "FOK": 6.8631,
        "GBP": 0.7883,
        "GEL": 2.7505,
        "GGP": 0.7883,
        "GHS": 14.4525,
        "GIP": 0.7883,
        "GMD": 64.2271,
        "GNF": 8584.4691,
        "GTQ": 7.7757,
        "GYD": 209.5502,
        "HKD": 7.8022,
        "HNL": 24.7426,
        "HRK": 6.9326,
        "HTG": 132.8425,
        "HUF": 356.1900,
        "IDR": 15985.7272,
        "ILS": 3.7070,
        "IMP": 0.7883,
        "INR": 83.3759,
        "IQD": 1311.7359,
        "IRR": 42059.2720,
        "ISK": 138.5833,
        "JEP": 0.7883,
        "JMD": 156.2360,
        "JOD": 0.7090,
        "JPY": 155.6194,
        "KES": 130.5693,
        "KGS": 88.8437,
        "KHR": 4089.9041,
        "KID": 1.4968,
        "KMF": 452.6639,
        "KRW": 1352.5281,
        "KWD": 0.3072,
        "KYD": 0.8333,
        "KZT": 443.9409,
        "LAK": 21646.3439,
        "LBP": 89500.0000,
        "LKR": 300.5281,
        "LRD": 193.5095,
        "LSL": 18.1878,
        "LYD": 4.8568,
        "MAD": 9.9543,
        "MDL": 17.7229,
        "MGA": 4416.3360,
        "MKD": 56.6943,
        "MMK": 2102.2200,
        "MNT": 3388.3658,
        "MOP": 8.0362,
        "MRU": 39.6500,
        "MUR": 46.1117,
        "MVR": 15.4675,
        "MWK": 1745.3320,
        "MXN": 16.6396,
        "MYR": 4.6846,
        "MZN": 63.8496,
        "NAD": 18.1878,
        "NGN": 1505.1574,
        "NIO": 36.8095,
        "NOK": 10.6897,
        "NPR": 133.4014,
        "NZD": 1.6321,
        "OMR": 0.3845,
        "PAB": 1.0000,
        "PEN": 3.7384,
        "PGK": 3.8519,
        "PHP": 57.6709,
        "PKR": 278.6140,
        "PLN": 3.9255,
        "PYG": 7497.4917,
        "QAR": 3.6400,
        "RON": 4.5842,
        "RSD": 107.8018,
        "RUB": 90.9683,
        "RWF": 1309.6127,
        "SAR": 3.7500,
        "SBD": 8.4696,
        "SCR": 14.6159,
        "SDG": 511.3776,
        "SEK": 10.7161,
        "SGD": 1.3459,
        "SHP": 0.7883,
        "SLE": 23.1362,
        "SLL": 23136.1912,
        "SOS": 572.4722,
        "SRD": 32.3562,
        "SSP": 1758.0684,
        "STN": 22.5427,
        "SYP": 12904.8072,
        "SZL": 18.1878,
        "THB": 36.1787,
        "TJS": 10.9522,
        "TMT": 3.5007,
        "TND": 3.1136,
        "TOP": 2.3402,
        "TRY": 32.2401,
        "TTD": 6.7583,
        "TVD": 1.4968,
        "TWD": 32.1857,
        "TZS": 2588.7723,
        "UAH": 39.4347,
        "UGX": 3780.7494,
        "UYU": 38.5887,
        "UZS": 12728.9868,
        "VES": 36.5717,
        "VND": 25464.1316,
        "VUV": 119.4909,
        "WST": 2.7302,
        "XAF": 603.5519,
        "XCD": 2.7000,
        "XDR": 0.7549,
        "XOF": 603.5519,
        "XPF": 109.7984,
        "YER": 250.5088,
        "ZAR": 18.1879,
        "ZMW": 25.4938,
        "ZWL": 13.3976,
    ]
}
#endif
