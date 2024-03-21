// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {SortedLinkedListWithMedian} from "../linked-lists/SortedLinkedListWithMedian.sol";

interface ISortedOracles {
    /**
     * @notice Adds a new Oracle for a specified rate feed.
     * @param token The rateFeedId that the specified oracle is permitted to report.
     * @param oracleAddress The address of the oracle.
     */
    function addOracle(address token, address oracleAddress) external;

    /**
     * @notice Removes an Oracle from a specified rate feed.
     * @param token The rateFeedId that the specified oracle is no longer permitted to report.
     * @param oracleAddress The address of the oracle.
     * @param index The index of `oracleAddress` in the list of oracles.
     */
    function removeOracle(
        address token,
        address oracleAddress,
        uint256 index
    ) external;

    /**
     * @notice Updates an oracle value and the median.
     * @param token The rateFeedId for the rate that is being reported.
     * @param value The number of stable asset that equate to one unit of collateral asset, for the
     *              specified rateFeedId, expressed as a fixidity value.
     * @param lesserKey The element which should be just left of the new oracle value.
     * @param greaterKey The element which should be just right of the new oracle value.
     * @dev Note that only one of `lesserKey` or `greaterKey` needs to be correct to reduce friction.
     */
    function report(
        address token,
        uint256 value,
        address lesserKey,
        address greaterKey
    ) external;

    /**
     * @notice Removes a report that is expired.
     * @param token The rateFeedId of the report to be removed.
     * @param n The number of expired reports to remove, at most (deterministic upper gas bound).
     */
    function removeExpiredReports(address token, uint256 n) external;

    /**
     * @notice Check if last report is expired.
     * @param token The rateFeedId of the reports to be checked.
     * @return isExpired A bool indicating if the last report is expired.
     * @return oracleAddressOfOldestReport Oracle address of the last report.
     */
    function isOldestReportExpired(
        address token
    )
        external
        view
        returns (bool isExpired, address oracleAddressOfOldestReport);

    /**
     * @notice Returns the number of rates that are currently stored for a specifed rateFeedId.
     * @param token The rateFeedId for which to retrieve the number of rates.
     * @return numRates The number of reported oracle rates stored for the given rateFeedId.
     */
    function numRates(address token) external view returns (uint256 numRates);

    /**
     * @notice Returns the median of the currently stored rates for a specified rateFeedId.
     * @param token The rateFeedId of the rates for which the median value is being retrieved.
     * @return median The median exchange rate for rateFeedId.
     * @return fixidity
     */
    function medianRate(
        address token
    ) external view returns (uint256 median, uint256 fixidity);

    /**
     * @notice Gets all elements from the doubly linked list.
     * @param token The rateFeedId for which the collateral asset exchange rate is being reported.
     * @return keys Keys of an unpacked list of elements from largest to smallest.
     * @return values Values of an unpacked list of elements from largest to smallest.
     * @return relations Relations of an unpacked list of elements from largest to smallest.
     */
    function getRates(
        address token
    )
        external
        view
        returns (
            address[] memory keys,
            uint256[] memory values,
            SortedLinkedListWithMedian.MedianRelation[] memory relations
        );

    /**
     * @notice Returns the number of timestamps.
     * @param token The rateFeedId for which the collateral asset exchange rate is being reported.
     * @return numTimestamps The number of oracle report timestamps for the specified rateFeedId.
     */
    function numTimestamps(
        address token
    ) external view returns (uint256 numTimestamps);

    /**
     * @notice Returns the median timestamp.
     * @param token The rateFeedId for which the collateral asset exchange rate is being reported.
     * @return timestamp The median report timestamp for the specified rateFeedId.
     */
    function medianTimestamp(
        address token
    ) external view returns (uint256 timestamp);

    /**
     * @notice Returns the list of oracles for a speficied rateFeedId.
     * @param token The rateFeedId whose oracles should be returned.
     * @return oraclesList A list of oracles for the given rateFeedId.
     */
    function getOracles(
        address token
    ) external view returns (address[] memory oraclesList);

    /**
     * @notice Gets all elements from the doubly linked list.
     * @param token The rateFeedId for which the collateral asset exchange rate is being reported.
     * @return keys Keys of nn unpacked list of elements from largest to smallest.
     * @return values Values of an unpacked list of elements from largest to smallest.
     * @return relations Relations of an unpacked list of elements from largest to smallest.
     */
    function getTimestamps(
        address token
    )
        external
        view
        returns (
            address[] memory keys,
            uint256[] memory values,
            SortedLinkedListWithMedian.MedianRelation[] memory relations
        );

    /**
     * @notice Returns the expiry for specified rateFeedId if it exists, if not the default is returned.
     * @param token The rateFeedId.
     * @return expirySeconds The report expiry in seconds.
     */
    function getTokenReportExpirySeconds(
        address token
    ) external view returns (uint256 expirySeconds);
}
