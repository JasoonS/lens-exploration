// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import '@float-capital/ds-test/src/test.sol';

import '../FunkyFollowModule.sol';

contract ExampleTest is DSTest {
    FunkyFollowModule followModule;

    function setUp() public {
        followModule = new FunkyFollowModule();

        followModule.initializeFollowModule(321, abi.encode(22));
    }

    function testExample() public {
        assertTrue(true);
    }
}
