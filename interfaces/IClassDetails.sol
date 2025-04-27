// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

interface IClassDetails {
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
    event addNFTEvent(
        uint256 _tokenId,
        classDetailsContract.nftProperties_1 _properties_1,
        classDetailsContract.nftProperties_2 _properties_2
    );
    event decrementClassTotalSupplyEvent(uint256 _classId, uint256 _newSupply);
    event updateClassEvent(
        bool _new,
        classDetailsContract.classDetails_1 _details_1,
        classDetailsContract.classDetails_2 _details_2
    );
    event updateEnergyEvent(
        uint256 _tokenId,
        uint256 _oldEnergy,
        uint256 _newEnergy
    );
    event updateLifeEvent(uint256 _tokenId, uint256 _oldLife, uint256 _newLife);
    event updateNFTDataEvent(
        uint256 _tokenId,
        classDetailsContract.nftProperties_1 _oldProperties_1,
        classDetailsContract.nftProperties_2 _oldProperties_2,
        classDetailsContract.nftProperties_1 _newProperties_1,
        classDetailsContract.nftProperties_2 _newProperties_2
    );

    function NFTContract() external view returns (address);

    function UPGRADE_INTERFACE_VERSION() external view returns (string memory);

    function addClass(
        classDetailsContract.classDetails_1 memory _details_1,
        classDetailsContract.classDetails_2 memory _details_2
    ) external;

    function addNFTData(uint256 _tokenId, uint256 _classId) external;

    function backendWallet() external view returns (address);

    function buyEnergy(uint256 _tokenId) external;

    function buyLives(uint256 _tokenId, uint256 _lifeCount) external;

    function classCount() external view returns (uint256);

    function classTotalSupply(uint256) external view returns (uint256);

    function classes_1(uint256)
        external
        view
        returns (
            uint256 classId,
            uint256 maxHardCap,
            uint256 mintPrice,
            uint256 maxLives,
            uint256 speed,
            uint256 attack,
            uint256 evasion,
            uint256 defense
        );

    function classes_2(uint256)
        external
        view
        returns (
            uint256 energy,
            uint256 maxEnergy,
            bool enabled,
            string memory tokenUri,
            uint256 extra_1,
            uint256 extra_2,
            uint256 extra_3
        );

    function decrementClassTotalSupply(uint256 _classId) external;

    function getClassData_1(uint256 _classId)
        external
        view
        returns (classDetailsContract.classDetails_1 memory classResult);

    function getClassData_2(uint256 classId)
        external
        view
        returns (classDetailsContract.classDetails_2 memory classResult);

    function getEnergy(uint256 _tokenId)
        external
        view
        returns (uint256 usableEnergy);

    function getNFTData_1(uint256 tokenId)
        external
        view
        returns (classDetailsContract.nftProperties_1 memory nftResult);

    function getNFTData_2(uint256 tokenId)
        external
        view
        returns (classDetailsContract.nftProperties_2 memory nftResult);

    function initialize() external;

    function missionContract() external view returns (address);

    function nftData_1(uint256)
        external
        view
        returns (
            uint256 classId,
            uint256 speed,
            uint256 attack,
            uint256 evasion,
            uint256 defense,
            uint256 tokenId,
            uint256 status
        );

    function nftData_2(uint256)
        external
        view
        returns (
            uint256 maxLives,
            uint256 availableLives,
            uint256 energy,
            uint256 energyTimestamp,
            uint256 mintingTimestamp,
            uint256 extra_1,
            uint256 extra_2,
            uint256 extra_3,
            uint256 maxEnergy
        );

    function owner() external view returns (address);

    function pause() external;

    function paused() external view returns (bool);

    function processEnergyGain(
        classDetailsContract.nftProperties_1 memory _properties_1,
        classDetailsContract.nftProperties_2 memory _properties_2
    )
        external
        returns (
            classDetailsContract.nftProperties_1 memory,
            classDetailsContract.nftProperties_2 memory
        );

    function proxiableUUID() external view returns (bytes32);

    function renounceOwnership() external;

    function setBackendWallet(address _backend) external;

    function setMissionContract(address _contract) external;

    function setNFTContract(address _contract) external;

    function transferOwnership(address newOwner) external;

    function unpause() external;

    function updateNFTData(
        uint256 _tokenId,
        classDetailsContract.nftProperties_1 memory _properties_1,
        classDetailsContract.nftProperties_2 memory _properties_2
    ) external;

    function upgradeToAndCall(address newImplementation, bytes memory data)
        external
        payable;
}

interface classDetailsContract {
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

    struct classDetails_1 {
        uint256 classId;
        uint256 maxHardCap;
        uint256 mintPrice;
        uint256 maxLives;
        uint256 speed;
        uint256 attack;
        uint256 evasion;
        uint256 defense;
    }

    struct classDetails_2 {
        uint256 energy;
        uint256 maxEnergy;
        bool enabled;
        string tokenUri;
        uint256 extra_1;
        uint256 extra_2;
        uint256 extra_3;
    }
}
