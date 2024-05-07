// SPDX-License-Identifier: UNLICENSED
// TODO: Re-enable rules after implementation is complete
// solhint-disable no-empty-blocks
// solhint-disable contract-name-camelcase, func-name-mixedcase, gas-strict-inequalities, ordering
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Oracles} from "../src/Oracles.sol";

contract OraclesTest is Test {
    Oracles public oracles;

    address public aRateFeed;
    // solhint-disable-next-line no-empty-blocks
    function setUp() public virtual {
        oracles = new Oracles();
        aRateFeed = address(0x1337);
    }
}

// solhint-disable-next-line max-line-length
// Example for a Redstone calldata payload // https://github.com/redstone-finance/redstone-near-connectors/blob/7bc02fc5421200b15da56c33c5c6130130b3ff8a/js/test/integration.test.ts#L17-L37
contract Oracles_report is OraclesTest {}

contract Oracles_markStale is OraclesTest {}

contract Oracles_setPriceWindowSize is OraclesTest {
    function testFuzz_setsWindowSize(uint8 priceWindowSize) public {
        vm.assume(priceWindowSize != 0 && priceWindowSize <= 100);
        oracles.setPriceWindowSize(aRateFeed, priceWindowSize);
        (uint8 realWindowSize, , , , ) = oracles.rateFeedConfig(aRateFeed);
        assertEq(realWindowSize, priceWindowSize);
    }

    function test_setTo0Fail() public {
        // TODO: set the exact expected error
        vm.expectRevert();
        oracles.setPriceWindowSize(aRateFeed, 0);
    }

    function testFuzz_setToOver100Fail(uint8 priceWindowSize) public {
        vm.assume(priceWindowSize > 100);
        // TODO: set the exact expected error
        vm.expectRevert();
        oracles.setPriceWindowSize(aRateFeed, priceWindowSize);
    }

    /*
    TODO:
    - Only owner
    More complex test cases, when average needs to be recalculated.
    - When buffer not full yet
        - decreasing window
        - increasing window, there's enough values for new average
        - increasing window, there's not enough values for new average
    - When buffer full
        - decreasing window
        - increasing window, there's enough values before index 0
        - increasing window, need to wrap around to end of buffer
    - setting window to max (100)
    */
}

contract Oracles_setAllowedDeviation is OraclesTest {
    function testFuzz_setsAllowedDeviation(uint16 allowedDeviation) public {
        oracles.setAllowedDeviation(aRateFeed, allowedDeviation);
        (, uint16 realAllowedDeviation, , , ) = oracles.rateFeedConfig(
            aRateFeed
        );
        assertEq(realAllowedDeviation, allowedDeviation);
    }

    /*
    TODO:
    - Only owner
    Test cases including a follow-up report:
    - New report has too much deviation
    - New report fits in new deviation
    */
}

contract Oracles_setQuorum is OraclesTest {
    function testFuzz_setsQuorum(uint8 quorum) public {
        oracles.setQuorum(aRateFeed, quorum);
        (, , uint8 realQuorum, , ) = oracles.rateFeedConfig(aRateFeed);
        assertEq(realQuorum, quorum);
    }

    /*
    TODO:
    - Only owner
    - Fails when quorum is larger than the number of whitelisted reporters
    test cases including a follow-up report:
    - New report has quorum
    - New report no longer has quorum
    */
}

contract Oracles_setCertaintyThreshold is OraclesTest {
    function testFuzz_setsCertaintyThreshold(uint8 certaintyThreshold) public {
        oracles.setCertaintyThreshold(aRateFeed, certaintyThreshold);
        (, , , uint8 realCertaintyThreshold, ) = oracles.rateFeedConfig(
            aRateFeed
        );
        assertEq(realCertaintyThreshold, certaintyThreshold);
    }

    /*
    TODO:
    - Only owner
    - Fails when certainty threshold is larger than the number of whitelisted
      reporters
    - Fails when certainty threshold is larger than quorum
    test cases including a follow-up report:
    - New report meets the certainty threshold
    - New report no longer meets the certainty threshold
    */
}

contract Oracles_setAllowedStaleness is OraclesTest {
    function testFuzz_setsAllowedStaleness(
        uint16 allowedStalenessInSeconds
    ) public {
        oracles.setAllowedStaleness(aRateFeed, allowedStalenessInSeconds);
        (, , , , uint16 realAllowedStaleness) = oracles.rateFeedConfig(
            aRateFeed
        );
        assertEq(realAllowedStaleness, allowedStalenessInSeconds);
    }

    /*
    TODO:
    - Only owner
    - Fails when certainty threshold is shorter than block time
    test cases including a follow-up report:
    - New report meets the allowed staleness
        - The new window is shorter, markStale marks as stale when with the
          previous window it would have still been fresh
        - The new window is longer, markStale doesn't mark as stale when with
          the previous window it would have been
    - New report no longer meets the allowed staleness
    */
}

contract Oracles_addRateFeed is OraclesTest {
    function test_createsANewRateFeed() public {
        address anotherRateFeed = address(0xbeef);
        address[] memory dataProviders = new address[](1);
        dataProviders[0] = address(0xcafe);
        oracles.addRateFeed(anotherRateFeed, 2, 100, 5, 3, 120, dataProviders);

        (
            uint8 realWindowSize,
            uint16 realAllowedDeviation,
            uint8 realQuorum,
            uint8 realCertaintyThreshold,
            uint16 realAllowedStaleness
        ) = oracles.rateFeedConfig(anotherRateFeed);

        assertEq(realWindowSize, 2);
        assertEq(realAllowedDeviation, 100);
        assertEq(realQuorum, 5);
        assertEq(realCertaintyThreshold, 2);
        assertEq(realAllowedStaleness, 120);
    }

    /*
    TODO:
    - Only owner
    - Fails with invalid parameters (e.g. quorum > # providers)
    */
}

contract Oracles_removeRateFeed is OraclesTest {
    address private _anotherRateFeed = address(0xbeef);
    address private _aDataProvider = address(0xcafe);

    function setUp() public override {
        super.setUp();
        address[] memory dataProviders = new address[](1);
        dataProviders[0] = address(0xcafe);
        oracles.addRateFeed({
            rateFeedId: _anotherRateFeed,
            priceWindowSize: 2,
            allowedDeviation: 100,
            quorum: 5,
            certaintyThreshold: 3,
            allowedStalenessInSeconds: 120,
            dataProviders: dataProviders
        });
    }

    function test_removesTheRateFeed() public {
        oracles.removeRateFeed(_anotherRateFeed);

        (uint8 realWindowSize, , , , ) = oracles.rateFeedConfig(
            _anotherRateFeed
        );
        assertEq(realWindowSize, 0);
    }

    /*
    TODO:
    - Only owner
    */
}

contract Oracles_addDataProvider is OraclesTest {
    /*
    TODO:
    - Only owner
    */
}

contract Oracles_removeDataProvider is OraclesTest {
    /*
    TODO:
    - Only owner
    */
}
