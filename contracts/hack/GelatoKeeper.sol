/*
background: This is an experimental, quickly hashed together contract.
It will never hold value of any kind.
*/

import {SuperFollowModule} from './SuperFollowModule.sol';
import {ILensHub} from '../interfaces/ILensHub.sol';
import {ModuleBase} from '../core/modules/ModuleBase.sol';

pragma solidity 0.8.13;

contract GelatoKeeper {
    address hub;

    constructor(address _hub) {
        hub = _hub;
    }

    // Used by Gelato resolver
    // https://docs.gelato.network/guides/writing-a-resolver/smart-contract-resolver
    function shouldForecloseSuperFollower(uint256 profileId, uint256 tokenIDStart)
        external
        returns (bool canExec, bytes memory execPayload)
    {
        // Loop through the 10 golden circle members and ensure they are not foreclosed.
        for (uint256 i = tokenIDStart; i < 10; i++) {
            // Ensure they are a super follower
            address moduleAddress = ILensHub(hub).getFollowModule(profileId);
            canExec =
                SuperFollowModule(moduleAddress).patronageOwed(profileId, tokenIDStart) <
                SuperFollowModule(moduleAddress).deposit(profileId, tokenIDStart);

            execPayload = abi.encodeWithSelector(
                SuperFollowModule(moduleAddress)._collectPatronage.selector,
                profileId,
                tokenIDStart
            );

            if (canExec) {
                break;
            }
        }
    }
}
