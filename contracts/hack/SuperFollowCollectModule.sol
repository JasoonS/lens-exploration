// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.13;

import {ICollectModule} from '../interfaces/ICollectModule.sol';
import {ILensHub} from '../interfaces/ILensHub.sol';
import {ModuleBase} from '../core/modules/ModuleBase.sol';
import {FollowValidationModuleBase} from '../core/modules/FollowValidationModuleBase.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {SuperFollowModule} from './SuperFollowModule.sol';

/**
 * @title SuperFollowCollectModule
 * @author Float Capital
 * *
 * This module works by allowing only super followers to collect content.
 */
contract SuperFollowCollectModule is FollowValidationModuleBase, ICollectModule {
    constructor(address hub) ModuleBase(hub) {}

    mapping(uint256 => mapping(uint256 => bool)) internal _followerOnlyByPublicationByProfile;

    /**
     * @dev There is nothing needed at initialization.
     */
    function initializePublicationCollectModule(
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external override onlyHub returns (bytes memory) {
        bool followerOnly = abi.decode(data, (bool));
        if (followerOnly) _followerOnlyByPublicationByProfile[profileId][pubId] = true;
        return data;
    }

    /**
     * @dev Processes a collect by:
     *  1. Ensuring the collector is a follower (1st step)
     *  2. Ensure that the collector is a super follower (LFG)
     */
    function processCollect(
        uint256 referrerProfileId,
        address collector,
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external view override {
        if (_followerOnlyByPublicationByProfile[profileId][pubId])
            _checkFollowValidity(profileId, collector);

        // Ensure they are a super follower
        address moduleAddress = ILensHub(HUB).getFollowModule(profileId);
        uint256 nftID = SuperFollowModule(moduleAddress).addressToNFT(collector);
        bool isSuperFollower = SuperFollowModule(moduleAddress).isSuperFollower(
            profileId,
            address(0), /* unused arg */
            nftID
        );
        require(isSuperFollower, 'not super follower');
    }
}
