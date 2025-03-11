#if canImport(StoreKit) && compiler(>=5.9.2)
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
        if #available(iOS 17.2, macOS 14.2, tvOS 17.2, visionOS 1.1, watchOS 10.2, *) {
            // detect if the purchase is a free trial (using modern APIs)
            if
                transaction.productType == .autoRenewable,
                transaction.offer?.type == .introductory,
                transaction.price == nil || transaction.price!.isZero
            {
                self.reportFreeTrial(transaction: transaction, parameters: parameters, customUserID: customUserID)
            } else {
                self.reportPaidPurchase(transaction: transaction, parameters: parameters, customUserID: customUserID)
            }
        } else {
            // detect if the purchase is a free trial (using legacy APIs on older systems)
            if
                transaction.productType == .autoRenewable,
                transaction.offerType == .introductory,
                transaction.price == nil || transaction.price!.isZero
            {
                self.reportFreeTrial(transaction: transaction, parameters: parameters, customUserID: customUserID)
            } else {
                self.reportPaidPurchase(transaction: transaction, parameters: parameters, customUserID: customUserID)
            }
        }
    }

    private static func reportFreeTrial(
        transaction: StoreKit.Transaction,
        parameters: [String: String],
        customUserID: String?
    ) {
        self.internalSignal(
            "TelemetryDeck.Purchase.freeTrialStarted",
            parameters: transaction.purchaseParameters().merging(parameters) { $1 },
            customUserID: customUserID
        )

        TrialConversionTracker.shared.freeTrialStarted(transaction: transaction)
    }

    private static func reportPaidPurchase(
        transaction: StoreKit.Transaction,
        parameters: [String: String],
        customUserID: String?
    ) {
        self.internalSignal(
            "TelemetryDeck.Purchase.completed",
            parameters: transaction.purchaseParameters().merging(parameters) { $1 },
            floatValue: transaction.priceInUSD(),
            customUserID: customUserID
        )
    }
}

@available(iOS 15, macOS 12, tvOS 15, visionOS 1, watchOS 8, *)
extension Transaction {
    func purchaseParameters() -> [String: String] {
        let countryCode: String
        if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
            countryCode = self.storefront.countryCode
        } else {
            #if os(visionOS)
            countryCode = "US"
            #else
            countryCode = self.storefrontCountryCode
            #endif
        }

        var purchaseParameters: [String: String] = [
            "TelemetryDeck.Purchase.type": self.subscriptionGroupID != nil ? "subscription" : "one-time-purchase",
            "TelemetryDeck.Purchase.countryCode": countryCode,
            "TelemetryDeck.Purchase.productID": self.productID,
        ]

        if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
            if let currencyCode = self.currency?.identifier {
                purchaseParameters["TelemetryDeck.Purchase.currencyCode"] = currencyCode
            }
        } else {
            if let currencyCode = self.currencyCode {
                purchaseParameters["TelemetryDeck.Purchase.currencyCode"] = currencyCode
            }
        }

        return purchaseParameters
    }

    func priceInUSD() -> Double {
        let priceValueInNativeCurrency = NSDecimalNumber(decimal: self.price ?? Decimal()).doubleValue
        let priceValueInUSD: Double

        if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
            if self.currency?.identifier == "USD" {
                priceValueInUSD = priceValueInNativeCurrency
            } else if
                let currencyCode = self.currency?.identifier,
                let oneUSDExchangeRate = Self.currencyCodeToOneUSDExchangeRate[currencyCode]
            {
                priceValueInUSD = priceValueInNativeCurrency / oneUSDExchangeRate
            } else {
                priceValueInUSD = 0
            }
        } else {
            if self.currencyCode == "USD" {
                priceValueInUSD = priceValueInNativeCurrency
            } else if
                let currencyCode = self.currencyCode,
                let oneUSDExchangeRate = Self.currencyCodeToOneUSDExchangeRate[currencyCode]
            {
                priceValueInUSD = priceValueInNativeCurrency / oneUSDExchangeRate
            } else {
                priceValueInUSD = 0
            }
        }

        return priceValueInUSD
    }

    private static let currencyCodeToOneUSDExchangeRate: [String: Double] = [
        "AED": 3.6725,
        "AFN": 73.1439,
        "ALL": 94.4244,
        "AMD": 396.6171,
        "ANG": 1.7900,
        "AOA": 915.1721,
        "ARS": 1058.5000,
        "AUD": 1.5742,
        "AWG": 1.7900,
        "AZN": 1.7002,
        "BAM": 1.8645,
        "BBD": 2.0000,
        "BDT": 121.5449,
        "BGN": 1.8646,
        "BHD": 0.3760,
        "BIF": 2964.2266,
        "BMD": 1.0000,
        "BND": 1.3398,
        "BOB": 6.9305,
        "BRL": 5.7132,
        "BSD": 1.0000,
        "BTN": 86.7994,
        "BWP": 13.8105,
        "BYN": 3.2699,
        "BZD": 2.0000,
        "CAD": 1.4182,
        "CDF": 2856.7620,
        "CHF": 0.8997,
        "CLP": 946.3948,
        "CNY": 7.2626,
        "COP": 4127.8455,
        "CRC": 507.0750,
        "CUP": 24.0000,
        "CVE": 105.1179,
        "CZK": 23.8700,
        "DJF": 177.7210,
        "DKK": 7.1119,
        "DOP": 62.0869,
        "DZD": 135.3706,
        "EGP": 50.6290,
        "ERN": 15.0000,
        "ETB": 126.2459,
        "EUR": 0.9533,
        "FJD": 2.2940,
        "FKP": 0.7948,
        "FOK": 7.1120,
        "GBP": 0.7948,
        "GEL": 2.8302,
        "GGP": 0.7948,
        "GHS": 15.4508,
        "GIP": 0.7948,
        "GMD": 72.6046,
        "GNF": 8589.0144,
        "GTQ": 7.7216,
        "GYD": 209.2593,
        "HKD": 7.7837,
        "HNL": 25.5206,
        "HRK": 7.1828,
        "HTG": 130.8347,
        "HUF": 383.5426,
        "IDR": 16225.1575,
        "ILS": 3.5481,
        "IMP": 0.7948,
        "INR": 86.7955,
        "IQD": 1307.9508,
        "IRR": 41993.2160,
        "ISK": 140.4283,
        "JEP": 0.7948,
        "JMD": 157.9457,
        "JOD": 0.7090,
        "JPY": 152.3479,
        "KES": 129.2574,
        "KGS": 87.4567,
        "KHR": 4008.1629,
        "KID": 1.5744,
        "KMF": 469.0028,
        "KRW": 1440.3458,
        "KWD": 0.3085,
        "KYD": 0.8333,
        "KZT": 497.5012,
        "LAK": 21867.2622,
        "LBP": 89500.0000,
        "LKR": 295.5196,
        "LRD": 199.3352,
        "LSL": 18.3599,
        "LYD": 4.9073,
        "MAD": 9.9608,
        "MDL": 18.8154,
        "MGA": 4734.8216,
        "MKD": 58.8122,
        "MMK": 2099.5486,
        "MNT": 3439.8970,
        "MOP": 8.0173,
        "MRU": 39.9597,
        "MUR": 46.4371,
        "MVR": 15.4548,
        "MWK": 1736.3946,
        "MXN": 20.3269,
        "MYR": 4.4350,
        "MZN": 63.6976,
        "NAD": 18.3599,
        "NGN": 1509.8070,
        "NIO": 36.7984,
        "NOK": 11.1191,
        "NPR": 138.8791,
        "NZD": 1.7453,
        "OMR": 0.3845,
        "PAB": 1.0000,
        "PEN": 3.7091,
        "PGK": 4.0165,
        "PHP": 57.7773,
        "PKR": 279.0304,
        "PLN": 3.9665,
        "PYG": 7905.2559,
        "QAR": 3.6400,
        "RON": 4.7473,
        "RSD": 111.7081,
        "RUB": 91.0874,
        "RWF": 1405.5288,
        "SAR": 3.7500,
        "SBD": 8.6689,
        "SCR": 14.4355,
        "SDG": 459.0793,
        "SEK": 10.6997,
        "SGD": 1.3398,
        "SHP": 0.7948,
        "SLE": 22.8772,
        "SLL": 22877.1788,
        "SOS": 571.5471,
        "SRD": 35.4328,
        "SSP": 4391.5735,
        "STN": 23.3563,
        "SYP": 12933.0491,
        "SZL": 18.3599,
        "THB": 33.6413,
        "TJS": 10.9222,
        "TMT": 3.5008,
        "TND": 3.1727,
        "TOP": 2.3859,
        "TRY": 36.2290,
        "TTD": 6.7863,
        "TVD": 1.5744,
        "TWD": 32.6576,
        "TZS": 2592.2504,
        "UAH": 41.5989,
        "UGX": 3674.9872,
        "UYU": 43.2704,
        "UZS": 12992.6998,
        "VES": 62.0708,
        "VND": 25400.2138,
        "VUV": 123.0591,
        "WST": 2.8244,
        "XAF": 625.3371,
        "XCD": 2.7000,
        "XDR": 0.7614,
        "XOF": 625.3371,
        "XPF": 113.7616,
        "YER": 247.9730,
        "ZAR": 18.3601,
        "ZMW": 28.1645,
        "ZWL": 26.4365,
    ]
}
#endif
