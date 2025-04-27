// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Initializable} from "@openzeppelin/contracts-upgradeable@5.0.0/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/utils/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IClassDetails.sol";
import "./interfaces/INFTContract.sol";

contract missionDetailsContract is Initializable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {

    address public NFTContract;
    address public classContract;

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
        classDetailsContract.nftProperties_1 nftInfo_1;
        classDetailsContract.nftProperties_2 nftInfo_2;

        uint256 start;
        uint256 end;
        uint256 initiateEnd;
        uint256 status;

        //  uint256 result;
        uint256 points;
        uint256 requestId;
        uint256[] fullFillRequestId;
    }

    mapping(uint256 => missionDetails) public missions;
    uint256 public missionCount;

    mapping(uint256 => missionParameters[]) public tokenMissions;
    mapping(uint256 => uint256) public tokenTotalMissions;

    event updateMissionEvent(bool _new, missionDetails _mission);
    event addTokenMissionEvent(uint256 _tokenId, missionParameters _tokenMission);
    event updateTokenMissionEvent(uint256 _tokenId,uint256 _index, missionParameters _oldTokenMission, missionParameters _newTokenMission);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize() public initializer {
        __Pausable_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

    function startMission(uint256 _missionId, uint256 _tokenId) public whenNotPaused nonReentrant {

        require(msg.sender == INFTContract(payable(NFTContract)).ownerOf(_tokenId), "Not the owner");
        (missionDetails memory _missionDetails, uint256[] memory _eligibleClasses) = getMission(_missionId);

        require(_missionDetails.enabled, "Mission Closed");
        bool _eligible;

        classDetailsContract.nftProperties_1 memory _properties_1 = IClassDetails(classContract).getNFTData_1(_tokenId);
        classDetailsContract.nftProperties_2 memory _properties_2 = IClassDetails(classContract).getNFTData_2(_tokenId);

        (_properties_1, _properties_2) = IClassDetails(classContract).processEnergyGain(_properties_1, _properties_2);

        require(_properties_1.status == 1, "Cannot Start Mission");
        require(_properties_2.energy >= _missionDetails.energy, "Not enough energy");

        _properties_2.energy -= _missionDetails.energy;
        _properties_1.status = 2;

        IClassDetails(classContract).updateNFTData(_tokenId, _properties_1, _properties_2);

        for (uint256 i = 0; i < _eligibleClasses.length; i++) {
            if ((_eligibleClasses[i] == _properties_1.classId)) {
                _eligible = true;
            }
        }

        require(_eligibleClasses.length == 0 || _eligible, "NFT class not eligible for this mission");

        classDetailsContract.nftProperties_1
            memory _propertiesV2_1 = classDetailsContract.nftProperties_1({
                classId: _properties_1.classId,
                speed: _properties_1.speed,
                attack: _properties_1.attack,
                evasion: _properties_1.evasion,
                defense: _properties_1.defense,
                tokenId: _properties_1.tokenId,
                status: _properties_1.status
            });

        classDetailsContract.nftProperties_2
            memory _propertiesV2_2 = classDetailsContract.nftProperties_2({
                maxLives: _properties_2.maxLives,
                availableLives: _properties_2.availableLives,
                energy: _properties_2.energy,
                extra_1: _properties_2.extra_1,
                extra_2: _properties_2.extra_2,
                extra_3: _properties_2.extra_3,
                maxEnergy: _properties_2.maxEnergy,
                mintingTimestamp: _properties_2.mintingTimestamp,
                energyTimestamp: _properties_2.energyTimestamp
            });

        missionDetailsContract.missionDetails
            memory _missionDetailsTemp = missionDetailsContract.missionDetails({
                missionId: _missionDetails.missionId,
                riskLevel: _missionDetails.riskLevel,
                energy: _missionDetails.energy,
                minTimeNeed: _missionDetails.minTimeNeed,
                deathRate: _missionDetails.deathRate,
                successRate: _missionDetails.successRate,
                pointsPerMinute: _missionDetails.pointsPerMinute,
                eligibleClasses: _eligibleClasses,
                enabled: _missionDetails.enabled
            });

        missionDetailsContract.missionParameters
            memory _mission = missionDetailsContract.missionParameters({
                tokenId: _tokenId,
                missionId: _missionId,
                missionInfo: _missionDetailsTemp,
                nftInfo_1: _propertiesV2_1,
                nftInfo_2: _propertiesV2_2,
                start: block.timestamp,
                end: 0,
                initiateEnd: 0,
                status: 1,
                // result: 0,
                points: 0,
                requestId: 0,
                fullFillRequestId: new uint256[](0)
            });

        tokenMissions[_tokenId].push(_mission);
        tokenTotalMissions[_tokenId]++;
        emit addTokenMissionEvent(_tokenId, _mission);

        // IMissionDetails(missionContract).addTokenMission(_tokenId, _mission);
        // emit startMissionEvent(msg.sender, _tokenId, _missionId, _mission);
    }

    function getMission(uint256 _id) public view returns (missionDetails memory, uint256[] memory eligibleClasses) {
        missionDetails memory m = missions[_id];
        return (missions[_id], m.eligibleClasses);
    }

    function setNFTContract(address _contract) public onlyOwner {
        require(_contract != address(0), "Cannot be null");
        NFTContract = _contract;
    }

    function setClassContract(address _contract) public onlyOwner {
        require(_contract != address(0), "Cannot be null");
        classContract = _contract;
    }

    function addTokenMission(uint256 _tokenId, missionParameters memory _mission) public {
        require(msg.sender == NFTContract, "Not authorized");
        tokenMissions[_tokenId].push(_mission);
        tokenTotalMissions[_tokenId]++;
        emit addTokenMissionEvent(_tokenId, _mission);
    }

    function updateTokenMission(uint256 _tokenId, uint256 _index, missionParameters memory _mission) public {
        require(msg.sender == NFTContract, "Not authorized");
        require(tokenTotalMissions[_tokenId] > _index, "Cannot find");
        missionParameters memory _oldMission = tokenMissions[_tokenId][_index];
        tokenMissions[_tokenId][_index] = _mission;
        emit updateTokenMissionEvent(_tokenId, _index, _oldMission, _mission);
    }

    function addMission(uint256 _id, uint256 riskLevel, uint256 energy, uint256 minTimeNeed, uint256 deathRate,
    uint256 successRate, uint256 pointsPerMinute, bool enabled, uint256[] memory eligibleClasses) public onlyOwner {

        require(_id > 0, "Mission ID must be greater than zero");
        require(_id <= missionCount + 1, "Mission ID exceeds next available ID");

        if (_id <= missionCount) {

            missions[_id].riskLevel = riskLevel;
            missions[_id].minTimeNeed = minTimeNeed;
            missions[_id].energy = energy;
            missions[_id].deathRate = deathRate;
            missions[_id].successRate = successRate;
            missions[_id].pointsPerMinute = pointsPerMinute;
            missions[_id].enabled = enabled;
            missions[_id].eligibleClasses = eligibleClasses;
            emit updateMissionEvent(false, missions[_id]);

        } else {
            missionDetails memory _mission = missionDetails({
                missionId: missionCount + 1,
                riskLevel: riskLevel,
                energy: energy,
                minTimeNeed: minTimeNeed,
                deathRate: deathRate,
                successRate: successRate,
                pointsPerMinute: pointsPerMinute,
                eligibleClasses: eligibleClasses,
                enabled: enabled
            });
            missions[++missionCount] = _mission;
            emit updateMissionEvent(true, _mission);
        }
    }

    function getTokenMissions(

        uint256 _tokenId,
        uint256 _startIndex,
        uint256 _endIndex

    ) public view returns (missionParameters[] memory) {

        if (_endIndex >= tokenTotalMissions[_tokenId]) {
            _endIndex = tokenTotalMissions[_tokenId] - 1;
        }

        missionParameters[] memory _tmp = new missionParameters[](
            tokenTotalMissions[_tokenId]
        );
        uint256 count = 0;
        for (uint256 i = _startIndex; i <= _endIndex; i++) {
            _tmp[count] = tokenMissions[_tokenId][i];
            count++;
        }

        missionParameters[] memory finalMissions = new missionParameters[](
            count
        );

        for (uint256 j = 0; j < count; j++) {
            finalMissions[j] = _tmp[j];
        }

        return finalMissions;
    }

    function pause() public onlyOwner { _pause(); }
    function unpause() public onlyOwner { _unpause(); }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}