// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import {RedstoneConsumerNumericBase, NumericArrayLib} from "redstone/contracts/core/RedstoneConsumerNumericBase.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {OracleValueLib, OracleValue} from "./lib/OracleValueLib.sol";

// Martin's original OracleValueLib: https://github.com/mento-protocol/OracleValueLib
// solhint-disable-next-line max-line-length
// Alex's original Oracles PoC: https://github.com/redstone-finance/redstone-evm-examples/blob/mento-v2-oracles-poc/contracts/mento-v2-oracles/MentoV2Oracles.sol

// solhint-disable gas-struct-packing
contract OraclesV2 is RedstoneConsumerNumericBase {
    using OracleValueLib for OracleValue;

    struct OracleBuffer {
        /// @dev the cyclic buffer of most recent medians.
        // A median is an unwrapped OracleValue converted to uint256
        uint256[100] medians;
        OracleBufferInfo info;
    }

    struct OracleBufferInfo {
        /// @dev index of the most recently reported median.
        uint8 lastIndex;
        /// @dev the size of the window to average over.
        uint8 windowSize;
        /// @dev the buffer has been filled up at least once.
        bool bufferFull;
        /// @dev sum of the last `windowSize` values.
        OracleValue windowSum;
        /// @dev average of the last `windowSize` values (i.e. `windowSum / windowSize`).
        OracleValue windowAverage;
        /// @dev timestamp of the latest report.
        uint40 latestTimestamp;
        bool hasFreshness;
        bool hasQuorum;
        bool hasCertainty;
        /// @dev the maximal deviation between providers’ values within a batch allowed, expressed as a factor < 1.
        uint16 allowedDeviation;
        /// @dev the minimal number of providers that need to be included in a report.
        uint8 quorum;
        /// @dev the minimal number of providers that need to be certain of their value.
        uint8 certaintyThreshold;
        /// @dev the allowed age of a report before it is considered stale, in seconds.
        uint16 allowedStaleness;
    }

    // Set of supported rate feeds.
    EnumerableSet.AddressSet private _rateFeedIds;

    // mapping from _rateFeedIds to a set of provider addresses allowed to report values for the given rate feed.
    mapping(address rateFeedId => EnumerableSet.AddressSet whitelistedRelayers)
        private _rateFeedProviders;

    /// @dev mapping from rate feed id to the cyclic buffer of most recent medians.
    mapping(address rateFeedId => OracleBuffer buffer) private _rateFeeds;

    address internal _currentlyUpdatedRateFeedId;

    error InvalidProviderForRateFeed(address rateFeedId, address provider);
    error TimestampFromFutureIsNotAllowed(
        uint256 receivedTimestampMilliseconds,
        uint256 blockTimestamp
    );
    error DataIsNotFresh(
        uint256 receivedTimestampMilliseconds,
        uint256 minAllowedTimestampForNewDataSeconds
    );
    error CertaintyThresholdNotReached(
        uint8 receivedCertainties,
        uint8 certaintyThreshold
    );
    error MinAndMaxValuesDeviateTooMuch(uint256 minVal, uint256 maxVal);

    /// @notice Main oracle function through which relayers submit new price data on-chain
    /// @dev Receives a RedStone calldata payload, which includes signed and timestamped reports.
    ///      The calldata payload is extracted in assembly, hence no function param for the price data.
    /// @dev The relayer is expected to ensure that each provider is allowed to report for the rate feed.
    ///      If not, the function will revert.
    /// @dev The relayer is expected to sort the price values from lowest to highest.
    ///      If not, the function will revert.
    function report(address rateFeedId) public {
        _currentlyUpdatedRateFeedId = rateFeedId;
        OracleBuffer storage rateFeed = _rateFeeds[rateFeedId];

        // Extracts values from calldata via assembly
        uint256 redstoneValue = getOracleNumericValueFromTxMsg(
            bytes32(uint256(uint160(rateFeedId)))
        );
        rateFeed.info.windowSum = OracleValueLib.fromRedStoneValue(
            redstoneValue
        );

        // TODO: We still would need to decide how to select the latest data timestamp
        // Because currently we assume providers provide the same timestamp
        // If not - we need to discuss the way to calculate its aggregated value (e.g. median or min)
        // TODO: naive uint40 conversion to satisfy compiler, needs to be done properly
        rateFeed.info.latestTimestamp = uint40(
            extractTimestampsAndAssertAllAreEqual()
        );
    }

    function getUniqueSignersThreshold()
        public
        view
        virtual
        override
        returns (uint8 quorum)
    {
        return _rateFeeds[_currentlyUpdatedRateFeedId].info.quorum;
    }

    function validateTimestamp(
        uint256 receivedTimestampMilliseconds
    ) public view override {
        uint256 receivedTimestampSeconds = receivedTimestampMilliseconds / 1000;
        OracleBuffer storage rateFeed = _rateFeeds[_currentlyUpdatedRateFeedId];
        uint256 previousDataTimestampSeconds = rateFeed.info.latestTimestamp;
        uint256 minAllowedTimestampForNewDataInSeconds = previousDataTimestampSeconds +
                rateFeed.info.allowedStaleness;

        if (
            // solhint-disable gas-strict-inequalities
            receivedTimestampSeconds <= minAllowedTimestampForNewDataInSeconds
        ) {
            revert DataIsNotFresh(
                receivedTimestampMilliseconds,
                minAllowedTimestampForNewDataInSeconds
            );
        }

        if (receivedTimestampSeconds > block.timestamp) {
            revert TimestampFromFutureIsNotAllowed(
                receivedTimestampMilliseconds,
                block.timestamp
            );
        }
    }

    function aggregateValues(
        uint256[] memory valuesWithCertainties
    ) public view virtual override returns (uint256 median) {
        OracleBuffer storage rateFeed = _rateFeeds[_currentlyUpdatedRateFeedId];

        uint256 valuesWithCertaintiesLength = valuesWithCertainties.length;
        uint256[] memory values = new uint256[](valuesWithCertaintiesLength);
        uint8 certainties = 0;
        uint256 maxVal = 0;
        uint256 minVal = type(uint256).max;

        for (uint256 i = 0; i < valuesWithCertaintiesLength; ++i) {
            (bool certainty, uint256 value) = parseValueWithCertainty(
                valuesWithCertainties[i]
            );
            values[i] = value;
            if (certainty) {
                ++certainties;
            }
            if (value > maxVal) {
                maxVal = value;
            }
            if (value < minVal) {
                minVal = value;
            }
        }

        if (certainties < rateFeed.info.certaintyThreshold) {
            revert CertaintyThresholdNotReached(
                certainties,
                rateFeed.info.certaintyThreshold
            );
        }

        if ((maxVal - minVal) > rateFeed.info.allowedDeviation) {
            revert MinAndMaxValuesDeviateTooMuch(minVal, maxVal);
        }

        // In this implementation, we do not require sorted values, but we can add it
        return NumericArrayLib.pickMedian(values);
    }

    /// @notice Check each provider is a member of _rateFeedProviders[rateFeedId], revert if not
    function getAuthorisedSignerIndex(
        address signerAddress
    ) public view virtual override returns (uint8 signerIndex) {
        if (
            !EnumerableSet.contains(
                _rateFeedProviders[_currentlyUpdatedRateFeedId],
                signerAddress
            )
        ) {
            revert InvalidProviderForRateFeed(
                _currentlyUpdatedRateFeedId,
                signerAddress
            );
        }

        // TODO: Replace hardcoding with dynamic signerAddresses
        if (signerAddress == 0x8BB8F32Df04c8b654987DAaeD53D6B6091e3B774) {
            return 0;
        } else if (
            signerAddress == 0xdEB22f54738d54976C4c0fe5ce6d408E40d88499
        ) {
            return 1;
        } else if (
            signerAddress == 0x51Ce04Be4b3E32572C4Ec9135221d0691Ba7d202
        ) {
            return 2;
        } else if (
            signerAddress == 0xDD682daEC5A90dD295d14DA4b0bec9281017b5bE
        ) {
            return 3;
        } else if (
            signerAddress == 0x9c5AE89C4Af6aA32cE58588DBaF90d18a855B6de
        ) {
            return 4;
        } else {
            revert SignerNotAuthorised(signerAddress);
        }
    }

    function parseValueWithCertainty(
        uint256 valueWithCertainty
    ) public pure returns (bool certainty, uint256 value) {
        certainty = valueWithCertainty >= 2 ** 255; // most significant bit
        value = valueWithCertainty & ((2 ** 255) - 1); // 255 least significant bits
    }
}
