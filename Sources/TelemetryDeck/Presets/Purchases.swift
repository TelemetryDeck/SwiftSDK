import Foundation

extension TelemetryDeck {
    /// The type of a purchase.
    public enum PurchaseType: String, Sendable {
        case subscription
        case oneTimePurchase = "one-time-purchase"
    }

    /// Sends an event recording a completed purchase.
    public static func purchaseCompleted(
        productID: String,
        type: PurchaseType,
        price: Decimal,
        currencyCode: String,
        countryCode: String? = nil,
        parameters: EventParameters = [:],
        customUserID: String? = nil
    ) async {
        assert(!productID.isEmpty, "productID must not be empty")
        assert(!currencyCode.isEmpty, "currencyCode must not be empty")
        var params = purchaseParameters(productID: productID, type: type, currencyCode: currencyCode, countryCode: countryCode)
        params.merge(parameters)
        await sdkEvent(
            DefaultEvents.Purchase.completed,
            parameters: params,
            floatValue: priceInUSD(price, currencyCode: currencyCode),
            customUserID: customUserID
        )
    }

    /// Sends an event recording when a user converts from a free trial to a paid subscription.
    public static func convertedFromTrial(
        productID: String,
        type: PurchaseType,
        price: Decimal,
        currencyCode: String,
        countryCode: String? = nil,
        parameters: EventParameters = [:],
        customUserID: String? = nil
    ) async {
        assert(!productID.isEmpty, "productID must not be empty")
        assert(!currencyCode.isEmpty, "currencyCode must not be empty")
        var params = purchaseParameters(productID: productID, type: type, currencyCode: currencyCode, countryCode: countryCode)
        params.merge(parameters)
        await sdkEvent(
            DefaultEvents.Purchase.convertedFromTrial,
            parameters: params,
            floatValue: priceInUSD(price, currencyCode: currencyCode),
            customUserID: customUserID
        )
    }

    /// Sends an event recording the start of a free trial.
    ///
    /// No price or `floatValue` is recorded because a free trial has no charge.
    public static func freeTrialStarted(
        productID: String,
        type: PurchaseType,
        currencyCode: String,
        countryCode: String? = nil,
        parameters: EventParameters = [:],
        customUserID: String? = nil
    ) async {
        assert(!productID.isEmpty, "productID must not be empty")
        assert(!currencyCode.isEmpty, "currencyCode must not be empty")
        var params = purchaseParameters(productID: productID, type: type, currencyCode: currencyCode, countryCode: countryCode)
        params.merge(parameters)
        await sdkEvent(DefaultEvents.Purchase.freeTrialStarted, parameters: params, customUserID: customUserID)
    }

    static func purchaseParameters(productID: String, type: PurchaseType, currencyCode: String, countryCode: String?) -> EventParameters {
        var params: [String: String] = [
            DefaultParams.Purchase.type.rawValue: type.rawValue,
            DefaultParams.Purchase.productID.rawValue: productID,
            DefaultParams.Purchase.currencyCode.rawValue: currencyCode,
        ]
        if let countryCode {
            params[DefaultParams.Purchase.countryCode.rawValue] = countryCode
        }
        return EventParameters(params)
    }

    static func priceInUSD(_ price: Decimal, currencyCode: String) -> Double {
        let nativePrice = NSDecimalNumber(decimal: price).doubleValue
        if currencyCode == "USD" {
            return nativePrice
        } else if let rate = currencyCodeToOneUSDExchangeRate[currencyCode] {
            return nativePrice / rate
        } else {
            return 0
        }
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
