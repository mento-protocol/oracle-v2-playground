// SPDX-License-Identifier: GPL-3.0-or-later
// NOTE: Disabled ordering rule to allow for more logical grouping of functions starting with the most important ones.
/* solhint-disable max-line-length, ordering */
pragma solidity ^0.8.24;

/**
 * @title IOracles Interface
 *
 * KEY ENTITIES
 * @dev Owner         = Mento Governance
 * @dev Data Provider = Oracle node operator reporting individual price points to RedStone's DDL.
 * @dev DDL           = RedStone's Data Distribution Layer, an off-chain caching service for price data.
 * @dev Relayer       = Entities batching together indvidual price points from the DDL and submitting them on-chain.
 *
 *
 * KEY CONCEPTS
 * @dev Rate Feed     = A specific price feed, e.g. "CELO/USD".
 * @dev Rate Feed ID  = A unique rate feed identifier calculated as address(uint160(uint256(keccak256("CELOUSD")))).
 *
 * @dev Price Value   = A single price point from a data provider for a single rate feed.
 * @dev Price Report  = A batch of multiple price values from different data providers for a single rate feed.
 * @dev Price Median  = The median price value from a price report. For every rate feed, we store the 100 latest medians in a cyclic buffer
 * @dev Price Window  = The most recent n median prices in the cyclic buffer (n = `priceWindowSize`)
 * @dev Average Price = The final price being returned to rate feed consumers. This is the average of the last `priceWindowSize` median prices in the cyclic buffer.
 *
 * @dev Validity Flags    = A set of boolean flags that indicate the current state of a rate feed: `isCertain` | `isFresh` | `isWithinAllowedDeviation`
 * @dev Certainty         = Each price value is accompanied by a certainty score (boolean). This score is determined by
 *                          the data provider and indicates their confidence in the reported value. If a more than
 *                          `certaintyThreshold` providers are certain about a price value, a price report is considered
 *                          "certain" in our contract. Breakers can be triggered if a report is not certain.
 * @dev Freshness         = A price report is considered fresh if the latest price value is not older than `allowedStalenessInSeconds`.
 * @dev Allowed Deviation = The maximum allowed deviation between the lowest and highest price values in a price report.
 */
interface IOracles {
    /**
     * @notice Main input function through which relayers submit new batched price reports on-chain
     * @param rateFeedId The rate feed for which prices are being submitted.
     * @dev This function expects additional calldata in form of a RedStone data package payload,
     *      which includes signed and timestamped price points from oracle node operators. The
     *      calldata payload is extracted in assembly, hence no function param for the price data.
     *      See RedStone docs:
     *      https://docs.redstone.finance/docs/smart-contract-devs/how-it-works#data-packing-off-chain-data-encoding
     * @dev Relayers must ensure that each provider is allowed to report for the rate feed.
     *      If any data provider signature is invalid, the function will revert.
     * @dev Relayers must sort the price values from lowest to highest. If not, the function will revert.
     */
    function report(address rateFeedId) external;

    /**
     * @notice Main output function returning the current price for a given rate feed
     * @dev The price being returned is the average of the latest `priceWindowSize` median prices in the rate feed's cyclic price buffer.
     * @param rateFeedId           The rate feed to fetch the latest price for
     * @return numerator           The numerator of the price.
     * @return denominator         The denominator of the price, fixed at 1e24.
     * @return lastUpdateTimestamp The timestamp of the last price update.
     * @dev The denominator was chosen based on Celo's FixidityLib, which is used in the legacy SortedOracles oracle. See here:
     *      https://github.com/celo-org/celo-monorepo/blob/master/packages/protocol/contracts/common/FixidityLib.sol#L26
     *      To get the price in this contract's internal format, and save a bit of gas on the consumer side, see `getExchangeRateAsUint64()`.
     */
    function getExchangeRateFor(
        address rateFeedId
    )
        external
        view
        returns (
            uint256 numerator,
            uint256 denominator,
            uint40 lastUpdateTimestamp
        );

    /**
     * @notice Adds a new supported rate feed.
     * @param rateFeedId                The new rate feed's ID, calculated as, i.e.: `address(uint160(uint256(keccak256("CELOUSD"))))`
     * @param priceWindowSize           The number of most recent median prices to average over for the final reported price.
     * @param allowedDeviation          The maximum allowed deviation between the lowest and highest price values in a price report
     * @param quorum                    The minimum number of values per report.
     * @param certaintyThreshold        The minimum number of certain values per report.
     * @param allowedStalenessInSeconds The allowed staleness in seconds.
     * @param dataProviders             The initial set of data providers for the new rate feed.
     * @dev Only callable by the owner.
     */
    function addRateFeed(
        address rateFeedId,
        uint8 priceWindowSize,
        uint16 allowedDeviation,
        uint8 quorum,
        uint8 certaintyThreshold,
        uint16 allowedStalenessInSeconds,
        address[] calldata dataProviders
    ) external;

    /**
     * @notice Removes a rate feed.
     * @param rateFeedId The rate feed's ID.
     * @dev Only callable by the owner.
     */
    function removeRateFeed(address rateFeedId) external;

    /**
     * @notice Adds a new trusted data provider, i.e. an oracle node operator
     * @param rateFeedId The rate feed for which the new data provider is allowed to report.
     * @param provider   The new data provider's address.
     * @dev Only callable by the owner.
     */
    function addDataProvider(address rateFeedId, address provider) external;

    /**
     * @notice Removes a data provider from being allowed to report for a rate feed.
     * @param rateFeedId The rate feed from which the data provider should be removed
     * @param provider   The data provider's address.
     * @dev Only callable by the owner.
     */
    function removeDataProvider(address rateFeedId, address provider) external;

    /**
     * @notice Sets validity flag `isFresh` to `0` for a rate feed if the most recent report has become outdated.
     * @param rateFeedId The rate feed to mark stale.
     */
    function markStale(address rateFeedId) external;

    /**
     * @notice Sets the price window size over which a rate feed's median prices will be averaged.
     * @param rateFeedId The rate feed being configured.
     * @param priceWindowSize The number of most recent median prices to average over for the final reported price.
     * @dev For example, if `priceWindowSize` was 3 and the latest 5 median prices were [1, 3, 2, 3, 4], then we would
     *      average over the last three values [2, 3, 4] to get the final reported average price of (2 + 3 + 4) / 3 = 3
     * @dev Only callable by the owner.
     */
    function setPriceWindowSize(
        address rateFeedId,
        uint8 priceWindowSize
    ) external;

    /**
     * @notice Sets the allowed price deviation between the lowest and highest price values in a report for a rate feed.
     * @param rateFeedId The rate feed being configured.
     * @param allowedDeviation The difference between the lowest and highest value in a price report.
     *        Expressed as the numerator of a fraction over uint16.max (65535). I.e., if allowedDeviation was 10_000,
     *        then the difference between price values can't be greater than 1_000 / 65_535 = 0.015259... ≈ 1.526%
     * @dev Only callable by the owner.
     */
    function setAllowedDeviation(
        address rateFeedId,
        uint16 allowedDeviation
    ) external;

    /**
     * @notice Sets the required quorum of data providers per price report for a rate feed.
     * @param rateFeedId The rate feed being configured.
     * @param quorum The minimum number of individual data providers that need to have reported a price in a batch.
     * @dev Only callable by the owner.
     */
    function setQuorum(address rateFeedId, uint8 quorum) external;

    /**
     * @notice Sets the certainty threshold for a rate feed.
     * @param rateFeedId The rate feed being configured.
     * @param certaintyThreshold The minimum number of price values in a batch that need to be
     *        denoted as "certain" by the data providers for the report to be considered valid.
     * @dev Only callable by the owner.
     */
    function setCertaintyThreshold(
        address rateFeedId,
        uint8 certaintyThreshold
    ) external;

    /**
     * @notice Sets the allowed staleness for a rate feed.
     * @param rateFeedId The rate feed being configured.
     * @param allowedStalenessInSeconds The number of seconds before a report is considered stale and no longer valid.
     * @dev Only callable by the owner.
     */
    function setAllowedStaleness(
        address rateFeedId,
        uint16 allowedStalenessInSeconds
    ) external;

    /**
     * @notice Returns the price as a fixed fraction with 8 decimal digits after the decimal point.
     * @dev Gas-optimized version of `getExchangeRateFor()`. Use this function if you only need the price as a uint64.
     * @param rateFeedId The rate feed being queried.
     * @return exchangeRate The price, expressed as the numerator of a fraction over 1e8 as a fixed denominator.
     */
    function getExchangeRateAsUint64(
        address rateFeedId
    ) external view returns (uint64 exchangeRate);

    /**
     * @notice Returns the latest price and validity flags.
     * @param rateFeedId The rate feed being queried.
     * @return medianRate The median rate.
     * @return validityFlags The feed's current validity flags, packed into a uint8.
     * Specifically:
     * - Bit 0 (least significant): `isFresh`
     * - Bit 1: `isCertain`
     * - Bit 2: `isWithinAllowedDeviation`
     * - Bits 3-7: unused
     */
    function rateFeedInfo(
        address rateFeedId
    ) external view returns (uint64 medianRate, uint8 validityFlags);

    /**
     * @notice Returns the current configuration parameters for a rate feed.
     * @param rateFeedId The rate feed being queried.
     * @return priceWindowSize           The number of most recent median prices to average over for the final reported price.
     * @return allowedDeviation          The maximum allowed deviation between the lowest and highest price values in a price report
     * @return quorum                    The minimum number of values per report.
     * @return certaintyThreshold        The minimum number of certain values per report.
     * @return allowedStalenessInSeconds The allowed staleness in seconds.
     */
    function rateFeedConfig(
        address rateFeedId
    )
        external
        view
        returns (
            uint8 priceWindowSize,
            uint16 allowedDeviation,
            uint8 quorum,
            uint8 certaintyThreshold,
            uint16 allowedStalenessInSeconds
        );

    /********************************************************/
    /*           FOR BACKWARDS-COMPATIBILITY ONLY           */
    /* The below functions are only required for backwards- */
    /* compatibility with the old SortedOracles interface.  */
    /*     Once we fully retire it, we can remove them.     */
    /********************************************************/

    /**
     * @notice Passthrough function that calls the new main interface `getExchangeRateFor()`
     * @dev We're ignoring the `lastUpdateTimestamp` as this wasn't part of the old SortedOracles interface
     * @param rateFeedId   The rate feed to fetch the latest price for
     * @return numerator   The numerator of the price
     * @return denominator The denominator of the price, fixed at 1e24.
     */
    function medianRate(
        address rateFeedId
    ) external view returns (uint256 numerator, uint256 denominator);

    /**
     * @notice Returns the timestamp of the latest price report.
     * @dev Uses the new interface's `latestTimestamp` cast to uint256
     * @param rateFeedId The rate feed being queried.
     * @return timestamp The timestamp of the latest price report for the specified rateFeedId.
     */
    function medianTimestamp(
        address rateFeedId
    ) external view returns (uint256 timestamp);

    /**
     * @notice Returns the rate feed's quorum as a proxy for the number of price values in the last report.
     * @param rateFeedId The rateFeed being queried.
     * @return _numRates The number of reported price values in the last report.
     */
    function numRates(
        address rateFeedId
    ) external view returns (uint256 _numRates);

    /**
     * @notice Checks if the latest price report for a rate feed is stale.
     * @param rateFeedId   The rate feed being queried.
     * @return isExpired   A boolean returning the inverse of the `isFresh` validity flag from the new interface.
     * @return zeroAddress We no longer store the oldest report's oracle address, so we return a zero address.
     *                     This should be safe because SortedOracle consumers only care about the `isExpired` flag.
     */
    function isOldestReportExpired(
        address rateFeedId
    ) external view returns (bool isExpired, address zeroAddress);
}
