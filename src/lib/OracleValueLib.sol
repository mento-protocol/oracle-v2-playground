// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {StdError} from "./StdError.sol";

/**
 * @notice Zero-cost wrapper around uint64. OracleValues represent fixed
 * fractions with 8 decimal digits after the decimal point (i.e. 1 is
 * represented as 10 ** 8).
 */
type OracleValue is uint64;

/**
 * @notice A library used to work with fixed fractions in the Oracle contract.
 */
library OracleValueLib {
    using OracleValueLib for OracleValue;

    /**
     * @notice The multiplicative factor to convert between OracleValue and
     * Celo's FixdityLib values.
     * @dev FixidityLib uses 24 decimal digits. OracleValue uses 8 decimal
     * digits. So the conversion factor is 10 ** (24 - 8) = 10 ** 16.
     */
    uint256 private constant CELO_FIXIDITY_CONVERSION_FACTOR = 10 ** 16;

    /**
     * @notice Wraps a uint64 into the OracleValue type.
     * @param value The raw uint64 value.
     * @return wrappedValue The OracleValue.
     */
    function wrap(
        uint64 value
    ) internal pure returns (OracleValue wrappedValue) {
        return OracleValue.wrap(value);
    }

    /**
     * @notice Unwraps an OracleValue into a raw uint64.
     * @param self The OracleValue.
     * @return unwrappedValue The underlying uint64 value.
     */
    function unwrap(
        OracleValue self
    ) internal pure returns (uint64 unwrappedValue) {
        return OracleValue.unwrap(self);
    }

    /**
     * @notice Wraps a uint256 into the OracleValue type.
     * @param value The raw uint256 value.
     * @return wrappedValue The OracleValue.
     * @dev Reverts if `value` doesn't fit in uint64.
     */
    function wrapUint256(
        uint256 value
    ) internal pure returns (OracleValue wrappedValue) {
        if (value > type(uint64).max) {
            StdError.panicArithmetic();
        }
        return OracleValue.wrap(uint64(value));
    }

    /**
     * @notice Unwraps an OracleValue into a raw uint256.
     * @param self The OracleValue.
     * @return unwrappedValue The underlying value exapnded to a uint256.
     */
    function unwrapToUint256(
        OracleValue self
    ) internal pure returns (uint256 unwrappedValue) {
        return uint256(self.unwrap());
    }

    /**
     * @notice Converts a Celo FixidityLib underlying value to an OracleValue.
     * @param value The FixidityLib value (with 24 decimal digits after the
     * decimal point).
     * @return wrappedValue The OracleValue (truncating the least significant 16 digits).
     * @dev Reverts if the value doesn't fit in uint64.
     */
    function fromCeloFixidity(
        uint256 value
    ) internal pure returns (OracleValue wrappedValue) {
        return wrapUint256(value / CELO_FIXIDITY_CONVERSION_FACTOR);
    }

    /**
     * @notice Converts an OracleValue to (an unwrapped) Celo Fixidity value.
     * @param self The OracleValue.
     * @return unwrappedValue The unwrapped Celo Fixidity value corresponding to the same
     * number.
     */
    function toCeloFixidity(
        OracleValue self
    ) internal pure returns (uint256 unwrappedValue) {
        return self.unwrapToUint256() * CELO_FIXIDITY_CONVERSION_FACTOR;
    }

    /**
     * @notice Addition of OracleValues.
     * @param self The first OracleValue.
     * @param other The second Oracle Value.
     * @return sum The sum of `self` and `other`.
     * @dev Reverts if the sum doesn't fit in uint64.
     */
    function add(
        OracleValue self,
        OracleValue other
    ) internal pure returns (OracleValue sum) {
        return
            OracleValue.wrap(
                OracleValue.unwrap(self) + OracleValue.unwrap(other)
            );
    }

    /**
     * @notice Subtraction of OracleValues.
     * @param self The first OracleValue.
     * @param other The second Oracle Value.
     * @return difference The difference of `self` minus `other`.
     * @dev Reverts on underflow, i.e. when `other` is greater than `self`.
     */
    function sub(
        OracleValue self,
        OracleValue other
    ) internal pure returns (OracleValue difference) {
        return
            OracleValue.wrap(
                OracleValue.unwrap(self) - OracleValue.unwrap(other)
            );
    }

    /**
     * @notice Greater than or equal comparison of OracleValues.
     * @param self The first OracleValue.
     * @param other The second Oracle Value.
     * @return isGreaterOrEqual True if `self` is greater than or equal to `other`, false otherwise.
     */
    function geq(
        OracleValue self,
        OracleValue other
    ) internal pure returns (bool isGreaterOrEqual) {
        // solhint-disable-next-line gas-strict-inequalities
        return self.unwrap() >= other.unwrap();
    }

    /**
     * @notice Divides an OracleValue by a small integer.
     * @param self The OracleValue.
     * @param divisor The divisor, a small integer (not a fixed fraction).
     * @return quotient The division of `self` by `divisor`.
     */
    function divByUint8(
        OracleValue self,
        uint8 divisor
    ) internal pure returns (OracleValue quotient) {
        return OracleValue.wrap(self.unwrap() / uint64(divisor));
    }

    /**
     * @notice Scales an OracleValue by a factor <1.
     * @param self The OracleValue.
     * @param fraction The numerator of a scaling factor less than 1, with the
     * denominator assumed to be uint16.max.
     * @return product The product of `self` and `fraction`/uint16.max.
     * @dev This never reverts, as the fraction is less than 1, and we lift into
     * uint256 to perform the multiplication.
     */
    function scaleByFraction(
        OracleValue self,
        uint16 fraction
    ) internal pure returns (OracleValue product) {
        uint256 intermediate = (uint256(self.unwrap()) * uint256(fraction)) /
            uint256(type(uint16).max);
        return OracleValue.wrap(uint64(intermediate));
    }

    /**
     * @notice Converts the value part of a RedStone value to an OracleValue.
     * @param value The value from a RedStone oracle report.
     * @return wrappedValue The value as an OracleValue.
     * @dev Reverts if the value doesn't fit in a uint64.
     * @dev RedStone reports use the same number of decimal digits (8) as
     * OracleValue.
     */
    function fromRedStoneValue(
        uint256 value
    ) internal pure returns (OracleValue wrappedValue) {
        uint256 mask = type(uint256).max - (1 << 255);
        return wrapUint256(value & mask);
    }

    /**
     * @notice Extracts the certainty bit form a RedStone value.
     * @param value The value from a RedStone oracle report.
     * @return isCertain The certainty bit.
     * @dev The certainty bit is encoded in the most significant bit of a report
     * value.
     */
    function redStoneValueCertainty(
        uint256 value
    ) internal pure returns (bool isCertain) {
        return (value >> 255) == 1;
    }
}
