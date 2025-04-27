// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

interface IMissionDetails {
    error AddressEmptyCode(address target);
    error ERC1967InvalidImplementation(address implementation);
    error ERC1967NonPayable();
    error EnforcedPause();
    error ExpectedPause();
    error FailedCall();
    error InvalidInitialization();
    error NotInitializing();
    error OwnableInvalidOwner(address owner);
    error OwnableUnauthorizedAccount(address account);
    error UUPSUnauthorizedCallContext();
    error UUPSUnsupportedProxiableUUID(bytes32 slot);
    event Initialized(uint64 version);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event Paused(address account);
    event Unpaused(address account);
    event Upgraded(address indexed implementation);
    event addTokenMissionEvent(
        uint256 _tokenId,
        missionDetailsContract.missionParameters _tokenMission
    );
    event updateMissionEvent(
        bool _new,
        missionDetailsContract.missionDetails _mission
    );
    event updateTokenMissionEvent(
        uint256 _tokenId,
        uint256 _index,
        missionDetailsContract.missionParameters _oldTokenMission,
        missionDetailsContract.missionParameters _newTokenMission
    );
    event startMissionEvent(
        address _user, 
        uint256 _tokenId, 
        uint256 _missionId, 
        missionDetailsContract.missionParameters _mission
    );

    function NFTContract() external view returns (address);
    function UPGRADE_INTERFACE_VERSION() external view returns (string memory);

    function addMission(
        uint256 _id,
        uint256 riskLevel,
        uint256 energy,
        uint256 minTimeNeed,
        uint256 deathRate,
        uint256 successRate,
        uint256 pointsPerMinute,
        bool enabled,
        uint256[] memory eligibleClasses
    ) external;

    function addTokenMission(
        uint256 _tokenId,
        missionDetailsContract.missionParameters memory _mission
    ) external;

    function classContract() external view returns (address);

    function getMission(uint256 _id)
        external
        view
        returns (
            missionDetailsContract.missionDetails memory,
            uint256[] memory eligibleClasses
        );

    function getTokenMissions(
        uint256 _tokenId,
        uint256 _startIndex,
        uint256 _endIndex
    ) external view returns (missionDetailsContract.missionParameters[] memory);

    function initialize() external;

    function missionCount() external view returns (uint256);

    function missions(uint256)
        external
        view
        returns (missionDetailsContract.missionDetails memory);

    function owner() external view returns (address);

    function pause() external;

    function paused() external view returns (bool);

    function proxiableUUID() external view returns (bytes32);

    function renounceOwnership() external;

    function setClassContract(address _contract) external;

    function setNFTContract(address _contract) external;

    function startMission(uint256 _missionId, uint256 _tokenId) external;

    function batchStartMission(uint256[] calldata _tokenIds, uint256 _missionId) external;

    function tokenMissions(uint256, uint256)
        external
        view
        returns (missionDetailsContract.missionParameters memory);

    function tokenTotalMissions(uint256) external view returns (uint256);

    function transferOwnership(address newOwner) external;

    function unpause() external;

    function updateTokenMission(
        uint256 _tokenId,
        uint256 _index,
        missionDetailsContract.missionParameters memory _mission
    ) external;

    function upgradeToAndCall(address newImplementation, bytes memory data)
        external
        payable;
}

interface missionDetailsContract {
    struct missionDetails {
        uint256 missionId;
        uint256 riskLevel;
        uint256 energy;
        uint256 minTimeNeed;
        uint256 deathRate;
        uint256 successRate;
        uint256 pointsPerMinute;
        uint256[] eligibleClasses;
        bool enabled;
    }

    struct missionParameters {
        uint256 tokenId;
        uint256 missionId;
        missionDetails missionInfo;
        classDetailsContractV2.nftProperties_1 nftInfo_1;
        classDetailsContractV2.nftProperties_2 nftInfo_2;
        uint256 start;
        uint256 end;
        uint256 initiateEnd;
        uint256 status;
        uint256 points;
        uint256 requestId;
        uint256[] fullFillRequestId;
    }
}

interface classDetailsContractV2 {
    struct nftProperties_1 {
        uint256 classId;
        uint256 speed;
        uint256 attack;
        uint256 evasion;
        uint256 defense;
        uint256 tokenId;
        uint256 status;
    }

    struct nftProperties_2 {
        uint256 maxLives;
        uint256 availableLives;
        uint256 energy;
        uint256 energyTimestamp;
        uint256 mintingTimestamp;
        uint256 extra_1;
        uint256 extra_2;
        uint256 extra_3;
        uint256 maxEnergy;
    }
}
