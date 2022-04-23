// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import '@float-capital/ds-test/src/test.sol';

import '../SuperFollowModule.sol';

contract ExampleTest is DSTest {
    SuperFollowModule followModule;

    uint256 constant patronageDenominator = 1000000000000;
    uint256 constant profileId = 123;

    function setUp() public {
        // followModule = new SuperFollowModule(address(5), patronageDenominator);
        // SuperFollowModule.InitializerInput memory initializerInput = SuperFollowModule
        //     .InitializerInput(
        //         20,
        //         patronageDenominator / 10, /* 10% anually */
        //         address(20000)
        //     );
        // followModule.initializeFollowModule(profileId, abi.encode(initializerInput));
    }

    function basicFlow() public {
        // followModule.
        assertTrue(true);
    }
}
