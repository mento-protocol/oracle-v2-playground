// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IOracles} from "./interfaces/IOracles.sol";
import {OracleValue, OracleValueLib} from "./lib/OracleValueLib.sol";

contract Oracles is IOracles {
    using OracleValueLib for OracleValue;

    struct OracleBuffer {
        uint256[100] medians;
        OracleBufferInfo bufferInfo;
    }

    struct OracleBufferInfo {
        uint8 lastIndex;
        uint8 windowSize;
        bool bufferFull;

        OracleValue windowSum;
        OracleValue windowAverage;

        uint40 latestTimestamp;

        uint8 validityFlags;

        uint16 allowedDeviation;
        uint8 quorum;
        uint8 certaintyThreshold;
        uint16 allowedStaleness;
    }

    mapping (address => OracleBuffer) rateFeeds;
    function report(address rateFeedId) external {}

    function markStale(address rateFeedId) external {}

    function setWindowSize(address rateFeedId, uint8 windowSize) external {}

    function setAllowedDeviation(
        address rateFeedId,
        uint16 allowedDeviation
    ) external {}

    function setQuorum(address rateFeedId, uint8 quorum) external {}

    function setCertaintyThreshold(
        address rateFeedId,
        uint8 certaintyThreshold
    ) external {}

    function setAllowedStaleness(
        address rateFeedId,
        uint16 allowedStaleness
    ) external {}

    function addRateFeed(
        address rateFeedId,
        uint8 windowSize,
        uint16 allowedDeviation,
        uint8 quorum,
        uint8 certaintyThreshold,
        uint16 allowedStaleness,
        address[] calldata dataProviders
    ) external {}

    function removeRateFeed(address rateFeedId) external {}

    function addDataProvider(address rateFeedId, address provider) external {}

    function removeDataProvider(
        address rateFeedId,
        address provider
    ) external {}

    function medianRate(
        address rateFeedId
    ) external view returns (uint256 numerator, uint256 denominator) {}

    function medianRateUint64(
        address rateFeedId
    ) external view returns (uint64 medianRate) {}

    function rateInfo(
        address rateFeedId
    ) external view returns (uint64 medianRate, uint8 validityFlags) {}

    function rateFeedParameters(address rateFeedId) external view returns (
        uint8 windowSize,
        uint16 allowedDeviation,
        uint8 quorum,
        uint8 certaintyThreshold,
        uint16 allowedStaleness
    ) {
        OracleBufferInfo memory bufferInfo =  rateFeeds[rateFeedId].bufferInfo;
        return (
            bufferInfo.windowSize,
            bufferInfo.allowedDeviation,
            bufferInfo.quorum,
            bufferInfo.certaintyThreshold,
            bufferInfo.allowedStaleness
        );
    }
}
