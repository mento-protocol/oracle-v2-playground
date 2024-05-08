// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";

/**
 * @notice Implements serialization to a RedStone data payload.
 * @dev Reference:
 * https://github.com/redstone-finance/redstone-oracles-monorepo/tree/main/packages/protocol/src
 */
library RedStonePayload {
    // See https://book.getfoundry.sh/forge/cheatcodes
    address private constant CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
    Vm private constant vm = Vm(CHEATCODE_ADDRESS);

    struct SerializationBuffer {
        bytes buffer;
        uint256 currentIndex;
    }

    struct DataPoint {
        bytes32 dataFeedId;
        uint256 value;
        uint256 decimals;
        uint256 valueBytesSize;
        // Memory structs cannot contain mappings. We likely don't need metadata
        // for our purposes. If we do, can replace this with two arrays.
        // mapping (string => bytes) metadata;
    }

    struct DataPackage {
        DataPoint[] dataPoints;
        uint256 timestampMilliseconds;
    }

    struct Signature {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    struct SignedDataPackage {
        DataPackage dataPackage;
        Signature signature;
    }

    struct Payload {
        SignedDataPackage[] dataPackages;
        string metadata;
    }

    // Constants from
    // solhint-disable-next-line max-line-length
    // https://github.com/redstone-finance/redstone-oracles-monorepo/blob/main/packages/protocol/src/common/redstone-constants.ts
    // Number of bytes reserved to store timestamp
    uint256 private constant TIMESTAMP_BS = 6;

    // Number of bytes reserved to store the number of data points
    uint256 private constant DATA_POINTS_COUNT_BS = 3;

    // Number of bytes reserved to store datapoints byte size
    uint256 private constant DATA_POINT_VALUE_BYTE_SIZE_BS = 4;

    // Default value byte size for numeric values
    uint256 private constant DEFAULT_NUM_VALUE_BS = 32;

    // Default precision for numeric values
    uint256 private constant DEFAULT_NUM_VALUE_DECIMALS = 8;

    // Number of bytes reserved for data packages count
    uint256 private constant DATA_PACKAGES_COUNT_BS = 2;

    // Number of bytes reserved for unsigned metadata byte size
    uint256 private constant UNSIGNED_METADATA_BYTE_SIZE_BS = 3;

    // RedStone marker, which will be appended in the end of each transaction
    uint256 private constant REDSTONE_MARKER = 0x000002ed57011e0000;

    // Byte size of RedStone marker
    // we subtract 1 because of the 0x prefix
    uint256 private constant REDSTONE_MARKER_BS = 9;

    // Byte size of signatures
    uint256 private constant SIGNATURE_BS = 65;

    // Byte size of data feed id
    uint256 private constant DATA_FEED_ID_BS = 32;

    // RedStone allows a single oracle to report for multiple feeds in a single
    // batch, but our model assumes each batch is for a single data feed.
    uint256 private constant DATA_POINTS_PER_PACKAGE = 1;

    function signDataPackage(DataPackage memory dataPackage, uint256 privateKey) internal pure returns (Signature memory) {
       uint256 dataPackageSerializedSize =
            DATA_POINTS_COUNT_BS +
            DATA_POINT_VALUE_BYTE_SIZE_BS +
            TIMESTAMP_BS +
            DATA_POINTS_PER_PACKAGE * (
                DATA_FEED_ID_BS +
                DEFAULT_NUM_VALUE_BS
            );
        SerializationBuffer memory buffer = newSerializationBuffer(dataPackageSerializedSize);
        writeDataPackage(buffer, dataPackage);
        bytes32 digest = keccak256(buffer.buffer);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return Signature(r, s, v);
    }

    function makePayload(
        bytes32 dataFeedId,
        uint256[] memory values,
        uint256[] memory privateKeys,
        uint256[] memory timestamps
    ) internal pure returns (Payload memory) {
        Payload memory payload;

        uint256 numberPackages = values.length;

        payload.dataPackages = new SignedDataPackage[](numberPackages);

        for (uint256 i = 0; i < numberPackages; i++) {
            DataPoint[] memory dataPoints = new DataPoint[](1);
            dataPoints[0] = DataPoint(dataFeedId, values[i], 18, 8);
            DataPackage memory dataPackage = DataPackage(
                dataPoints,
                timestamps[i]
            );

            Signature memory signature = signDataPackage(dataPackage, privateKeys[i]);
            payload.dataPackages[i] = SignedDataPackage(dataPackage, signature);
        }

        return payload;
    }

    function makePayload(
        bytes32 dataFeedId,
        uint256[] memory values,
        bytes32[] memory rs,
        bytes32[] memory ss,
        uint8[] memory vs,
        uint256[] memory timestamps
    ) internal pure returns (Payload memory) {
        Payload memory payload;

        uint256 numberPackages = values.length;

        payload.dataPackages = new SignedDataPackage[](numberPackages);

        for (uint256 i = 0; i < numberPackages; i++) {
            DataPoint[] memory dataPoints = new DataPoint[](1);
            dataPoints[0] = DataPoint(dataFeedId, values[i], 18, 8);
            DataPackage memory dataPackage = DataPackage(
                dataPoints,
                timestamps[i]
            );
            Signature memory signature = Signature(rs[i], ss[i], vs[i]);
            payload.dataPackages[i] = SignedDataPackage(dataPackage, signature);
        }

        return payload;
    }

    function newSerializationBuffer(
        uint256 length
    ) internal pure returns (SerializationBuffer memory) {
        bytes memory buffer = new bytes(length);
        return SerializationBuffer(buffer, 0);
    }

    function writeBytes32(
        SerializationBuffer memory buffer,
        bytes32 data
    ) internal pure {
        for (uint256 i = 0; i < 32; i++) {
            uint256 bufferIndex = buffer.currentIndex + i;
            buffer.buffer[bufferIndex] = data[i];
        }

        buffer.currentIndex += 32;
    }

    function writeNumber(
        SerializationBuffer memory buffer,
        uint256 value,
        uint256 bytesToWrite
    ) internal pure {
        // we write the number back-to-front, makes the logic simpler
        for (int256 i = int256(bytesToWrite) - 1; i >= 0; i--) {
            uint256 bufferIndex = buffer.currentIndex + uint256(i);
            buffer.buffer[bufferIndex] = bytes1(uint8(value % 0x100)); // write the last byte
            value = value / 0x100; // truncate last byte
        }

        buffer.currentIndex += bytesToWrite;
    }

    function writeUint256(
        SerializationBuffer memory buffer,
        uint256 value
    ) internal pure {
        writeNumber(buffer, value, 32);
    }

    function writeDataPoint(
        SerializationBuffer memory buffer,
        DataPoint memory dataPoint
    ) internal pure {
        writeBytes32(buffer, dataPoint.dataFeedId);
        writeUint256(buffer, dataPoint.value);
    }

    function writeTimestamp(
        SerializationBuffer memory buffer,
        uint256 timestamp
    ) internal pure {
        writeNumber(buffer, timestamp, TIMESTAMP_BS);
    }

    function writeDataPointSize(
        SerializationBuffer memory buffer
    ) internal pure {
        writeNumber(buffer, 32, DATA_POINT_VALUE_BYTE_SIZE_BS);
    }

    function writeDataPointNumber(
        SerializationBuffer memory buffer,
        uint256 number
    ) internal pure {
        writeNumber(buffer, number, DATA_POINTS_COUNT_BS);
    }

    function writeSignature(
        SerializationBuffer memory buffer,
        Signature memory signature
    ) internal pure {
        writeBytes32(buffer, signature.r);
        writeBytes32(buffer, signature.s);
        writeNumber(buffer, signature.v, 1);
    }

    function writeDataPackage(
        SerializationBuffer memory buffer,
        DataPackage memory dataPackage
    ) internal pure {
        for (uint256 i = 0; i < dataPackage.dataPoints.length; i++) {
            writeDataPoint(buffer, dataPackage.dataPoints[i]);
        }
        writeTimestamp(buffer, dataPackage.timestampMilliseconds);
        writeDataPointSize(buffer);
        writeDataPointNumber(buffer, dataPackage.dataPoints.length);
    }

    function writeSignedDataPackage(
        SerializationBuffer memory buffer,
        SignedDataPackage memory signedDataPackage
    ) internal pure {
        writeDataPackage(buffer, signedDataPackage.dataPackage);
        writeSignature(buffer, signedDataPackage.signature);
    }

    function writeEmptyMetadata(
        SerializationBuffer memory buffer
    ) internal pure {
        writeNumber(buffer, 0, UNSIGNED_METADATA_BYTE_SIZE_BS);
    }

    function writeRedStoneMarker(
        SerializationBuffer memory buffer
    ) internal pure {
        writeNumber(buffer, REDSTONE_MARKER, REDSTONE_MARKER_BS);
    }

    function serializePayload(
        Payload memory payload
    ) internal pure returns (bytes memory) {
        uint256 numberDataPackages = payload.dataPackages.length;
        // prettier-ignore
        uint256 serializedPayloadLength = REDSTONE_MARKER_BS +
            UNSIGNED_METADATA_BYTE_SIZE_BS + // + 0 for actual metadata in our case
            DATA_PACKAGES_COUNT_BS +
            numberDataPackages * (
                SIGNATURE_BS +
                DATA_POINTS_COUNT_BS +
                DATA_POINT_VALUE_BYTE_SIZE_BS +
                TIMESTAMP_BS +
                DATA_POINTS_PER_PACKAGE * (
                    DATA_FEED_ID_BS +
                    DEFAULT_NUM_VALUE_BS
                )
            );

        SerializationBuffer memory buffer = newSerializationBuffer(
            serializedPayloadLength
        );

        for (uint256 i = 0; i < numberDataPackages; i++) {
            writeSignedDataPackage(buffer, payload.dataPackages[i]);
        }

        writeNumber(buffer, numberDataPackages, DATA_PACKAGES_COUNT_BS);
        writeEmptyMetadata(buffer);
        writeRedStoneMarker(buffer);

        return buffer.buffer;
    }
}
