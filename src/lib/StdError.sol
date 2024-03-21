// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/**
 * @notice Allows reverting with standard Solidity panic codes.
 * @dev When Solidity encounters certain irrecoverable errors (such as division
 * by 0), it reverts with a `Panic(uint256)` error, using one of the predefined
 * error codes.
 * These errors cannot be directly returned with the `revert` keyword, nor
 * defined with `error`, thus we use low-level assembly to revert with the
 * appropriate data.
 * See:
 * - https://docs.soliditylang.org/en/v0.8.13/control-structures.html#panic-via-assert-and-error-via-require
 * - https://github.com/ethereum/solidity/issues/11792
 */
library StdError {
    string private constant PANIC_SIGNATURE = "Panic(uint256)";
    uint256 private constant CODE_ARITHMETIC = 0x11;
    bytes private constant ERROR_ARITHMETIC =
        abi.encodeWithSignature(PANIC_SIGNATURE, CODE_ARITHMETIC);

    function panicArithmetic() internal pure {
        bytes memory err = ERROR_ARITHMETIC;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            /* The first 32 (0x20) bytes at `err`'s memory location is the
             * length of the byte array, we're only interested in the contents
             * themselves
             * Length of the error payload is 36:
             * - 4 bytes for signature
             * - 32 bytes for uint256 error code
             */
            revert(add(err, 0x20), 36)
        }
    }
}
