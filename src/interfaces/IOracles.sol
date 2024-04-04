// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

interface IOracles {
    /**
     * @notice Used to submit a new batch of signed price data.
     * @param rateFeedId The rate feed for which prices are being submitted.
     * @dev This function expects additional calldata in the form of a RedStone
     * packed data payload, containing the signed reports from oracle node
     * operators.
     * See RedStone docs:
     * https://docs.redstone.finance/docs/smart-contract-devs/how-it-works#data-packing-off-chain-data-encoding
     */
    function report(address rateFeedId) external;

    /**
     * @notice Sets `hasFreshness` to `false` if the most recent report has
     * become outdated.
     * @param rateFeedId The rate feed to mark stale.
     */
    function markStale(address rateFeedId) external;

    /**
     * @notice Sets the window size over which a rate feed's medians will be
     * averaged.
     * @param rateFeedId The rate feed being configured.
     * @param windowSize The number of most recent medians to average over for
     * the final reported median.
     * @dev Only callable by the owner.
     */
    function setWindowSize(address rateFeedId, uint8 windowSize) external;

    /**
     * @notice Sets the allowed deviation for a rate feed.
     * @param rateFeedId The rate feed being configured.
     * @param allowedDeviation The maximal multiplicative deviation allowed
     * between two values in a report batch, expressed as the numerator of a
     * fraction over uint16.max.
     * @dev Only callable by the owner.
     */
    function setAllowedDeviation(
        address rateFeedId,
        uint16 allowedDeviation
    ) external;

    /**
     * @notice Sets the required quorum for a rate feed.
     * @param rateFeedId The rate feed being configured.
     * @param quorum The minimum number of individual reporters that need to be
     * present in a report batch.
     * @dev Only callable by the owner.
     */
    function setQuorum(address rateFeedId, uint8 quorum) external;

    /**
     * @notice Sets the certainty threshold for a rate feed.
     * @param rateFeedId The rate feed being configured.
     * @param certaintyThreshold The minimum number of values that need to be
     * denoted as certain in a batch for it to be considered valid.
     * @dev Only callable by the owner.
     */
    function setCertaintyThreshold(
        address rateFeedId,
        uint8 certaintyThreshold
    ) external;

    /**
     * @notice Sets the allowed staleness for a rate feed.
     * @param rateFeedId The rate feed being configured.
     * @param allowedStaleness The number of seconds before a report becomes
     * considered stale and no longer valid.
     * @dev Only callable by the owner.
     */
    function setAllowedStaleness(
        address rateFeedId,
        uint16 allowedStaleness
    ) external;

    /**
     * @notice Adds a new supported rate feed.
     * @param rateFeedId The new rate feed's ID.
     * @dev Only callable by the owner.
     */
    function addRateFeed(address rateFeedId) external;

    /**
     * @notice Removes a rate feed.
     * @param rateFeedId The rate feed's ID.
     * @dev Only callable by the owner.
     */
    function removeRateFeed(address rateFeedId) external;

    /**
     * @notice Adds a new trusted provider, i.e. a new offchain oracle node
     * operator.
     * @param rateFeedId The rate feed for which the new provider is allowed to
     * report.
     * @param provider The new provider's address.
     * @dev Only callable by the owner.
     */
    function addProvider(address rateFeedId, address provider) external;

    /**
     * @notice Removes a provider from being allowed to report of a rate feed.
     * @param rateFeedId The rate feed for which the provider was allowed to
     * report.
     * @param provider The provider's address.
     * @dev Only callable by the owner.
     */
    function removeProvider(address rateFeedId, address provider) external;

    /**
     * @notice Returns the median rate as a numerator and denominator, the
     * denominator being fixed to 1e24.
     * @param rateFeedId The rate feed whose median rate is queried.
     * @return numerator The numerator of the median rate.
     * @return denominator The denominator of the median rate, fixed at 1e24.
     * @dev The denominator is chosen based on Celo's FixidityLib, which is used
     * in the legacy SortedOracles oracle. See here:
     * https://github.com/celo-org/celo-monorepo/blob/master/packages/protocol/contracts/common/FixidityLib.sol#L26
     * To get the rate in this contract's internal format, and save a bit of gas
     * on the consumer side, see `medianRateUint64`.
     */
    function medianRate(
        address rateFeedId
    ) external view returns (uint256 numerator, uint256 denominator);

    /**
     * @notice Returns the median rate as a fixed fraction with 8 decimal digits
     * after the decimal point.
     * @param rateFeedId The rate feed whose median rate is queried.
     * @return medianRate The median rate, expressed as the numerator of a fraction
     * over 1e8.
     */
    function medianRateUint64(
        address rateFeedId
    ) external view returns (uint64 medianRate);

    /**
     * @notice Returns the median rate and validity flags.
     * @param rateFeedId The rate feed being queried.
     * @return medianRate The median rate.
     * @return validityFlags The feed's current validity flags, packed into a uint8.
     * Specifically:
     * - Bit 0 (least significant): `hasFresnhess`
     * - Bit 1: `hasQuorum`
     * - Bit 2: `hasCertainty`
     * - Bits 3-7: unused
     */
    function rateInfo(
        address rateFeedId
    ) external view returns (uint64 medianRate, uint8 validityFlags);
}
