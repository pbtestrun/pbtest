// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

interface INFTContract {
    error AddressEmptyCode(address target);
    error ERC1967InvalidImplementation(address implementation);
    error ERC1967NonPayable();
    error ERC721EnumerableForbiddenBatchMint();
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);
    error ERC721InsufficientApproval(address operator, uint256 tokenId);
    error ERC721InvalidApprover(address approver);
    error ERC721InvalidOperator(address operator);
    error ERC721InvalidOwner(address owner);
    error ERC721InvalidReceiver(address receiver);
    error ERC721InvalidSender(address sender);
    error ERC721NonexistentToken(uint256 tokenId);
    error ERC721OutOfBoundsIndex(address owner, uint256 index);
    error EnforcedPause();
    error ExpectedPause();
    error FailedCall();
    error InvalidInitialization();
    error NotInitializing();
    error OwnableInvalidOwner(address owner);
    error OwnableUnauthorizedAccount(address account);
    error UUPSUnauthorizedCallContext();
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
    event Initialized(uint64 version);
    event MetadataUpdate(uint256 _tokenId);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event Paused(address account);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event RequestSent(uint256 requestId, uint32 numWords);
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
    event Unpaused(address account);
    event Upgraded(address indexed implementation);
    event endSeasonEvent(
        uint256 _rewards,
        uint256 _fee,
        uint256 _totalAddresses
    );

    event claimEvent(address indexed _user, uint256 _amount);
    event assignPointsEvent(address indexed user, uint256 points, uint256 seasonId);
    event updateLifeEvent(address indexed _buyer, uint256 _tokenId, uint256 _lifeCount, uint256 _spent);
    event ContractInitialized(address owner);

    function BASIS_POINTS() external view returns (uint256);
    function COORDINATOR() external view returns (address);
    function LifeCost() external view returns (uint256);
    function UPGRADE_INTERFACE_VERSION() external view returns (string memory);

    function allSeasons(uint256)
        external
        view
        returns (
            uint256 seasonId,
            uint256 endDate,
            uint256 totalRewards,
            uint256 totalPoints,
            uint256 totalAddresses
        );

    function approve(address to, uint256 tokenId) external;

    function assignPoints(address _user, uint256 _points) external;

    function balanceOf(address owner) external view returns (uint256);

    function burn(uint256 tokenId) external;

    function callbackGasLimit() external view returns (uint32);

    function changeKeyHash(bytes32 _keyhash) external;

    function changeRequestConfirmations(uint16 _requestConfirmations) external;

    function changeSubsriberID(uint256 _id) external;

    function claimReward(uint256 _amount) external;

    function claimableRewards(address) external view returns (uint256);

    function classContract() external view returns (address);

    function completeMission(uint256 _tokenId) external;

    function currentSeason() external view returns (uint256);

    function endSeason(uint256 _totalRewards) external;

    function energyCost() external view returns (uint256);

    function energyRegenAmount() external view returns (uint256);

    function energyRegenInterval() external view returns (uint256);

    function initialize() external;

    function getApproved(uint256 tokenId) external view returns (address);

    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);

    function getAge(uint256 _mintTimestamp)
        external
        view
        returns (uint256 _age);

    function getMissionVRF(uint256 _tokenId) external payable;

    function getMintedTokenIds() external view returns (uint256[] memory tokenIds);
    
    function getTokensByOwner(address wallet) external view returns (uint256 count, uint256[] memory tokenIds);

    function keyHash() external view returns (bytes32);

    function lastRequestId() external view returns (uint256);

    function loyaltyPoint() external view returns (uint256);

    function marketplaceContract() external view returns (address);

    function mintCurrency() external view returns (address);

    function mintFee() external view returns (uint256);

    function feeWallet() external view returns (address);

    function mintNFT(uint256 _classId) external;

    function missionContract() external view returns (address);

    function name() external view returns (string memory);

    function nextTokenId() external view returns (uint256);

    function nftTransfers() external view returns (bool);

    function owner() external view returns (address);

    function ownerBurn(uint256 _tokenId) external;

    function ownerOf(uint256 tokenId) external view returns (address);

    function pause() external;

    function paused() external view returns (bool);

    function proxiableUUID() external view returns (bytes32);

    function rawFulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) external;

    function renounceOwnership() external;

    function requestConfirmations() external view returns (uint16);

    function requestIds(uint256) external view returns (uint256);

    function rewardFee() external view returns (uint256);

    function rewardFeeWallet() external view returns (address);

    function s_requests(uint256)
        external
        view
        returns (
            bool fulfilled,
            bool exists,
            uint256 tokenId,
            uint256 vrfType
        );

    function s_subscriptionId() external view returns (uint256);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) external;

    function seasonAddresses(uint256) external view returns (address);

    function seasonTotalPoints(uint256) external view returns (uint256);

    function setAddresses(
        address _vaultAddress,
        address _mintFeeWallet,
        address _rewardFeeWallet
    ) external;

    function setApprovalForAll(address operator, bool approved) external;

    function setClassContract(address _class) external;

    function setCoordinator(address _address) external;

    function setCurrency(address _mintCurrency) external;

    function setEnergyCost(uint256 _cost) external;

    function setEnergyRegenParam(
        uint256 _energyRegenInterval,
        uint256 _energyRegenAmount
    ) external;

    function setFees(uint256 _mintFee, uint256 _rewardFee) external;

    function setGasLimit(uint32 gas) external;

    function setLifeCost(uint256 _lifeCost) external;

    function setLoyaltyPoint(uint256 _loyaltyPoint) external;

    function setMarketPlaceContract(address _market) external;

    function setMissionContract(address _mission) external;

    function setNFTTransfers(bool _status) external;

    function setVRFCost(uint256 _vrfCost) external;

    function setVRFNative(bool _status) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function symbol() external view returns (string memory);

    function tokenByIndex(uint256 index) external view returns (uint256);

    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        view
        returns (uint256);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function totalSeasonCount() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferOwnership(address newOwner) external;

    function unpause() external;

    function updateTokenURI(uint256 tokenId, string memory newURI) external;

    function upgradeToAndCall(address newImplementation, bytes memory data)
        external
        payable;

    function userPoints(address) external view returns (uint256);

    function vaultAddress() external view returns (address);

    function vrfCost() external view returns (uint256);

    function vrfNative() external view returns (bool);

    function withdrawFundsERC20(address erc20, uint256 amount) external;

    function withdrawFundsNative(uint256 amount) external;

    receive() external payable;
}
