///// this contract is heavily inspired by the wildcards contract (V2): https://github.com/wildcards-world/contracts/blob/master/mainnet/contracts/previousVersions/WildcardSteward_v2.sol
//         All credit to the awesome wildcards team 💪

pragma solidity 0.8.13;

import {IFollowModule} from '../interfaces/IFollowModule.sol';
import {ModuleBase} from '../core/modules/ModuleBase.sol';
import {FollowValidatorFollowModuleBase} from '../core/modules/follow/FollowValidatorFollowModuleBase.sol';

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
    // profileId => followNFTTokenId => state
    mapping(uint256 => mapping(uint256 => FollowState)) public state;

    address public admin;

    // profileId => max number of super followers
    mapping(uint256 => uint256) numberOfSuperFollowers;

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

    // modifier onlyPatron(uint256 followNFTTokenId) {
    //     require(msg.sender == currentPatron[followNFTTokenId], 'Not patron');
    //     _;
    // }

    modifier onlyAdmin() {
        require(msg.sender == admin, 'Not admin');
        _;
    }

    // modifier onlyReceivingbeneficiaryOrAdmin(uint256 followNFTTokenId) {
    //     require(
    //         msg.sender == beneficiary[followNFTTokenId] || msg.sender == admin,
    //         'Not beneficiary or admin'
    //     );
    //     _;
    // }

    modifier collectPatronage(uint256 profileId, uint256 followNFTTokenId) {
        _collectPatronage(profileId, followNFTTokenId);
        _;
    }

    // modifier collectPatronageAddress(address tokenPatron) {
    //     _collectPatronagePatron(tokenPatron);
    //     _;
    // }

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

    function buy(
        uint256 profileId,
        uint256 followNFTTokenId,
        uint256 _newPrice,
        uint256 previousPrice
    ) public payable collectPatronage(profileId, followNFTTokenId) {
        /* 
        // require(state[profileId][followNFTTokenId] == FollowState.Owned, 'token on auction');
        require(price[tokenId] == previousPrice, 'must specify current price accurately');
        require(_newPrice > 0, 'Price is zero');
        require(msg.value > price[followNFTTokenId], 'Not enough'); // >, coz need to have at least something for deposit

        if (state[followNFTTokenId] == StewardState.Owned) {
            uint256 totalToPayBack = price[followNFTTokenId];
            // NOTE: pay back the deposit only if it is the only token the patron owns.
            if (
                totalPatronOwnedTokenCost[tokenPatron] ==
                price[followNFTTokenId].mul(patronageNumerator[followNFTTokenId])
            ) {
                totalToPayBack = totalToPayBack.add(deposit[tokenPatron]);
                deposit[tokenPatron] = 0;
            }

            // pay previous owner their price + deposit back.
            address payable payableCurrentPatron = address(uint160(tokenPatron));
            (bool transferSuccess, ) = payableCurrentPatron.call.gas(2300).value(totalToPayBack)(
                ''
            );
            if (!transferSuccess) {
                deposit[tokenPatron] = deposit[tokenPatron].add(totalToPayBack);
            }
        } else if (state[followNFTTokenId] == StewardState.Foreclosed) {
            state[followNFTTokenId] = StewardState.Owned;
            timeLastCollected[followNFTTokenId] = now;
            timeLastCollectedPatron[msg.sender] = now;
        }

        deposit[msg.sender] = deposit[msg.sender].add(msg.value.sub(price[followNFTTokenId]));
        transferAssetTokenTo(followNFTTokenId, currentOwner, tokenPatron, msg.sender, _newPrice);
        emit Buy(followNFTTokenId, msg.sender, _newPrice); */
    }
}

contract SuperFollowModule is IFollowModule, FollowValidatorFollowModuleBase, HarbergerTaxStuff {
    constructor(address hub) ModuleBase(hub) {}

    struct InitializerInput {
        uint256 numberOfSuperFollowers;
        uint256 patronageNumerator;
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

        numberOfSuperFollowers[profileId] = inputData.numberOfSuperFollowers;
        patronageNumerator[profileId] = inputData.patronageNumerator;

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
