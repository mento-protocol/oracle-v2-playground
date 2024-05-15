// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {RedstoneConsumerNumericBase, NumericArrayLib} from "redstone/contracts/core/RedstoneConsumerNumericBase.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IOracles} from "./interfaces/IOracles.sol";
import {OracleValue, OracleValueLib} from "./lib/OracleValueLib.sol";

// TODO: reenable some/all of these once code written
// solhint-disable no-empty-blocks, gas-struct-packing, named-parameters-mapping
contract Oracles is IOracles, RedstoneConsumerNumericBase {
    using OracleValueLib for OracleValue;

    // prettier-ignore
    struct RateFeed {
        /// @dev A cyclic buffer of the 100 most recent price reports.
        /// @dev A price is an unwrapped OracleValue converted to uint256.
        uint256[100] latestPrices;

        /// @dev Tightly packed rate feed details fitting into a single storage slot.
        RateFeedDetails details;
    }

    // prettier-ignore
    // Designed to fit within 1 storage slot.
    struct RateFeedDetails {
        /**********************/
        /*  Rate Feed Config  */
        /**********************/

        /// @dev Number of the most recent price values to average over.
        uint8 priceWindowSize;

        /// @dev The maximal allowed deviation between reported prices within a batch, expressed as a factor < 1.
        uint16 allowedDeviation;

        /// @dev The minimal number of data providers that need to have reported a value in the last report.
        uint8 quorum;

        /// @dev The minimal number of data providers that need to be certain of their value.
        uint8 certaintyThreshold;

        /// @dev The allowed age of a report before it is considered stale, in seconds.
        uint16 allowedStaleness;


        /**********************/
        /*  Rate Feed Values  */
        /**********************/

        /// @dev Index of the most recently reported price.
        uint8 latestPriceIndex;

        /// @dev True if the buffer of the 100 most recent prices has been filled up at least once.
        bool bufferFull;

        /// @dev Sum of the last `priceWindowSize` prices.
        OracleValue priceWindowSum;

        /// @dev Average of the last `priceWindowSize` prices (i.e. `priceWindowSum / priceWindowSize`).
        OracleValue priceWindowAverage;

        /// @dev Timestamp of the latest price report.
        uint40 latestTimestamp;

        /// @dev A bitmask of the following validity flags:
        /// 0x001 - isFresh => the last price report is fresh
        /// 0x010 - isCertain => at least `certaintyThreshold` data providers are certain of their price report
        /// 0x100 - isWithinAllowedDeviation => the latest price is within the allowed deviation.
        uint8 validityFlags;
    }

    /// @dev Set of supported rate feed IDs.
    EnumerableSet.AddressSet private _rateFeedIds;

    /// @dev mapping from rateFeedId to a set of data provider addresses allowed to report prices for `rateFeedId`.
    mapping(address rateFeedId => EnumerableSet.AddressSet dataProviders)
        private _rateFeedProviders;

    /// @dev Mapping from rateFeedId to a rateFeed containing price medians and metadata.
    mapping(address rateFeedId => RateFeed rateFeed) private _rateFeeds;

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

    // TODO: This is a placeholder for the actual implementation based on the 2023 PoC.
    // solhint-disable-next-line max-line-length
    // https://github.com/redstone-finance/redstone-evm-examples/blob/mento-v2-oracles-poc/contracts/mento-v2-oracles/MentoV2Oracles.sol
    function report(address rateFeedId) external {
        _currentlyUpdatedRateFeedId = rateFeedId;
        RateFeed storage rateFeed = _rateFeeds[rateFeedId];

        // Extracts values from calldata via assembly
        uint256 redstoneValue = getOracleNumericValueFromTxMsg(
            bytes32(uint256(uint160(rateFeedId)))
        );
        rateFeed.details.priceWindowSum = OracleValueLib.fromRedStoneValue(
            redstoneValue
        );

        // TODO: We still would need to decide how to select the latest data timestamp
        // Because currently we assume providers provide the same timestamp
        // If not - we need to discuss the way to calculate its aggregated value (e.g. median or min)
        // TODO: naive uint40 conversion to satisfy compiler, needs to be done properly
        rateFeed.details.latestTimestamp = uint40(
            extractTimestampsAndAssertAllAreEqual()
        );
    }

    function markStale(address rateFeedId) external {}

    function setPriceWindowSize(
        address rateFeedId,
        uint8 priceWindowSize
    ) external {}

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
        uint16 allowedStalenessInSeconds
    ) external {}

    function addRateFeed(
        address rateFeedId,
        uint8 priceWindowSize,
        uint16 allowedDeviation,
        uint8 quorum,
        uint8 certaintyThreshold,
        uint16 allowedStalenessInSeconds,
        address[] calldata dataProviders
    ) external {}

    function removeRateFeed(address rateFeedId) external {}

    function addDataProvider(address rateFeedId, address provider) external {}

    function removeDataProvider(
        address rateFeedId,
        address provider
    ) external {}

    function getExchangeRateFor(
        address rateFeedId
    )
        external
        view
        returns (
            uint256 numerator,
            uint256 denominator,
            uint40 lastUpdateTimestamp
        )
    {}

    function getExchangeRateAsUint64(
        address rateFeedId
    ) external view returns (uint64 exchangeRate) {}

    function rateFeedInfo(
        address rateFeedId
    ) external view returns (uint64 exchangeRate, uint8 validityFlags) {
        RateFeedDetails storage details = _rateFeeds[rateFeedId].details;
        return (details.priceWindowAverage.unwrap(), details.validityFlags);
    }

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
            uint16 allowedStaleness
        )
    {
        RateFeedDetails memory details = _rateFeeds[rateFeedId].details;
        return (
            details.priceWindowSize,
            details.allowedDeviation,
            details.quorum,
            details.certaintyThreshold,
            details.allowedStaleness
        );
    }

    /**************************************/
    /*                                    */
    /*  RedStone Base Contract Overrides  */
    /*                                    */
    /**************************************/
    // solhint-disable-next-line max-line-length
    // From Alex's original Oracles PoC: https://github.com/redstone-finance/redstone-evm-examples/blob/mento-v2-oracles-poc/contracts/mento-v2-oracles/MentoV2Oracles.sol
    // TODO: Reimplement based on latest design

    function getUniqueSignersThreshold()
        public
        view
        virtual
        override
        returns (uint8 quorum)
    {
        return _rateFeeds[_currentlyUpdatedRateFeedId].details.quorum;
    }

    function validateTimestamp(
        uint256 receivedTimestampMilliseconds
    ) public view override {
        uint256 receivedTimestampSeconds = receivedTimestampMilliseconds / 1000;
        RateFeed storage rateFeed = _rateFeeds[_currentlyUpdatedRateFeedId];
        uint256 previousDataTimestampSeconds = rateFeed.details.latestTimestamp;
        uint256 minAllowedTimestampForNewDataInSeconds = previousDataTimestampSeconds +
                rateFeed.details.allowedStaleness;

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
        RateFeed storage rateFeed = _rateFeeds[_currentlyUpdatedRateFeedId];

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

        if (certainties < rateFeed.details.certaintyThreshold) {
            revert CertaintyThresholdNotReached(
                certainties,
                rateFeed.details.certaintyThreshold
            );
        }

        if ((maxVal - minVal) > rateFeed.details.allowedDeviation) {
            revert MinAndMaxValuesDeviateTooMuch(minVal, maxVal);
        }

        // In this implementation, we do not require sorted values, but we can add it
        return NumericArrayLib.pickMedian(values);
    }

    /// @notice Check each provider is a member of _rateFeedProviders[rateFeedId], revert if not.
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

    /********************************************************/
    /*           FOR BACKWARDS-COMPATIBILITY ONLY           */
    /* The below functions are only required for backwards- */
    /* compatibility with the old SortedOracles interface.  */
    /*     Once we fully retire it, we can remove them.     */
    /********************************************************/
    // solhint-disable ordering
    function medianRate(
        address rateFeedId
    ) external view returns (uint256 numerator, uint256 denominator) {}

    function medianTimestamp(
        address rateFeedId
    ) external view returns (uint256 timestamp) {}

    function numRates(
        address rateFeedId
    ) external view returns (uint256 _numRates) {}

    function isOldestReportExpired(
        address rateFeedId
    ) external view returns (bool isExpired, address zeroAddress) {}
}
