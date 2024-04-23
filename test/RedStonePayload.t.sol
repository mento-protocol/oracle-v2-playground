// SPDX-License-Identifier: UNLICENSED
// solhint-disable func-name-mixedcase, gas-strict-inequalities, ordering
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RedStonePayload} from "./lib/RedStonePayload.sol";

contract OraclesTest is Test {
    function setUp() public virtual {}

    function test_makePayload() public {
        bytes memory dataFeedId = new bytes(20);
        dataFeedId = "USDCELO";
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

        assertEq(payload.dataPackages[0].dataPackage.dataPoints[0].value, 42);
        assertEq(
            payload.dataPackages[0].dataPackage.timestampMilliseconds,
            1337
        );
    }
}
