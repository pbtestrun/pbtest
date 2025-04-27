// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Initializable} from "@openzeppelin/contracts-upgradeable@5.0.0/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/utils/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts@5.0.0/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/INFTContract.sol";

abstract contract IERC20Extended is IERC20 {
    function decimals() public view virtual returns (uint8);
}

contract classDetailsContract is Initializable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {

    using SafeERC20 for IERC20Extended;

    address public NFTContract;
    address public missionContract;

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

    mapping(uint256 => classDetails_1) public classes_1;
    mapping(uint256 => classDetails_2) public classes_2;
    uint256 public classCount;

    mapping(uint256 => uint256) public classTotalSupply;

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

    mapping(uint256 => nftProperties_1) public nftData_1;
    mapping(uint256 => nftProperties_2) public nftData_2;
    address public backendWallet;

    event addNFTEvent(uint256 _tokenId, nftProperties_1 _properties_1, nftProperties_2 _properties_2);
    event updateLifeEvent(uint256 _tokenId, uint256 _oldLife, uint256 _newLife);
    event updateEnergyEvent(uint256 _tokenId, uint256 _oldEnergy, uint256 _newEnergy);

    event updateNFTDataEvent(
        uint256 _tokenId,
        nftProperties_1 _oldProperties_1,
        nftProperties_2 _oldProperties_2,
        nftProperties_1 _newProperties_1,
        nftProperties_2 _newProperties_2
    );

    event decrementClassTotalSupplyEvent(uint256 _classId, uint256 _newSupply);
    event updateClassEvent(bool _new, classDetails_1 _details_1, classDetails_2 _details_2);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize() public initializer {
        __Pausable_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

    function getEnergy(uint256 _tokenId) public view returns (uint256 usableEnergy) {

        nftProperties_1 memory _properties_1 = nftData_1[_tokenId];
        nftProperties_2 memory _properties_2 = nftData_2[_tokenId];

        usableEnergy = _properties_2.energy;

        if (_properties_2.energy < _properties_2.maxEnergy) {

            if (_properties_1.status == 1) {
                uint256 _elapsed = block.timestamp - _properties_2.energyTimestamp;
                uint256 regenInterval = INFTContract(payable(NFTContract)).energyRegenInterval();

                if (regenInterval == 0) { revert("Energy regeneration interval cannot be zero"); }
                if (_elapsed < regenInterval) {} else {

                    uint256 _count = _elapsed / regenInterval;
                    _properties_2.energy += (_count * INFTContract(payable(NFTContract)).energyRegenAmount());
                    _properties_2.energyTimestamp += (_count * regenInterval);
                    
                    usableEnergy = _properties_2.energy;

                    if (usableEnergy > _properties_2.maxEnergy) {
                        usableEnergy = _properties_2.maxEnergy;
                    }
                }
            }
        }
        return usableEnergy;
    }

    function updateEnergy(uint256 _tokenId) public nonReentrant {

        require(msg.sender == INFTContract(payable(NFTContract)).ownerOf(_tokenId), "Caller not token owner");

        nftProperties_1 memory _properties_1 = nftData_1[_tokenId];
        nftProperties_2 memory _properties_2 = nftData_2[_tokenId];

        if (_properties_2.energy == _properties_2.maxEnergy) {
            _properties_2.energyTimestamp = block.timestamp;

            nftProperties_1 memory _oldProperties_1 = nftData_1[_properties_1.tokenId];
            nftProperties_2 memory _oldProperties_2 = nftData_2[_properties_1.tokenId];

            nftData_1[_properties_1.tokenId] = _properties_1;
            nftData_2[_properties_1.tokenId] = _properties_2;

            emit updateNFTDataEvent(
                _properties_1.tokenId,
                _oldProperties_1,
                _oldProperties_2,
                _properties_1,
                _properties_2
            );
        }

        if (_properties_2.energy < _properties_2.maxEnergy) {

            if (_properties_1.status == 1) {
                uint256 _elapsed = block.timestamp - _properties_2.energyTimestamp;
                uint256 regenInterval = INFTContract(payable(NFTContract)).energyRegenInterval();

                if (regenInterval == 0) { revert("Energy regeneration interval cannot be zero"); }
                if (_elapsed < regenInterval) {} else {

                    uint256 _count = _elapsed / regenInterval;
                    _properties_2.energy += (_count * INFTContract(payable(NFTContract)).energyRegenAmount());
                    _properties_2.energyTimestamp += (_count * regenInterval);

                    if (_properties_2.energy > _properties_2.maxEnergy) {
                        _properties_2.energy = _properties_2.maxEnergy;
                    }

                    nftProperties_1 memory _oldProperties_1 = nftData_1[_properties_1.tokenId];
                    nftProperties_2 memory _oldProperties_2 = nftData_2[_properties_1.tokenId];

                    nftData_1[_properties_1.tokenId] = _properties_1;
                    nftData_2[_properties_1.tokenId] = _properties_2;

                    emit updateNFTDataEvent(
                        _properties_1.tokenId,
                        _oldProperties_1,
                        _oldProperties_2,
                        _properties_1,
                        _properties_2
                    );
                }

            } else {

                _properties_2.energyTimestamp = block.timestamp;

                nftProperties_1 memory _oldProperties_1 = nftData_1[_properties_1.tokenId];
                nftProperties_2 memory _oldProperties_2 = nftData_2[_properties_1.tokenId];

                nftData_1[_properties_1.tokenId] = _properties_1;
                nftData_2[_properties_1.tokenId] = _properties_2;
                
                emit updateNFTDataEvent(
                    _properties_1.tokenId,
                    _oldProperties_1,
                    _oldProperties_2,
                    _properties_1,
                    _properties_2
                );
            }

        } else {}
    }

    function processEnergyGain(nftProperties_1 memory _properties_1, nftProperties_2 memory _properties_2) public nonReentrant
    returns (classDetailsContract.nftProperties_1 memory, classDetailsContract.nftProperties_2 memory) {

        require(msg.sender == missionContract || msg.sender == NFTContract, "Not authorized");

        if (_properties_2.energy == _properties_2.maxEnergy) {
            _properties_2.energyTimestamp = block.timestamp;

            nftProperties_1 memory _oldProperties_1 = nftData_1[_properties_1.tokenId];
            nftProperties_2 memory _oldProperties_2 = nftData_2[_properties_1.tokenId];

            nftData_1[_properties_1.tokenId] = _properties_1;
            nftData_2[_properties_1.tokenId] = _properties_2;

            emit updateNFTDataEvent(
                _properties_1.tokenId,
                _oldProperties_1,
                _oldProperties_2,
                _properties_1,
                _properties_2
            );

            return (_properties_1, _properties_2);
        }

        if (_properties_2.energy < _properties_2.maxEnergy) {

            if (_properties_1.status == 1) {
                uint256 _elapsed = block.timestamp - _properties_2.energyTimestamp;
                uint256 regenInterval = INFTContract(payable(NFTContract)).energyRegenInterval();

                if (regenInterval == 0) { revert("Energy regeneration interval cannot be zero"); }                
                if (_elapsed < regenInterval) {
                    return (_properties_1, _properties_2);

                } else {
                    uint256 _count = _elapsed / regenInterval;
                    _properties_2.energy += (_count * INFTContract(payable(NFTContract)).energyRegenAmount());
                    _properties_2.energyTimestamp += (_count * regenInterval);

                    if (_properties_2.energy > _properties_2.maxEnergy) {
                        _properties_2.energy = _properties_2.maxEnergy;
                    }

                    nftProperties_1 memory _oldProperties_1 = nftData_1[_properties_1.tokenId];
                    nftProperties_2 memory _oldProperties_2 = nftData_2[_properties_1.tokenId];

                    nftData_1[_properties_1.tokenId] = _properties_1;
                    nftData_2[_properties_1.tokenId] = _properties_2;

                    emit updateNFTDataEvent(
                        _properties_1.tokenId,
                        _oldProperties_1,
                        _oldProperties_2,
                        _properties_1,
                        _properties_2
                    );

                    return (_properties_1, _properties_2);
                }

            } else {

                _properties_2.energyTimestamp = block.timestamp;

                nftProperties_1 memory _oldProperties_1 = nftData_1[_properties_1.tokenId];
                nftProperties_2 memory _oldProperties_2 = nftData_2[_properties_1.tokenId];

                nftData_1[_properties_1.tokenId] = _properties_1;
                nftData_2[_properties_1.tokenId] = _properties_2;

                emit updateNFTDataEvent(
                    _properties_1.tokenId,
                    _oldProperties_1,
                    _oldProperties_2,
                    _properties_1,
                    _properties_2
                );

                return (_properties_1, _properties_2);
            }
            
        } else { return (_properties_1, _properties_2); }
    }

    function getNFTData_1(uint256 tokenId) public view returns (nftProperties_1 memory nftResult) {

        nftProperties_1 memory nft = nftData_1[tokenId];
        nftResult.classId = nft.classId;
        nftResult.speed = nft.speed;
        nftResult.attack = nft.attack;
        nftResult.evasion = nft.evasion;
        nftResult.defense = nft.defense;
        nftResult.tokenId = nft.tokenId;
        nftResult.status = nft.status;
    }

    function getNFTData_2(uint256 tokenId) public view returns (nftProperties_2 memory nftResult) {

        nftProperties_2 memory nft = nftData_2[tokenId];
        nftResult.maxLives = nft.maxLives;
        nftResult.availableLives = nft.availableLives;
        nftResult.energy = nft.energy;
        nftResult.energyTimestamp = nft.energyTimestamp;
        nftResult.mintingTimestamp = nft.mintingTimestamp;
        nftResult.extra_1 = nft.extra_1;
        nftResult.extra_2 = nft.extra_2;
        nftResult.extra_3 = nft.extra_3;
        nftResult.maxEnergy = nft.maxEnergy;
    }

    function getClassData_1(uint256 _classId) public view returns (classDetails_1 memory classResult) {

        classDetails_1 memory class = classes_1[_classId];
        classResult.classId = class.classId;
        classResult.maxHardCap = class.maxHardCap;
        classResult.mintPrice = class.mintPrice;
        classResult.maxLives = class.maxLives;
        classResult.speed = class.speed;
        classResult.attack = class.attack;
        classResult.evasion = class.evasion;
        classResult.defense = class.defense;
    }

    function getClassData_2(uint256 classId) public view returns (classDetails_2 memory classResult) {

        classDetails_2 memory class = classes_2[classId];
        classResult.energy = class.energy;
        classResult.maxEnergy = class.maxEnergy;
        classResult.enabled = class.enabled;
        classResult.tokenUri = class.tokenUri;
        classResult.extra_1 = class.extra_1;
        classResult.extra_2 = class.extra_2;
        classResult.extra_3 = class.extra_3;
    }

    function setNFTContract(address _contract) public onlyOwner {
        require(_contract != address(0), "Cannot be null");
        NFTContract = _contract;
    }

    function setMissionContract(address _contract) public onlyOwner {
        require(_contract != address(0), "Cannot be null");
        missionContract = _contract;
    }

    function addNFTData(uint256 _tokenId, uint256 _classId) public {

        require(msg.sender == NFTContract, "Not Authorized");

        nftProperties_1 memory _properties_1 = nftProperties_1({
            classId: classes_1[_classId].classId,
            speed: classes_1[_classId].speed,
            attack: classes_1[_classId].attack,
            evasion: classes_1[_classId].evasion,
            defense: classes_1[_classId].defense,
            tokenId: _tokenId,
            status: 1
        });

        nftProperties_2 memory _properties_2 = nftProperties_2({
            maxLives: classes_1[_classId].maxLives,
            availableLives: classes_1[_classId].maxLives,
            energy: classes_2[_classId].energy,
            maxEnergy: classes_2[_classId].maxEnergy,
            energyTimestamp: block.timestamp,
            mintingTimestamp: block.timestamp,
            extra_1: 0,
            extra_2: 0,
            extra_3: 0
        });

        nftData_1[_tokenId] = _properties_1;
        nftData_2[_tokenId] = _properties_2;

        classTotalSupply[_properties_1.classId]++;
        emit addNFTEvent(_tokenId, _properties_1, _properties_2);
    }

    function buyLives(uint256 _tokenId, uint256 _lifeCount) public whenNotPaused nonReentrant {

        require(msg.sender == INFTContract(payable(NFTContract)).ownerOf(_tokenId), "Caller is not the token owner");
        require(nftData_2[_tokenId].maxLives > 0, "Cannot buy lives for this class");
        require(nftData_1[_tokenId].status == 1, "Ongoing mission, cannot buy");

        require(_lifeCount > 0 && nftData_2[_tokenId].availableLives + _lifeCount <= nftData_2[_tokenId].maxLives, "Cannot buy more");
        require(INFTContract(payable(NFTContract)).feeWallet() != address(0), "Mint fee wallet address not set");

        uint256 amount;
        amount = _lifeCount * INFTContract(payable(NFTContract)).LifeCost();

        require(
            IERC20Extended(INFTContract(payable(NFTContract)).mintCurrency()).transferFrom
            (msg.sender, INFTContract(payable(NFTContract)).feeWallet(), amount), "Problem transfering funds");

        uint256 _oldLife = nftData_2[_tokenId].availableLives;
        nftData_2[_tokenId].availableLives += _lifeCount;

        emit updateLifeEvent(_tokenId, _oldLife, nftData_2[_tokenId].availableLives);
    }

    function buyEnergy(uint256 _tokenId) public whenNotPaused nonReentrant {

        require(msg.sender == INFTContract(payable(NFTContract)).ownerOf(_tokenId), "Caller is not the token owner");
        require(nftData_1[_tokenId].status == 1, "Ongoing mission, cannot buy");


        // classDetailsContract.nftProperties memory _properties = IClassDetails(classContract).nftData(_tokenId);
        // classDetailsContract.classDetails memory _class = IClassDetails(classContract).classes(_properties.classId);

        require(nftData_2[_tokenId].energy != nftData_2[_tokenId].maxEnergy, "Cannot buy any more energy");
        require(INFTContract(payable(NFTContract)).feeWallet() != address(0), "Mint fee wallet address not set");

        require(IERC20Extended(INFTContract(payable(NFTContract)).mintCurrency()).transferFrom(msg.sender,INFTContract
        (payable(NFTContract)).feeWallet(), INFTContract(payable(NFTContract)).energyCost()), "Problem transfering funds");

        uint256 _oldEnergy = nftData_2[_tokenId].energy;
        nftData_2[_tokenId].energy = nftData_2[_tokenId].maxEnergy;
        nftData_2[_tokenId].energyTimestamp = block.timestamp;

        emit updateEnergyEvent(_tokenId, _oldEnergy, nftData_2[_tokenId].maxEnergy);
    }


    // function updateLife(uint256 _tokenId, uint256 _newLife) public {
    //     require(msg.sender == NFTContract, "Not authorized");
    //     uint256 _oldLife = nftData[_tokenId].availableLives;
    //     nftData[_tokenId].availableLives = _newLife;
    //     emit updateLifeEvent(_tokenId, _oldLife, _newLife);
    // }


    // function updateEnergy(uint256 _tokenId, uint256 _newEnergy) public {
    //     require(msg.sender == NFTContract, "Not authorized");
    //     uint256 _oldEnergy = nftData[_tokenId].energy;
    //     nftData[_tokenId].energy = _newEnergy;
    //     emit updateEnergyEvent(_tokenId, _oldEnergy, _newEnergy);
    // }

    function updateNFTData(uint256 _tokenId, nftProperties_1 memory _properties_1, nftProperties_2 memory _properties_2) public {

        require(msg.sender == NFTContract || msg.sender == backendWallet || msg.sender == missionContract, "Not authorized");

        nftProperties_1 memory _oldProperties_1 = nftData_1[_tokenId];
        nftProperties_2 memory _oldProperties_2 = nftData_2[_tokenId];
        
        require(_tokenId == _properties_1.tokenId, "Mismatch tokenId");

        nftData_1[_tokenId] = _properties_1;
        nftData_2[_tokenId] = _properties_2;
        
        emit updateNFTDataEvent(_tokenId, _oldProperties_1, _oldProperties_2, _properties_1, _properties_2);
    }

    function decrementClassTotalSupply(uint256 _classId) public {
        require(msg.sender == NFTContract, "Not authorized");
        classTotalSupply[_classId]--;
        emit decrementClassTotalSupplyEvent(_classId, classTotalSupply[_classId]);
    }

    function setBackendWallet(address _backend) public onlyOwner {
        backendWallet = _backend;
    }

    function addClass(classDetails_1 memory _details_1, classDetails_2 memory _details_2) public onlyOwner {

        if (_details_1.classId < classCount) {

            classes_1[_details_1.classId].mintPrice = _details_1.mintPrice;
            classes_1[_details_1.classId].maxLives = _details_1.maxLives;
            classes_1[_details_1.classId].speed = _details_1.speed;
            classes_1[_details_1.classId].attack = _details_1.attack;
            classes_1[_details_1.classId].evasion = _details_1.evasion;
            classes_1[_details_1.classId].defense = _details_1.defense;
            classes_2[_details_1.classId].energy = _details_2.energy;
            classes_2[_details_1.classId].maxEnergy = _details_2.maxEnergy;
            classes_2[_details_1.classId].enabled = _details_2.enabled;
            classes_2[_details_1.classId].tokenUri = _details_2.tokenUri;
            classes_1[_details_1.classId].maxHardCap = _details_1.maxHardCap;

            classes_2[_details_1.classId].extra_1 = _details_2.extra_1;
            classes_2[_details_1.classId].extra_2 = _details_2.extra_2;
            classes_2[_details_1.classId].extra_3 = _details_2.extra_3;

            emit updateClassEvent(false, _details_1, _details_2);

        } else {

            classDetails_1 memory _class_1 = classDetails_1({
                classId: classCount,
                maxHardCap: _details_1.maxHardCap,
                mintPrice: _details_1.mintPrice,
                maxLives: _details_1.maxLives,
                speed: _details_1.speed,
                attack: _details_1.attack,
                evasion: _details_1.evasion,
                defense: _details_1.defense
            });

            classDetails_2 memory _class_2 = classDetails_2({
                energy: _details_2.energy,
                maxEnergy: _details_2.maxEnergy,
                enabled: _details_2.enabled,
                tokenUri: _details_2.tokenUri,
                extra_1: _details_2.extra_1,
                extra_2: _details_2.extra_2,
                extra_3: _details_2.extra_3
            });

            classes_1[classCount++] = _class_1;
            classes_2[classCount - 1] = _class_2;

            emit updateClassEvent(true, _class_1, _class_2);
        }
    }

    function pause() public onlyOwner { _pause(); }
    function unpause() public onlyOwner { _unpause(); }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}