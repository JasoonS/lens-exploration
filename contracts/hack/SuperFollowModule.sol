///// this contract is heavily inspired by the wildcards contract (V2): https://github.com/wildcards-world/contracts/blob/master/mainnet/contracts/previousVersions/WildcardSteward_v2.sol
//         All credit to the awesome wildcards team 💪

pragma solidity 0.8.13;

import {IFollowModule} from '../interfaces/IFollowModule.sol';
import {ModuleBase} from '../core/modules/ModuleBase.sol';
import {FollowValidatorFollowModuleBase} from '../core/modules/follow/FollowValidatorFollowModuleBase.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {ILensHub} from '../interfaces/ILensHub.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import 'hardhat/console.sol';

/*
// NOTE:
   -- This contract has some role access holes, hackathon vibes.

// TODO:
   -- Add more customization, and admin roles to edit configuration.
*/
contract HarbergerTaxStuff {
    address public hub;

    constructor(uint256 _patronageDenominator, address _HUB) {
        patronageDenominator = _patronageDenominator;
        hub = _HUB;
    }

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
    // profileId => followNFTTokenId => state
    mapping(uint256 => mapping(uint256 => FollowState)) public state;

    address public admin;

    // profileId => max number of super followers
    mapping(uint256 => uint256) maxNumberOfSuperFollowers; // need to set in constructor!!
    mapping(uint256 => uint256) numberOfSuperFollowers;

    mapping(uint256 => address) whitelistedCollateralUsed; // need to initialize.

    //////////////// NEW variables in v2///////////////////
    // mapping(uint256 => uint256) public tokenGenerationRate; // we can reuse the patronage denominator

    // MintManager public mintManager;

    event Buy(uint256 indexed followNFTTokenId, address indexed owner, uint256 price);
    event PriceChange(uint256 indexed followNFTTokenId, uint256 newPrice);
    event Foreclosure(address indexed prevOwner, uint256 foreclosureTime);
    event RemainingDepositUpdate(address indexed tokenPatron, uint256 remainingDeposit);

    event AddToken(
        uint256 indexed followNFTTokenId,
        uint256 patronageNumerator,
        uint256 tokenGenerationRate
    );
    // QUESTION: in future versions, should these two events (CollectPatronage and CollectLoyalty) be combined into one? - they only ever happen at the same time.
    event CollectPatronage(
        uint256 indexed followNFTTokenId,
        address indexed patron,
        uint256 remainingDeposit,
        uint256 amountReceived
    );
    event CollectLoyalty(
        uint256 indexed followNFTTokenId,
        address indexed patron,
        uint256 amountRecieved
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, 'Not admin');
        _;
    }

    modifier collectPatronage(uint256 profileId, uint256 followNFTTokenId) {
        _collectPatronage(profileId, followNFTTokenId);
        _;
    }

    function patronageOwed(uint256 profileId, uint256 followNFTTokenId)
        public
        view
        returns (uint256 patronageDue)
    {
        uint256 tokenTimeLastCollected = timeLastCollected[profileId][followNFTTokenId];
        if (tokenTimeLastCollected == 0) return 0;

        return
            ((price[profileId][followNFTTokenId] * (block.timestamp - tokenTimeLastCollected)) /
                (patronageDenominator)) / (365 days);
    }

    function _foreclose(uint256 profileId, uint256 followNFTTokenId) internal {
        // become steward of assetToken (aka foreclose)
        state[profileId][followNFTTokenId] = FollowState.NormalFollow;
        numberOfSuperFollowers[profileId]--; // decrement number of superfollowers

        // send the token anywhere?
        // emit Foreclosure(currentOwner, timeLastCollected[followNFTTokenId]);
    }

    function _collectPatronage(uint256 profileId, uint256 followNFTTokenId) public {
        // determine patronage to pay
        if (state[profileId][followNFTTokenId] == FollowState.SuperFollow) {
            // address currentOwner = currentPatron[followNFTTokenId];
            uint256 previousTokenCollection = timeLastCollected[profileId][followNFTTokenId];
            uint256 patronageOwedByTokenPatron = patronageOwed(profileId, followNFTTokenId);
            // _collectLoyalty(followNFTTokenId); // This needs to be called before before the token may be foreclosed next section
            uint256 collection;
            uint256 currentDeposit = deposit[profileId][followNFTTokenId];

            // it should foreclose and take stewardship
            if (patronageOwedByTokenPatron >= currentDeposit) {
                uint256 newTimeLastCollected = previousTokenCollection +
                    (
                        (((block.timestamp - (previousTokenCollection)) *
                            (deposit[profileId][followNFTTokenId])) / (patronageOwedByTokenPatron))
                    );

                timeLastCollected[profileId][followNFTTokenId] = newTimeLastCollected;
                // timeLastCollectedPatron[currentOwner] = newTimeLastCollected;
                collection =
                    (((price[profileId][followNFTTokenId] *
                        (newTimeLastCollected - (previousTokenCollection))) *
                        (patronageNumerator[followNFTTokenId])) / (patronageDenominator)) /
                    (365 days);
                deposit[profileId][followNFTTokenId] = 0;
                _foreclose(profileId, followNFTTokenId);
            } else {
                collection =
                    (((price[profileId][followNFTTokenId] *
                        (block.timestamp - (previousTokenCollection))) *
                        (patronageNumerator[followNFTTokenId])) / (patronageDenominator)) /
                    (365 days);

                timeLastCollected[profileId][followNFTTokenId] = block.timestamp;
                deposit[profileId][followNFTTokenId] =
                    currentDeposit -
                    (patronageOwedByTokenPatron);
            }

            beneficiaryFunds[profileId] = beneficiaryFunds[profileId] + (collection);
            // if foreclosed, tokens are minted and sent to the steward since _foreclose is already called.
            // emit CollectPatronage(followNFTTokenId, currentOwner, deposit[currentOwner], collection);
        }
    }

    // Used to upgrade an existing follow to super follow NFT.
    // Requires you to already own a follower NFT.
    // oldFollowNFTTokenId is the id of the follow token you are going to take the super privledge from
    // newFollowNFTTokenId is the id of your follow tokenID that you are going to upgrade.
    // If this is before match super followers are reached, simply pass oldFollowNFTTokenId = newFollowNFTTokenId
    // check weird case where collect patronage makes the oldFollowNFTTokenId no longer a super token!
    function upgradeToSuperFollower(
        uint256 profileId,
        uint256 oldFollowNFTTokenId,
        uint256 newFollowNFTTokenId,
        uint256 _newPrice,
        uint256 previousPrice,
        uint256 depositAmount
    ) public payable collectPatronage(profileId, oldFollowNFTTokenId) {
        require(
            price[profileId][oldFollowNFTTokenId] == previousPrice,
            'must specify current price accurately'
        );
        require(_newPrice > 0, 'Price is zero');
        require(
            state[profileId][newFollowNFTTokenId] == FollowState.NormalFollow,
            'can only upgrade normal token'
        );

        uint256 amountForBuyerToTransfer = (state[profileId][oldFollowNFTTokenId] ==
            FollowState.SuperFollow)
            ? price[profileId][oldFollowNFTTokenId] + depositAmount
            : depositAmount;

        // Take the users whitelisted tokens.
        IERC20(whitelistedCollateralUsed[profileId]).transferFrom(
            msg.sender,
            address(this),
            amountForBuyerToTransfer
        );

        address followNFT = ILensHub(hub).getFollowNFT(profileId);

        address newOwner = IERC721(followNFT).ownerOf(newFollowNFTTokenId);
        require(newOwner == msg.sender, 'need to be owner to upgrade');

        // Case 1 - it is already a super follow token.
        if (state[profileId][oldFollowNFTTokenId] == FollowState.SuperFollow) {
            uint256 totalToPayBack = price[profileId][oldFollowNFTTokenId] +
                deposit[profileId][oldFollowNFTTokenId];

            deposit[profileId][oldFollowNFTTokenId] = 0;
            price[profileId][oldFollowNFTTokenId] = 0;

            address paymentRecipient = IERC721(followNFT).ownerOf(oldFollowNFTTokenId);
            // transfer this back to old user.
            IERC20(whitelistedCollateralUsed[profileId]).transfer(paymentRecipient, totalToPayBack);

            // correct states
            state[profileId][oldFollowNFTTokenId] == FollowState.NormalFollow;
        } else {
            // Case 2 - it is a normal token.
            numberOfSuperFollowers[profileId]++;
            require(
                numberOfSuperFollowers[profileId] <= maxNumberOfSuperFollowers[profileId],
                'All super follow spots are claimed.'
            );
        }

        timeLastCollected[profileId][newFollowNFTTokenId] = block.timestamp;
        deposit[profileId][newFollowNFTTokenId] = depositAmount;
        state[profileId][newFollowNFTTokenId] == FollowState.SuperFollow;

        // emit Buy(followNFTTokenId, msg.sender, _newPrice);
    }
}

contract SuperFollowModule is IFollowModule, FollowValidatorFollowModuleBase, HarbergerTaxStuff {
    constructor(address hub, uint256 _patronageDenominator)
        HarbergerTaxStuff(_patronageDenominator, hub)
        ModuleBase(hub)
    {}

    struct InitializerInput {
        uint256 numberOfSuperFollowers;
        uint256 patronageNumerator;
        address erc20PaymentTokenAddress;
    }

    function hackToEncodeValueAsBytes(
        uint256 numberOfSuperFollowers,
        uint256 patronageNumerator,
        address erc20PaymentTokenAddress
    ) public pure returns (bytes memory) {
        InitializerInput memory initializerInput = InitializerInput(
            numberOfSuperFollowers,
            patronageNumerator,
            erc20PaymentTokenAddress
        );

        return abi.encode(initializerInput);
    }

    function initializeFollowModule(uint256 profileId, bytes calldata data)
        external
        returns (bytes memory)
    {
        InitializerInput memory inputData = abi.decode(data, (InitializerInput));

        // TODO: do some more data validation on the input data.
        require(
            inputData.numberOfSuperFollowers > 0 && inputData.numberOfSuperFollowers < 100000,
            'num super followers not in range'
        );
        require(
            inputData.patronageNumerator >= (patronageDenominator / 100) && /* 1% anually */
                inputData.patronageNumerator <= (patronageDenominator * 10), /* 1000% anually */
            'patronageNumerator not in range'
        );

        maxNumberOfSuperFollowers[profileId] = inputData.numberOfSuperFollowers;
        patronageNumerator[profileId] = inputData.patronageNumerator;
        whitelistedCollateralUsed[profileId] = inputData.erc20PaymentTokenAddress;

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
        // TODO: Check that the address owns the followNFTTokenId.
        if (state[profileId][followNFTTokenId] == FollowState.SuperFollow) {
            if (patronageOwed(profileId, followNFTTokenId) < deposit[profileId][followNFTTokenId]) {
                return true;
            } else {
                return false;
            }
        } else {
            return false;
        }
    }
}
