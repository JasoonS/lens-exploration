pragma solidity 0.8.13;

import {IFollowModule} from '../interfaces/IFollowModule.sol';
import {ModuleBase} from '../core/modules/ModuleBase.sol';
import {FollowValidatorFollowModuleBase} from '../core/modules/follow/FollowValidatorFollowModuleBase.sol';

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

    modifier collectPatronage(uint256 profileId, uint256 tokenId) {
        _collectPatronage(profileId, tokenId);
        _;
    }

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

contract SuperFollowModule is IFollowModule, FollowValidatorFollowModuleBase, HarbergerTaxStuff {
    // profileId => max number of super followers
    mapping(uint256 => uint256) numberOfSuperFollowers;
    // profileId => follewerId => isFollower
    mapping(uint256 => mapping(uint256 => bool)) registeredSuperFollower;

    constructor(address hub) ModuleBase(hub) {}

    struct InitializerInput {
        uint256 patronageDenominator;
    }

    function initializeFollowModule(uint256 profileId, bytes calldata data)
        external
        returns (bytes memory)
    {
        InitializerInput memory inputData = abi.decode(data, (InitializerInput));

        patronageDenominator = inputData.patronageDenominator;

        return abi.encode(0);
    }

    function processFollow(
        address follower,
        uint256 profileId,
        bytes calldata data
    ) external override {}

    function followModuleTransferHook(
        uint256 profileId,
        address from,
        address to,
        uint256 followNFTTokenId
    ) external {
        // does nothing
    }

    function isSuperFollower(
        uint256 profileId,
        address follower,
        uint256 followNFTTokenId
    ) external view returns (bool) {
        // TODO: collect h-tax and make sure follower is liquid.
        if (state[profileId][followNFTTokenId] == FollowState.SuperFollow) {
            if (
                patronageOwed(profileId, followNFTTokenId) >= deposit[profileId][followNFTTokenId]
            ) {
                return true;
            } else {
                return false;
            }
        } else {
            return false;
        }
    }
}
