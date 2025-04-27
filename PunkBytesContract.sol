// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// NFT Contracts
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/token/ERC721/ERC721Upgradeable.sol";
import {ERC721BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import {ERC721PausableUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import {ERC721URIStorageUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

// Utilities
import {Initializable} from "@openzeppelin/contracts-upgradeable@5.0.0/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/proxy/utils/UUPSUpgradeable.sol";

import "@openzeppelin/contracts@5.0.0/token/ERC20/utils/SafeERC20.sol";

import {IVRFCoordinatorV2Plus} from "./VRF/IVRFCoordinatorV2Plus.sol";
import {VRFV2PlusClient} from "./VRF/VRFV2PlusClient.sol";

import "./interfaces/IClassDetails.sol";
import "./interfaces/IMissionDetails.sol";

abstract contract IERC20Extended is IERC20 {
    function decimals() public view virtual returns (uint8);
}

contract PunkBytesContract is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable,
                    ERC721PausableUpgradeable, OwnableUpgradeable, ERC721BurnableUpgradeable, UUPSUpgradeable {

    uint256 public nextTokenId;
    using SafeERC20 for IERC20Extended;
    uint256 public constant BASIS_POINTS = 10000; // 5000 = 50%

    /* VRF START */

            struct RequestStatus {
                bool fulfilled;
                bool exists;
                uint256[] randomWords;
                uint256 tokenId;
                uint256 vrfType;
            }

        mapping(uint256 => RequestStatus) public s_requests;
        IVRFCoordinatorV2Plus public COORDINATOR;

        uint256 public s_subscriptionId;
        uint256[] public requestIds;
        uint256 public lastRequestId;
        bytes32 public keyHash;

        uint32 public callbackGasLimit;
        uint16 public requestConfirmations;

    /* VRF END */

    address public classContract;
    address public missionContract;
    address public marketplaceContract;

    bool public nftTransfers; // toggle for transferability 

    address public feeWallet;
    address public vaultAddress;
    address public rewardFeeWallet;

    IERC20Extended public mintCurrency;

    uint256 public mintFee;
    uint256 public rewardFee;

    bool public vrfNative;
    uint256 public vrfCost;

    uint256 public LifeCost;
    uint256 public energyCost;

    uint256 public energyRegenAmount;
    uint256 public energyRegenInterval;

    uint256 public loyaltyPoint; // Potential reward system 
    
    mapping(address => uint256) public userPoints;
    mapping(address => uint256) public claimableRewards;
    mapping(uint256 => uint256) public seasonTotalPoints;

    uint256 public currentSeason;
    uint256 public totalSeasonCount;

    struct seasonInfo {
        uint256 seasonId;
        uint256 endDate;
        uint256 totalRewards;
        uint256 totalPoints;
        uint256 totalAddresses;
    }

    address[] public seasonAddresses; // unique participants
    mapping(uint256 => seasonInfo) public allSeasons;

    event ContractInitialized(address owner);

        /// @custom:oz-upgrades-unsafe-allow constructor
        constructor() { _disableInitializers(); }

    function initialize() public initializer {

    __ERC721_init("punkbytes", "PUNK");
    __ERC721Enumerable_init();
    __ERC721URIStorage_init();
    __ERC721Pausable_init();
    __ERC721Burnable_init();
    __Ownable_init(msg.sender);
    __UUPSUpgradeable_init();

        s_subscriptionId = 7702849726606705533155550027540487965509207440469620364675695306739514636546;
        keyHash = 0xea7f56be19583eeb8255aa79f16d8bd8a64cedf68e42fefee1c9ac5372b1a102;
        requestConfirmations = 3;

        COORDINATOR = IVRFCoordinatorV2Plus(
            0xE40895D055bccd2053dD0638C9695E326152b1A4
        );
        callbackGasLimit = 2500000;

        vaultAddress = 0x8EDC29a84e86975266eF7A45bd76969B6051FD48;
        feeWallet = 0x5Eb62C9261e2189c9664a7953F816075B3f2e908;
        rewardFeeWallet = 0x2f4F63840cB93334ee35030bb92849a66735911a;

            mintFee = 1500;
            rewardFee = 1000;

        mintCurrency = IERC20Extended(0x5b583Db39E574C34aF5c31D4B12B40AB79F90C17); // mockUSDC addr
        // mintCurrency = IERC20Extended(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E); // USDC for prod
  
            LifeCost = 25000000;
            energyCost = 5000000;

            vrfCost = 0;
            //  vrfCost = 900000000000000; // prod

        energyRegenInterval = 3600;
        energyRegenAmount = 2;
        loyaltyPoint = 1;

        // emit ContractInitialized(msg.sender);
    }

    modifier onlyOwner_orMarketplace() {
        require(msg.sender == owner() || msg.sender == marketplaceContract, "");
        _;
    }

    // Function for the owner to assign points to a user
    function assignPoints(address _user, uint256 _points) public onlyOwner_orMarketplace {
        require(_user != address(0), "");
        require(_points > 0, "");

        if (userPoints[_user] == 0) {
            seasonAddresses.push(_user);
        }

        userPoints[_user] += _points;
        seasonTotalPoints[currentSeason] += _points;
    }

    function claimReward(uint256 _amount) public whenNotPaused {
        require(claimableRewards[msg.sender] >= _amount && _amount > 0, "");
        claimableRewards[msg.sender] -= _amount;
        mintCurrency.transfer(msg.sender, _amount);
    }

    // Distribute rewards, end season, zero out user points and reset addrs
    function endSeason(uint256 _totalRewards) public onlyOwner {

        uint256 _fee = (_totalRewards * rewardFee) / BASIS_POINTS;
        require(mintCurrency.transferFrom(msg.sender, address(rewardFeeWallet), _fee), "");

        _totalRewards -= _fee;

        require(mintCurrency.transferFrom(msg.sender, address(this), _totalRewards), "");
        require(seasonTotalPoints[currentSeason] > 0, "");

        for (uint256 i = 0; i < seasonAddresses.length; i++) {  

            uint256 _reward = (userPoints[seasonAddresses[i]] *
             _totalRewards) / seasonTotalPoints[currentSeason];

            userPoints[seasonAddresses[i]] = 0;
            claimableRewards[seasonAddresses[i]] += _reward;
        }

        allSeasons[currentSeason] = seasonInfo({
            seasonId: currentSeason,
            endDate: block.timestamp,
            totalRewards: _totalRewards,
            totalPoints: seasonTotalPoints[currentSeason],
            totalAddresses: seasonAddresses.length
        });
        delete seasonAddresses;
        // seasonTotalPoints[currentSeason] = 0;

        currentSeason++;
    }

    function getMissionVRF(uint256 _tokenId) public payable whenNotPaused {

        require(msg.value == vrfCost, "");
        require(feeWallet != address(0), "");

        (bool callSuccess, ) = payable(feeWallet).call{value: vrfCost}("");

        require(callSuccess, "");
        require(msg.sender == ownerOf(_tokenId), "");

        uint256 _tokenTotalMissions = IMissionDetails(missionContract).tokenTotalMissions(_tokenId);

        require(_tokenTotalMissions > 0, "");

        classDetailsContract.nftProperties_1 memory _properties_1 = IClassDetails(classContract).getNFTData_1(_tokenId);
        classDetailsContract.nftProperties_2 memory _properties_2 = IClassDetails(classContract).getNFTData_2(_tokenId);

        require(_properties_1.status == 2 || _properties_1.status == 3, "");

        _properties_1.status = 3;
        
        IClassDetails(classContract).updateNFTData(_tokenId, _properties_1, _properties_2);

        missionDetailsContract.missionParameters 
        memory _tokenMissions = IMissionDetails
        (missionContract).getTokenMissions(
            _tokenId,
            _tokenTotalMissions - 1,
            _tokenTotalMissions - 1
            )[0];

        require(
            ((!s_requests[_tokenMissions.requestId].fulfilled &&
            _tokenMissions.initiateEnd == 0 && (_tokenMissions.start + 
            _tokenMissions.missionInfo.minTimeNeed) < block.timestamp) || 
            
            (!s_requests[_tokenMissions.requestId].fulfilled &&
            (_tokenMissions.initiateEnd + 60 < block.timestamp) &&
            _tokenMissions.status == 2)), "");

        _tokenMissions.status = 2;
        _tokenMissions.requestId = getRandomNumber(1, _tokenId, 0);
        _tokenMissions.initiateEnd = block.timestamp;

        IMissionDetails(missionContract).updateTokenMission(
            _tokenId, _tokenTotalMissions - 1, _tokenMissions
        );
    }

    function completeMission(uint256 _tokenId) public whenNotPaused {
        require(msg.sender == ownerOf(_tokenId), "");

        classDetailsContract.nftProperties_1 memory _properties_1 = IClassDetails(classContract).getNFTData_1(_tokenId);
        classDetailsContract.nftProperties_2 memory _properties_2 = IClassDetails(classContract).getNFTData_2(_tokenId)
        ;
        (_properties_1, _properties_2) = IClassDetails(classContract).processEnergyGain(_properties_1, _properties_2);

        address user = ownerOf(_tokenId);
        require(_properties_1.status == 3, "");

        _properties_1.status = 1;

        uint256 _tokenTotalMissions = IMissionDetails(missionContract).tokenTotalMissions(_tokenId);
        missionDetailsContract.missionParameters memory _tokenMissions = IMissionDetails(missionContract).getTokenMissions(
                    _tokenId,
                    _tokenTotalMissions - 1,
                    _tokenTotalMissions - 1
                )[0];

        require(_tokenTotalMissions > 0, "");
        require(_tokenMissions.status == 2, "");
        require(_tokenMissions.end == 0, "");
        require(s_requests[_tokenMissions.requestId].fulfilled, "");

        uint256 _elapsedTime = (_tokenMissions.initiateEnd - _tokenMissions.start) / 60;
        require(_elapsedTime > 0, "");
        uint256 _random = s_requests[_tokenMissions.requestId].randomWords[0] % 10001;

        if ((_tokenMissions.missionInfo.riskLevel != 0) && (_random <= _tokenMissions.missionInfo.deathRate)) {

            // DEATH
            _tokenMissions.points = ((_elapsedTime * _tokenMissions.missionInfo.pointsPerMinute) * 1000) / BASIS_POINTS;
            uint256 age = getAge(_properties_2.mintingTimestamp);
            _tokenMissions.points += (((age * loyaltyPoint) * 1000) / BASIS_POINTS);
            _tokenMissions.status = 5;

            if (_properties_2.maxLives > 0) { _properties_2.availableLives--; }
            if (_properties_2.availableLives == 0 && _properties_2.maxLives > 0) {

                // BURN
                _properties_1.status = 0;
                internalBurn(_tokenId);
            }

        } else {

            if (_random <= (10000 - (_tokenMissions.missionInfo.successRate + _tokenMissions.missionInfo.deathRate))) {

                // FAIL
                _tokenMissions.points = ((_elapsedTime * _tokenMissions.missionInfo.pointsPerMinute) * 1000) / BASIS_POINTS;
                uint256 age = getAge(_properties_2.mintingTimestamp);
                _tokenMissions.points += (((age * loyaltyPoint) * 1000) / BASIS_POINTS);
                
                _tokenMissions.status = 4;

            } else {

                // SUCCESS
                _tokenMissions.points = _elapsedTime * _tokenMissions.missionInfo.pointsPerMinute;
                uint256 age = getAge(_properties_2.mintingTimestamp);
                _tokenMissions.points += (age * loyaltyPoint);

                _tokenMissions.status = 3;
            }
        }

        //_tokenMissions.result = block.timestamp;
        _tokenMissions.end = block.timestamp;

        seasonTotalPoints[currentSeason] += _tokenMissions.points;
        userPoints[user] += _tokenMissions.points;
        _tokenMissions.fullFillRequestId = s_requests[_tokenMissions.requestId].randomWords;

        bool found = false;
        for (uint256 i = 0; i < seasonAddresses.length; i++) {
            if (seasonAddresses[i] == user) { found = true; }
        }
        
        if (!found) { seasonAddresses.push(user); /* add player IF not found */ }
        
        IClassDetails(classContract).updateNFTData(
            _tokenId, _properties_1, _properties_2
        );

        IMissionDetails(missionContract).updateTokenMission(
            _tokenId, _tokenTotalMissions - 1, _tokenMissions
        );
    }

    function setCurrentSeason(uint256 _season) public onlyOwner { currentSeason = _season; }
    function setVRFNative(bool _status) public onlyOwner { vrfNative = _status; }

    function setLoyaltyPoint(uint256 _loyaltyPoint) public onlyOwner { loyaltyPoint = _loyaltyPoint; }

    function setEnergyRegenParam(uint256 _energyRegenInterval, uint256 _energyRegenAmount) public onlyOwner {
        require(_energyRegenInterval > 0, "");
        require(_energyRegenAmount > 0, "");
        energyRegenInterval = _energyRegenInterval;
        energyRegenAmount = _energyRegenAmount;
    }

    function setVRFCost(uint256 _vrfCost) public onlyOwner { vrfCost = _vrfCost;}
    function setEnergyCost(uint256 _cost) public onlyOwner { energyCost = _cost;}

    function pause() public onlyOwner { _pause(); }
    function unpause() public onlyOwner { _unpause(); }

    // Get age (In weeks)
    function getAge(uint256 _mintTimestamp) public view returns (uint256 _age) {
        uint256 elapsed = block.timestamp - _mintTimestamp;
        _age = elapsed / 604800;
    }

    function mintNFT(uint256 _classId) public whenNotPaused {
        classDetailsContract.classDetails_1 memory _details_1 = IClassDetails(classContract).getClassData_1(_classId);
        classDetailsContract.classDetails_2 memory _details_2 = IClassDetails(classContract).getClassData_2(_classId);

        require(IClassDetails(classContract).classTotalSupply(_classId) < _details_1.maxHardCap, "");
        require(_details_2.enabled, "");

        require(vaultAddress != address(0), "");
        require(feeWallet != address(0), "");

        uint256 amount;

        amount = _details_1.mintPrice;
        uint256 fee = (amount * mintFee) / BASIS_POINTS;

        amount = amount - fee;

        require(mintCurrency.transferFrom(msg.sender, vaultAddress, amount), "");
        require(mintCurrency.transferFrom(msg.sender, address(feeWallet), fee), "");

        IClassDetails(classContract).addNFTData(nextTokenId, _classId);
        safeMint(msg.sender, _details_2.tokenUri);
    }

    // Returns an array of all existing minted token IDs (ascending order)
    // function getMintedTokenIds() public view returns (uint256[] memory tokenIds) {

    //     // totalSupply() does not include burned tokens
    //     uint256 total = totalSupply(); // Get the number of existing tokens

    //     tokenIds = new uint256[](total);
            
    //     for (uint256 i = 0; i < total; i++) {
    //         tokenIds[i] = tokenByIndex(i);
    //     }
    //     return tokenIds;
    // }

    // Returns the number of NFTs owned by a specific wallet and their token IDs
    function getTokensByOwner(address wallet) public view returns (uint256 count, uint256[] memory tokenIds) {

        require(wallet != address(0), "");
        count = balanceOf(wallet);
        tokenIds = new uint256[](count);
            
        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(wallet, i);
        }
        return (count, tokenIds);
    }

    receive() external payable {}

    /// @notice used to withdraw any ERC20 token from the contract
    /// @param erc20 ERC20 address
    /// @param amount the amount withdrawn

    function withdrawFundsERC20(address erc20, uint256 amount) public onlyOwner {
        // if (IERC20Extended(erc20).balanceOf(address(this)) >= amount) {
        //     IERC20Extended(erc20).transfer(msg.sender, amount); }
        IERC20Extended(erc20).safeTransfer(msg.sender, amount);
    }

    function withdrawFundsNative(uint256 amount) public onlyOwner {
        if (address(this).balance >= amount) {
                (bool sent, ) = msg.sender.call{value: amount}("");
                require(sent);
        }
    }

    function safeMint(address to, string memory uri) internal returns (uint256) {
        uint256 tokenId = nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        // totalSupply++;
        return tokenId;
    }

    function updateTokenURI(uint256 tokenId, string memory newURI) public onlyOwner {
        _setTokenURI(tokenId, newURI);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // Following functions are overrides required by Solidity

    function _update(address to, uint256 tokenId, address auth) internal override (
        
        ERC721Upgradeable, 
        ERC721EnumerableUpgradeable, 
        ERC721PausableUpgradeable
    
    ) returns (address) {

        address from = _ownerOf(tokenId);

        if (from == address(0) || to == address(0)) {

            if (to == address(0)) {

                classDetailsContract.nftProperties_1 memory _properties_1 =
                IClassDetails(classContract).getNFTData_1(tokenId);

                IClassDetails(classContract).decrementClassTotalSupply(_properties_1.classId);
            }

        } else {

            if (ownerOf(tokenId) == marketplaceContract || to == marketplaceContract) {} else {
                require(nftTransfers, ""); // NFTs are Soulbound
            }
        }
        return super._update(to, tokenId, auth);
    }

    function internalBurn(uint256 _tokenId) internal {
        _burn(_tokenId);
    }

    function setClassContract(address _class) public onlyOwner {
        require(_class != address(0), "");
        classContract = _class;
    }

    function setMissionContract(address _mission) public onlyOwner {
        require(_mission != address(0), "");
        missionContract = _mission;
    }

    function setNFTTransfers(bool _status) public onlyOwner {
        nftTransfers = _status;
    }

    function setLifeCost(uint256 _lifeCost) public onlyOwner {
        LifeCost = _lifeCost;
    }

    function setMarketplaceContract(address _market) public onlyOwner {
        marketplaceContract = _market;
    }

    function setAddresses(address _vaultAddress, address _feeWallet, address _rewardFeeWallet) public onlyOwner {
        vaultAddress = _vaultAddress;
        feeWallet = _feeWallet;
        rewardFeeWallet = _rewardFeeWallet;
    }

    function setFees(uint256 _mintFee, uint256 _rewardFee) public onlyOwner {
        mintFee = _mintFee;
        rewardFee = _rewardFee;
    }

    function setCurrency(address _mintCurrency) public onlyOwner {
        mintCurrency = IERC20Extended(_mintCurrency);
    }

    function ownerBurn(uint256 _tokenId) public onlyOwner {
        _burn(_tokenId);
    }

    function tokenURI(uint256 tokenId) public view override (ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _increaseBalance(address account, uint128 value) internal override (ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId) public view override (ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /* VRF Functions START */

        function changeSubsriberID(uint256 _id) public onlyOwner {
            s_subscriptionId = _id;
        }

        function changeRequestConfirmations(uint16 _requestConfirmations) public onlyOwner {
            requestConfirmations = _requestConfirmations;
        }

        function changeKeyHash(bytes32 _keyhash) public onlyOwner {
            keyHash = _keyhash;
        }

        function setCoordinator(address _address) public onlyOwner {
            require(_address != address(0));
            COORDINATOR = IVRFCoordinatorV2Plus(_address);
        }

        function setGasLimit(uint32 gas) public onlyOwner {
            callbackGasLimit = gas;
        }

        function getRandomNumber(uint32 numWords, uint256 _tokenId, uint256 vrfType) internal whenNotPaused returns (uint256 requestId) {
            return requestRandomWords(numWords, _tokenId, vrfType);
        }

        function requestRandomWords(uint32 numWords, uint256 _tokenId, uint256 vrfType) internal returns (uint256 requestId) {

            requestId = COORDINATOR.requestRandomWords(VRFV2PlusClient.RandomWordsRequest({

                    keyHash: keyHash,
                    subId: s_subscriptionId,
                    requestConfirmations: requestConfirmations,
                    callbackGasLimit: callbackGasLimit,
                    numWords: numWords,
                    
                    extraArgs:
                        VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: vrfNative
                    }))
                })
            );

            s_requests[requestId] = RequestStatus({

                randomWords: new uint256[](0),
                exists: true,
                fulfilled: false,
                tokenId: _tokenId,
                vrfType: vrfType
            });

            requestIds.push(requestId);
            lastRequestId = requestId;

            return requestId;
        }

        function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
            if (msg.sender != address(COORDINATOR)) {
                revert("Only Coordinator");
            }
            fulfillRandomWords(requestId, randomWords);
            // _completeMission(s_requests[requestId].tokenId);
        }

        function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal {
            require(s_requests[_requestId].exists, "");
            s_requests[_requestId].fulfilled = true;
            s_requests[_requestId].randomWords = _randomWords;
            // emit RequestFulfilled(_requestId, _randomWords);
        }

    /* VRF Functions END */
}