// SPDX-License-Identifier: UNLICENSED
// solhint-disable func-name-mixedcase, gas-strict-inequalities, ordering
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {DebugRedStoneConsumer} from "./lib/DebugRedStoneConsumer.sol";
import {RedStonePayload} from "./lib/RedStonePayload.sol";

contract RedStonePayloadTest is Test {
    DebugRedStoneConsumer consumer;

    uint256 constant PRIVATE_KEY_1 =
        0x1111111111111111111111111111111111111111111111111111111111111111;
    address constant ADDRESS_1 = 0x19E7E376E7C213B7E7e7e46cc70A5dD086DAff2A;
    uint256 constant PRIVATE_KEY_2 =
        0x2222222222222222222222222222222222222222222222222222222222222222;
    address constant ADDRESS_2 = 0x1563915e194D8CfBA1943570603F7606A3115508;

    // The Solidity compiler does not support storing some more complex structs
    // in storage, so we return example data packages from functions.
    function payloadWithOneDataPackage()
        internal
        pure
        returns (RedStonePayload.Payload memory)
    {
        bytes32 dataFeedId = "USDCELO";
        uint256[] memory values = new uint256[](1);
        uint256[] memory privateKeys = new uint256[](1);
        uint256[] memory timestamps = new uint256[](1);

        values[0] = 42;
        privateKeys[0] = PRIVATE_KEY_1;
        timestamps[0] = 1337;

        return
            RedStonePayload.makePayload(
                dataFeedId,
                values,
                privateKeys,
                timestamps
            );
    }

    function payloadWithTwoDataPackages()
        internal
        pure
        returns (RedStonePayload.Payload memory)
    {
        bytes32 dataFeedId = "USDCELO";
        uint256[] memory values = new uint256[](2);
        uint256[] memory privateKeys = new uint256[](2);
        uint256[] memory timestamps = new uint256[](2);

        values[0] = 42;
        values[1] = 24;
        privateKeys[0] = PRIVATE_KEY_1;
        privateKeys[1] = PRIVATE_KEY_2;
        timestamps[0] = 1337;
        timestamps[1] = 1337;
        return
            RedStonePayload.makePayload(
                dataFeedId,
                values,
                privateKeys,
                timestamps
            );
    }

    function setUp() public {
        consumer = new DebugRedStoneConsumer();
    }

    function reportWithPayload(
        bytes32 rateFeedId,
        bytes memory payload,
        uint8 signers
    ) public returns (uint64[4] memory) {
        bytes memory callData = abi.encodeWithSignature(
            "report(bytes32)",
            rateFeedId
        );
        bytes memory callDataWithPayload = bytes.concat(callData, payload);
        consumer.setUniqueSignersThreshold(signers);
        // solhint-disable-next-line avoid-low-level-calls
        (, bytes memory returnBytes) = address(consumer).call(
            callDataWithPayload
        );
        uint256 returnValue = abi.decode(returnBytes, (uint256));
        return consumer.parseAggregatedValue(returnValue);
    }
}

contract RedStonePayloadTest_makePayload is RedStonePayloadTest {
    function test_makePayloadWithSignatures() public pure {
        bytes32 dataFeedId = "USDCELO";
        uint256[] memory values = new uint256[](1);
        bytes32[] memory rs = new bytes32[](1);
        bytes32[] memory ss = new bytes32[](1);
        uint8[] memory vs = new uint8[](1);
        uint256[] memory timestamps = new uint256[](1);

        values[0] = 42;
        rs[0] = 0;
        ss[0] = 0;
        vs[0] = 0;
        timestamps[0] = 1337;

        RedStonePayload.Payload memory payload = RedStonePayload.makePayload(
            dataFeedId,
            values,
            rs,
            ss,
            vs,
            timestamps
        );

        assertEq(
            payload.dataPackages[0].dataPackage.dataPoints[0].dataFeedId,
            "USDCELO"
        );
        assertEq(payload.dataPackages[0].dataPackage.dataPoints[0].decimals, 8);
        assertEq(
            payload.dataPackages[0].dataPackage.dataPoints[0].valueBytesSize,
            32
        );
        assertEq(payload.dataPackages[0].dataPackage.dataPoints[0].value, 42);
        assertEq(
            payload.dataPackages[0].dataPackage.timestampMilliseconds,
            1337
        );
    }

    function test_makePayloadWithPrivateKeys() public pure {
        bytes32 dataFeedId = "USDCELO";
        uint256[] memory values = new uint256[](1);
        uint256[] memory privateKeys = new uint256[](1);
        uint256[] memory timestamps = new uint256[](1);

        values[0] = 42;
        privateKeys[0] = PRIVATE_KEY_1;
        timestamps[0] = 1337;

        RedStonePayload.Payload memory payload = RedStonePayload.makePayload(
            dataFeedId,
            values,
            privateKeys,
            timestamps
        );

        assertEq(payload.dataPackages[0].dataPackage.dataPoints[0].value, 42);
        assertEq(payload.dataPackages[0].dataPackage.dataPoints[0].decimals, 8);
        assertEq(
            payload.dataPackages[0].dataPackage.dataPoints[0].valueBytesSize,
            32
        );
        assertEq(
            payload.dataPackages[0].dataPackage.timestampMilliseconds,
            1337
        );
    }
}

contract RedStonePayload_serializePayload is RedStonePayloadTest {
    function test_serializePayload_oneDataPackage() public pure {
        RedStonePayload.Payload memory payload = payloadWithOneDataPackage();

        bytes memory result = RedStonePayload.serializePayload(payload);
        // 156 comes from manual math verification of what the length should be.
        assertEq(result.length, 156);
    }

    function test_serializePayload_twoDataPackages() public pure {
        RedStonePayload.Payload memory payload = payloadWithTwoDataPackages();

        bytes memory result = RedStonePayload.serializePayload(payload);
        // 298 comes from manual math verification of what the length should be.
        assertEq(result.length, 298);
    }

    function test_parseSerializedPayload() public {
        RedStonePayload.Payload memory payload = payloadWithOneDataPackage();
        bytes memory result = RedStonePayload.serializePayload(payload);

        uint64[4] memory values = reportWithPayload("USDCELO", result, 1);

        assertEq(values[0], 42);
        assertEq(consumer.receivedTimestamp(), 1337);
    }

    function test_parseSerializedPayloadWithTwoValues() public {
        RedStonePayload.Payload memory payload = payloadWithTwoDataPackages();
        bytes memory result = RedStonePayload.serializePayload(payload);

        uint64[4] memory values = reportWithPayload("USDCELO", result, 2);

        assertEq(values[0], 42);
        assertEq(values[1], 24);
        assertEq(consumer.receivedTimestamp(), 1337);
    }
}
