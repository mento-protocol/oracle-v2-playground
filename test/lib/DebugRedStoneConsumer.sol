// SPDX-License-Identifier: UNLICENSED
// solhint-disable func-name-mixedcase, gas-strict-inequalities, ordering
pragma solidity ^0.8.24;

import {RedstoneConsumerNumericBase} from "redstone/contracts/core/RedstoneConsumerNumericBase.sol";

contract DebugRedStoneConsumer is RedstoneConsumerNumericBase {
    address constant ADDRESS_1 = 0x19E7E376E7C213B7E7e7e46cc70A5dD086DAff2A;
    address constant ADDRESS_2 = 0x1563915e194D8CfBA1943570603F7606A3115508;
    uint256[] public receivedValues;
    uint256 public receivedTimestamp;
    uint8 public signersThreshold;

    function report(bytes32 rateFeedId) public returns (uint256) {
        receivedTimestamp = extractTimestampsAndAssertAllAreEqual();
        return getOracleNumericValueFromTxMsg(rateFeedId);
    }

    function getAuthorisedSignerIndex(address receivedSigner) public pure override returns (uint8) {
        if (receivedSigner == ADDRESS_1) {
            return 1;
        } else if (receivedSigner == ADDRESS_2) {
            return 2;
        }
    }

    function setUniqueSignersThreshold(uint8 threshold) public {
        signersThreshold = threshold;
    }

    function getUniqueSignersThreshold() public view override returns (uint8) {
        return signersThreshold;
    }

    function aggregateValues(uint256[] memory values) public pure override returns (uint256) {
        // VERY hacky way of returning up to 4 of the received uint64 values
        // while keeping this function `view`.
        uint256 result = 0;
        for (uint256 i = 0; i < values.length && i < 4; i++) {
            result <<= 64;
            result |= values[i];
        }
        return result;
    }

    function parseAggregatedValue(
        uint256 value
    ) public pure returns (uint64[4] memory) {
        uint64[4] memory values;
        for (uint64 i = 0; i < 4; i++) {
            values[i] = uint64(value % 2**64);
            value >>= 64;
        }
        return values;
    }
}
