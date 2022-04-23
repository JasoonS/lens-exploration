pragma solidity 0.8.13;

import '../interfaces/IFollowModule.sol';

///// this contract is heavily inspired by the wildcards contract (V2): https://github.com/wildcards-world/contracts/blob/master/mainnet/contracts/previousVersions/WildcardSteward_v2.sol

contract MintManager {
    // Might not use this contract - intention is to manage payout of erc20 tokens.
}

contract HarbergerTaxStuff {
    /*
    This smart contract collects patronage from current owner through a Harberger tax model and 
    takes stewardship of the asset token if the patron can't pay anymore.

    Harberger Tax (COST): 
    - Asset is always on sale.
    - You have to have a price set.
    - Tax (Patronage) is paid to maintain ownership.
    - Steward maints control over ERC721.
    */
    mapping(uint256 => mapping(uint256 => uint256)) public price; //in wei

    // mapping from profileId
    // mapping(uint256 => uint256) public timeLastCollected; // might delete
    // mapping from followerId
    mapping(uint256 => mapping(uint256 => uint256)) public timeLastCollected;
    mapping(uint256 => mapping(uint256 => uint256)) public deposit;

    // mapping from profileId to fund reciever
    mapping(uint256 => address) public beneficiary; // non-profit beneficiary
    // mapping from profileId
    mapping(uint256 => uint256) public beneficiaryFunds; // might delete

    // mapping(uint256 => address) public currentPatron; // This is different to the current token owner.
    // mapping(uint256 => mapping(address => bool)) public patrons;
    // mapping(uint256 => mapping(address => uint256)) public timeHeld;

    // mapping(uint256 => uint256) public timeAcquired;

    // profileId => numerator
    mapping(uint256 => uint256) public patronageNumerator;
    uint256 public patronageDenominator;

    enum FollowState {
        NormalFollow,
        SuperFollow
    }
    // profileId => tokenId => state
    mapping(uint256 => mapping(uint256 => FollowState)) public state;

    address public admin;

    //////////////// NEW variables in v2///////////////////
    // mapping(uint256 => uint256) public tokenGenerationRate; // we can reuse the patronage denominator

    // MintManager public mintManager;

    event Buy(uint256 indexed tokenId, address indexed owner, uint256 price);
    event PriceChange(uint256 indexed tokenId, uint256 newPrice);
    event Foreclosure(address indexed prevOwner, uint256 foreclosureTime);
    event RemainingDepositUpdate(address indexed tokenPatron, uint256 remainingDeposit);

    event AddToken(
        uint256 indexed tokenId,
        uint256 patronageNumerator,
        uint256 tokenGenerationRate
    );
    // QUESTION: in future versions, should these two events (CollectPatronage and CollectLoyalty) be combined into one? - they only ever happen at the same time.
    event CollectPatronage(
        uint256 indexed tokenId,
        address indexed patron,
        uint256 remainingDeposit,
        uint256 amountReceived
    );
    event CollectLoyalty(uint256 indexed tokenId, address indexed patron, uint256 amountRecieved);

    // modifier onlyPatron(uint256 tokenId) {
    //     require(msg.sender == currentPatron[tokenId], 'Not patron');
    //     _;
    // }

    modifier onlyAdmin() {
        require(msg.sender == admin, 'Not admin');
        _;
    }

    // modifier onlyReceivingbeneficiaryOrAdmin(uint256 tokenId) {
    //     require(
    //         msg.sender == beneficiary[tokenId] || msg.sender == admin,
    //         'Not beneficiary or admin'
    //     );
    //     _;
    // }

    // modifier collectPatronage(uint256 tokenId) {
    //     _collectPatronage(tokenId);
    //     _;
    // }

    // modifier collectPatronageAddress(address tokenPatron) {
    //     _collectPatronagePatron(tokenPatron);
    //     _;
    // }

    function patronageOwed(uint256 profileId, uint256 tokenId)
        public
        view
        returns (uint256 patronageDue)
    {
        uint256 tokenTimeLastCollected = timeLastCollected[profileId][tokenId];
        if (tokenTimeLastCollected == 0) return 0;

        return
            ((price[profileId][tokenId] * (block.timestamp - tokenTimeLastCollected)) /
                (patronageDenominator)) / (365 days);
    }

    function _foreclose(uint256 profileId, uint256 tokenId) internal {
        // become steward of assetToken (aka foreclose)
        state[profileId][tokenId] = FollowState.NormalFollow;

        // emit Foreclosure(currentOwner, timeLastCollected[tokenId]);
    }

    function _collectPatronage(uint256 profileId, uint256 tokenId) public {
        // determine patronage to pay
        if (state[profileId][tokenId] == FollowState.SuperFollow) {
            // address currentOwner = currentPatron[tokenId];
            uint256 previousTokenCollection = timeLastCollected[profileId][tokenId];
            uint256 patronageOwedByTokenPatron = patronageOwed(profileId, tokenId);
            // _collectLoyalty(tokenId); // This needs to be called before before the token may be foreclosed next section
            uint256 collection;
            uint256 currentDeposit = deposit[profileId][tokenId];

            // it should foreclose and take stewardship
            if (patronageOwedByTokenPatron >= currentDeposit) {
                uint256 newTimeLastCollected = previousTokenCollection +
                    (
                        (((block.timestamp - (previousTokenCollection)) *
                            (deposit[profileId][tokenId])) / (patronageOwedByTokenPatron))
                    );

                timeLastCollected[profileId][tokenId] = newTimeLastCollected;
                // timeLastCollectedPatron[currentOwner] = newTimeLastCollected;
                collection =
                    (((price[profileId][tokenId] *
                        (newTimeLastCollected - (previousTokenCollection))) *
                        (patronageNumerator[tokenId])) / (patronageDenominator)) /
                    (365 days);
                deposit[profileId][tokenId] = 0;
                _foreclose(profileId, tokenId);
            } else {
                collection =
                    (((price[profileId][tokenId] * (block.timestamp - (previousTokenCollection))) *
                        (patronageNumerator[tokenId])) / (patronageDenominator)) /
                    (365 days);

                timeLastCollected[profileId][tokenId] = block.timestamp;
                deposit[profileId][tokenId] = currentDeposit - (patronageOwedByTokenPatron);
            }

            beneficiaryFunds[profileId] = beneficiaryFunds[profileId] + (collection);
            // if foreclosed, tokens are minted and sent to the steward since _foreclose is already called.
            // emit CollectPatronage(tokenId, currentOwner, deposit[currentOwner], collection);
        }
    }
}

contract SuperFollowModule is IFollowModule, HarbergerTaxStuff {
    // profileId => max number of super followers
    mapping(uint256 => uint256) numberOfSuperFollowers;
    // profileId => follewerId => isFollower
    mapping(uint256 => mapping(uint256 => bool)) registeredSuperFollower;

    struct InitializerInput {
        uint256 patronageDenominator;
    }

    /**
     * @notice Initializes a follow module for a given Lens profile. This can only be called by the hub contract.
     *
     * @param profileId The token ID of the profile to initialize this follow module for.
     * @param data Arbitrary data passed by the profile creator.
     *
     * @return bytes The encoded data to emit in the hub.
     */
    function initializeFollowModule(uint256 profileId, bytes calldata data)
        external
        returns (bytes memory)
    {
        InitializerInput memory inputData = abi.decode(data, (InitializerInput));

        patronageDenominator = inputData.patronageDenominator;

        return abi.encode(0);
    }

    /**
     * @notice Processes a given follow, this can only be called from the LensHub contract.
     *
     * @param follower The follower address.
     * @param profileId The token ID of the profile being followed.
     * @param data Arbitrary data passed by the follower.
     */
    function processFollow(
        address follower,
        uint256 profileId,
        bytes calldata data
    ) external {}

    /**
     * @notice This is a transfer hook that is called upon follow NFT transfer in `beforeTokenTransfer. This can
     * only be called from the LensHub contract.
     *
     * NOTE: Special care needs to be taken here: It is possible that follow NFTs were issued before this module
     * was initialized if the profile's follow module was previously different. This transfer hook should take this
     * into consideration, especially when the module holds state associated with individual follow NFTs.
     *
     * @param profileId The token ID of the profile associated with the follow NFT being transferred.
     * @param from The address sending the follow NFT.
     * @param to The address receiving the follow NFT.
     * @param followNFTTokenId The token ID of the follow NFT being transferred.
     */
    function followModuleTransferHook(
        uint256 profileId,
        address from,
        address to,
        uint256 followNFTTokenId
    ) external {}

    /**
     * @notice This is a helper function that could be used in conjunction with specific collect modules.
     *
     * NOTE: This function IS meant to replace a check on follower NFT ownership.
     *
     * NOTE: It is assumed that not all collect modules are aware of the token ID to pass. In these cases,
     * this should receive a `followNFTTokenId` of 0, which is impossible regardless.
     *
     * One example of a use case for this would be a subscription-based following system:
     *      1. The collect module:
     *          - Decodes a follower NFT token ID from user-passed data.
     *          - Fetches the follow module from the hub.
     *          - Calls `isFollowing` passing the profile ID, follower & follower token ID and checks it returned true.
     *      2. The follow module:
     *          - Validates the subscription status for that given NFT, reverting on an invalid subscription.
     *
     * @param profileId The token ID of the profile to validate the follow for.
     * @param follower The follower address to validate the follow for.
     * @param followNFTTokenId The followNFT token ID to validate the follow for.
     *
     * @return true if the given address is following the given profile ID, false otherwise.
     */
    function isFollowing(
        uint256 profileId,
        address follower,
        uint256 followNFTTokenId
    ) external view returns (bool) {
        return true;
    }

    function isSuperFollower(
        uint256 profileId,
        address follower,
        uint256 followNFTTokenId
    ) external view returns (bool) {
        // TODO: collect h-tax and make sure follower is liquid.
        return registeredSuperFollower[profileId][followNFTTokenId];
    }
}
