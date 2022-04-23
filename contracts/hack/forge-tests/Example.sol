// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import '@float-capital/ds-test/src/test.sol';

import '../SuperFollowModule.sol';

contract ExampleTest is DSTest {
    SuperFollowModule followModule;

    function setUp() public {
        followModule = new SuperFollowModule(address(5));

        // followModule.initializeFollowModule(321, abi.encode(22));
    }

    function testExample() public {
        assertTrue(true);
    }
}
