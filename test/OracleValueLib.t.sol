// SPDX-License-Identifier: UNLICENSED
// solhint-disable func-name-mixedcase, gas-strict-inequalities, ordering
pragma solidity ^0.8.24;

import {Test, stdError} from "forge-std/Test.sol";
import {OracleValueLib, OracleValue} from "../src/lib/OracleValueLib.sol";

contract OracleValueLibTest is Test {
    using OracleValueLib for OracleValue;

    // solhint-disable-next-line no-empty-blocks
    function setUp() public {}

    function testFuzz_wrap(uint64 x) public pure {
        OracleValue a = OracleValueLib.wrap(x);
        assertEq(OracleValue.unwrap(a), x);
    }

    function testFuzz_unwrap(uint64 x) public pure {
        OracleValue a = OracleValueLib.wrap(x);
        assertEq(a.unwrap(), x);
    }

    function testFuzz_wrapUint256(uint256 x) public pure {
        vm.assume(x <= type(uint64).max);
        OracleValue a = OracleValueLib.wrapUint256(x);
        assertEq(uint256(a.unwrap()), x);
    }

    function testFuzz_wrapUint256Fail(uint256 x) public {
        vm.assume(x > type(uint64).max);

        vm.expectRevert(stdError.arithmeticError);
        OracleValueLib.wrapUint256(x);
    }

    function testFuzz_unwrapToUint256(uint256 x) public pure {
        vm.assume(x <= type(uint64).max);
        OracleValue a = OracleValueLib.wrapUint256(x);
        assertEq(a.unwrapToUint256(), uint256(x));
    }

    function testFuzz_fromCeloFixidity(uint256 x) public pure {
        vm.assume(x / 10 ** 16 <= type(uint64).max);
        OracleValue a = OracleValueLib.fromCeloFixidity(x);
        assertEq(a.unwrapToUint256(), x / 10 ** 16);
    }

    function testFuzz_fromCeloFixidityFail(uint256 x) public {
        vm.assume(x / 10 ** 16 > type(uint64).max);
        vm.expectRevert(stdError.arithmeticError);
        OracleValueLib.fromCeloFixidity(x);
    }

    function testFuzz_toCeloFixidity(uint64 x) public pure {
        OracleValue a = OracleValueLib.wrap(x);
        assertEq(a.toCeloFixidity(), uint256(x) * 10 ** 16);
    }

    function testFuzz_add(uint64 x, uint64 y) public pure {
        vm.assume(uint256(x) + uint256(y) <= type(uint64).max);
        OracleValue a = OracleValueLib.wrap(x);
        OracleValue b = OracleValueLib.wrap(y);
        OracleValue c = a.add(b);
        assertEq(OracleValue.unwrap(c), x + y);
    }

    function testFuzz_addFail(uint64 x, uint64 y) public {
        vm.assume(x > type(uint64).max / 2);
        vm.assume(y > type(uint64).max / 2);
        OracleValue a = OracleValueLib.wrap(x);
        OracleValue b = OracleValueLib.wrap(y);

        vm.expectRevert(stdError.arithmeticError);
        a.add(b);
    }

    function testFuzz_sub(uint64 x, uint64 y) public pure {
        vm.assume(x >= y);
        OracleValue a = OracleValueLib.wrap(x);
        OracleValue b = OracleValueLib.wrap(y);
        OracleValue c = a.sub(b);
        assertEq(OracleValue.unwrap(c), x - y);
    }

    function testFuzz_subFail(uint64 x, uint64 y) public {
        vm.assume(x < y);
        OracleValue a = OracleValueLib.wrap(x);
        OracleValue b = OracleValueLib.wrap(y);

        vm.expectRevert(stdError.arithmeticError);
        a.sub(b);
    }

    function testFuzz_geqLarger(uint64 x, uint64 y) public pure {
        vm.assume(x > y);
        OracleValue a = OracleValueLib.wrap(x);
        OracleValue b = OracleValueLib.wrap(y);

        assertTrue(a.geq(b));
    }

    function testFuzz_geqEqual(uint64 x, uint64 y) public pure {
        vm.assume(x == y);
        OracleValue a = OracleValueLib.wrap(x);
        OracleValue b = OracleValueLib.wrap(y);

        assertTrue(a.geq(b));
    }

    function testFuzz_geqSmaller(uint64 x, uint64 y) public pure {
        vm.assume(x < y);
        OracleValue a = OracleValueLib.wrap(x);
        OracleValue b = OracleValueLib.wrap(y);

        assertFalse(a.geq(b));
    }

    function testFuzz_div(uint64 x, uint8 y) public pure {
        vm.assume(y != 0);
        OracleValue a = OracleValueLib.wrap(x);
        OracleValue b = a.divByUint8(y);

        assertEq(b.unwrap(), x / uint64(y));
    }

    function testFuzz_divByZero(uint64 x) public {
        OracleValue a = OracleValueLib.wrap(x);

        vm.expectRevert(stdError.divisionError);
        a.divByUint8(0);
    }

    function testFuzz_scaleByFraction(uint64 x, uint16 f) public pure {
        OracleValue a = OracleValueLib.wrap(x);
        OracleValue b = a.scaleByFraction(f);

        assertTrue(a.geq(b));
        assertEq(
            b.unwrap(),
            (uint256(a.unwrap()) * uint256(f)) / uint256(type(uint16).max)
        );
    }

    function testFuzz_fromRedStoneValue_withoutCertainty(
        uint256 x
    ) public pure {
        vm.assume(x <= type(uint64).max);
        OracleValue a = OracleValueLib.fromRedStoneValue(x);
        assertEq(a.unwrap(), uint256(x));
    }

    function testFuzz_fromRedStoneValue_withCertainty(uint256 x) public pure {
        vm.assume(x <= type(uint64).max);
        uint256 y = x | uint256(1 << 255);
        OracleValue a = OracleValueLib.fromRedStoneValue(y);
        assertEq(a.unwrap(), uint256(x));
    }

    function testFuzz_fromRedStoneValueFail_withoutCertainy(uint256 x) public {
        vm.assume(x & (1 << 255) == 0);
        vm.assume(x > type(uint64).max);

        vm.expectRevert(stdError.arithmeticError);
        OracleValueLib.fromRedStoneValue(x);
    }

    function testFuzz_fromRedStoneValueFail_withCertainy(uint256 x) public {
        vm.assume(x & (1 << 255) == 0);
        vm.assume(x > type(uint64).max);
        x = x | uint256(1 << 255);

        vm.expectRevert(stdError.arithmeticError);
        OracleValueLib.fromRedStoneValue(x);
    }

    function testFuzz_redStoneValueCertainty(uint256 x) public pure {
        bool certainty = OracleValueLib.redStoneValueCertainty(x);
        assertEq(certainty, (x >> 255) == 1);
    }
}
