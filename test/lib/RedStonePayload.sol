// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

/**
 * @notice Implements serialization to a RedStone data payload.
 * @dev Reference:
 * https://github.com/redstone-finance/redstone-oracles-monorepo/tree/main/packages/protocol/src
 */
library RedStonePayload {
    // Constants from
    // https://github.com/redstone-finance/redstone-oracles-monorepo/blob/main/packages/protocol/src/common/redstone-constants.ts
    // Number of bytes reserved to store timestamp
    uint256 constant TIMESTAMP_BS = 6;

    // Number of bytes reserved to store the number of data points
    uint256 constant DATA_POINTS_COUNT_BS = 3;

    // Number of bytes reserved to store datapoints byte size
    uint256 constant DATA_POINT_VALUE_BYTE_SIZE_BS = 4;

    // Default value byte size for numeric values
    uint256 constant DEFAULT_NUM_VALUE_BS = 32;

    // Default precision for numeric values
    uint256 constant DEFAULT_NUM_VALUE_DECIMALS = 8;

    // Number of bytes reserved for data packages count
    uint256 constant DATA_PACKAGES_COUNT_BS = 2;

    // Number of bytes reserved for unsigned metadata byte size
    uint256 constant UNSIGNED_METADATA_BYTE_SIZE_BS = 3;

    // RedStone marker, which will be appended in the end of each transaction
    uint256 constant REDSTONE_MARKER = 0x000002ed57011e0000;

    // Byte size of RedStone marker
    // we subtract 1 because of the 0x prefix
    uint256 constant REDSTONE_MARKER_BS = 9;

    // Byte size of signatures
    uint256 constant SIGNATURE_BS = 65;

    // Byte size of data feed id
    uint256 constant DATA_FEED_ID_BS = 32;

    // RedStone allows a single oracle to report for multiple feeds in a single
    // batch, but our model assumes each batch is for a single data feed.
    uint256 constant DATA_POINTS_PER_PACKAGE = 1;

    struct DataPoint {
        bytes dataFeedId;
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

    function makePayload(
        bytes memory dataFeedId,
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

            dataPoints[0] = DataPoint(
                dataFeedId,
                values[i],
                18,
                8
            );

            DataPackage memory dataPackage = DataPackage(
                dataPoints,
                timestamps[i]
            );

            Signature memory signature = Signature(rs[i], ss[i], vs[i]);

            payload.dataPackages[i] = SignedDataPackage(dataPackage, signature);
        }

        return payload;
    }

    function serializePayload(Payload memory payload) internal pure returns (bytes memory) {
        uint256 numberDataPackages = payload.dataPackages.length;
        uint256 serializedPayloadLength =
            REDSTONE_MARKER_BS +
            UNSIGNED_METADATA_BYTE_SIZE_BS + // + 0 for actual metadata in our case
            DATA_PACKAGES_COUNT_BS +
            numberDataPackages * (
                SIGNATURE_BS +
                DATA_POINTS_COUNT_BS +
                DATA_POINT_VALUE_BYTE_SIZE_BS +
                TIMESTAMP_BS +
                DATA_POINTS_PER_PACKAGE * ( // this is always = 1 in our case
                    DATA_FEED_ID_BS +
                    DEFAULT_NUM_VALUE_BS
                )
            );

        bytes memory serializedPayload = new bytes(serializedPayloadLength);

        return serializedPayload;
    }
}
