// SPDX-License-Identifier: UNLICENSED
// solhint-disable func-name-mixedcase, gas-strict-inequalities, ordering
pragma solidity ^0.8.24;

import {Test, stdError} from "forge-std/Test.sol";
import {StdError} from "../src/lib/StdError.sol";

contract StdErrorTest is Test {
    // solhint-disable-next-line no-empty-blocks
    function setUp() public {}

    function test_panicArithmetic() public {
        vm.expectRevert(stdError.arithmeticError);
        StdError.panicArithmetic();
    }
}
