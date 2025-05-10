// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Initializable} from "@openzeppelin/contracts-upgradeable@5.0.0/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable@5.0.0/utils/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts@5.0.0/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts@5.0.0/token/ERC721/IERC721.sol";

import "./interfaces/IClassDetails.sol";
import "./interfaces/IMissionDetails.sol";
import "./interfaces/INFTContract.sol";

abstract contract IERC20Extended is IERC20 {
    function decimals() public view virtual returns (uint8);
}

contract PunkBytesMarketplace is Initializable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {

    using SafeERC20 for IERC20Extended;

    INFTContract public nftContract; // PunkBytesContract NFT Interactions and Points
    IERC20Extended public currency; // PunkBytesContract mintCurrency used for trading

    address public feeRecipient; // Recipient of marketplace fees
    uint256 public feeBps; // Fee in basis points 2500 = 25%
    uint256 public constant BASIS_POINTS = 10000;

    uint256 public buyerPoints;
    uint256 public sellerPoints;

    struct Listing {
        uint256 price;
        address seller;
        uint256 listingId;
        bool active;
        uint256 tokenId;
    }

    struct ListingDetails {
        uint256 tokenId;
        address seller;
        uint256 price;
        bool active;
        uint256 listingId;
    }

    mapping(uint256 => Listing) private listings;
    uint256 private nextListingId;

    event CharacterListed(uint256 indexed listingId, uint256 indexed tokenId, address indexed seller, uint256 price);
    event ListingUpdated(uint256 indexed listingId, uint256 indexed tokenId, uint256 newPrice);
    event ListingCancelled(uint256 indexed listingId, uint256 indexed tokenId);
    event CharacterBought(uint256 indexed listingId, uint256 indexed tokenId, address indexed buyer, uint256 price);
    event AllListingsCancelled(uint256 count);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        currency = IERC20Extended(0xf0877917AE5E44772BB9977508eD368a5332D111); // mockUSDC addr
        // currency = IERC20Extended(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E); // USDC for prod
        feeRecipient = 0xb81F514b1488d971647e1164554e9A504c0A2729;

        feeBps = 2500;
        buyerPoints = 5000;
        sellerPoints = 500;
        nextListingId = 1;
    }

    function listCharacter(uint256 _tokenId, uint256 _price) external whenNotPaused nonReentrant {
        require(address(nftContract) != address(0), "NFT contract not set");
        require(_price > 0, "Price must be greater than zero");
        require(_price <= type(uint256).max / feeBps, "Price too high");
        require(nftContract.ownerOf(_tokenId) == msg.sender, "Not token owner");
        require(nftContract.getApproved(_tokenId) == address(this) || nftContract.isApprovedForAll(msg.sender, address(this)), "Marketplace not approved");

        // Ensure NFT is not on a mission
        classDetailsContract.nftProperties_1 memory props1 = IClassDetails(nftContract.classContract()).getNFTData_1(_tokenId);
        require(props1.status == 1, "NFT on mission");

        uint256 listingId = nextListingId++;
        listings[listingId] = Listing({
            price: _price,
            seller: msg.sender,
            listingId: listingId,
            active: true,
            tokenId: _tokenId
        });

        emit CharacterListed(listingId, _tokenId, msg.sender, _price);
    }

    function updateListing(uint256 _listingId, uint256 _newPrice) external whenNotPaused nonReentrant {
        Listing memory listing = listings[_listingId];
        require(listing.active, "Listing not active");
        require(listing.seller == msg.sender, "Not listing seller");
        require(_newPrice > 0, "Price must be greater than zero");
        require(_newPrice <= type(uint256).max / feeBps, "Price too high");

        listings[_listingId].price = _newPrice;

        emit ListingUpdated(_listingId, _listingId, _newPrice);
    }

    function cancelListing(uint256 _listingId) external whenNotPaused nonReentrant {
        Listing memory listing = listings[_listingId];
        require(listing.active, "Listing not active");
        require(listing.seller == msg.sender, "Not listing seller");

        listings[_listingId].active = false;

        emit ListingCancelled(_listingId, _listingId);
    }

    function buyCharacter(uint256 _listingId, uint256 _tokenId) external whenNotPaused nonReentrant {
        Listing memory listing = listings[_listingId];
        require(listing.active, "Listing not active");
        require(nftContract.ownerOf(_tokenId) == listing.seller, "Seller no longer owns NFT");
        require(nftContract.getApproved(_tokenId) == address(this) || nftContract.isApprovedForAll(listing.seller, address(this)), "Marketplace not approved");

        // Ensure NFT is not on a mission
        classDetailsContract.nftProperties_1 memory props1 = IClassDetails(nftContract.classContract()).getNFTData_1(_tokenId);
        require(props1.status == 1, "NFT on mission");

        uint256 fee = (listing.price * feeBps) / BASIS_POINTS;
        uint256 sellerAmount = listing.price - fee;

        // Transfer funds
        currency.safeTransferFrom(msg.sender, feeRecipient, fee);
        currency.safeTransferFrom(msg.sender, listing.seller, sellerAmount);

        // Assign points
        nftContract.assignPoints(msg.sender, buyerPoints);
        nftContract.assignPoints(listing.seller, sellerPoints);

        // Transfer NFT
        nftContract.safeTransferFrom(listing.seller, msg.sender, _tokenId);

        listings[_listingId].active = false;

        emit CharacterBought(_listingId, _tokenId, msg.sender, listing.price);
    }

    function getActiveListings() external view returns (ListingDetails[] memory) {
        // uint256 totalSupply = nftContract.totalSupply();
        uint256 activeCount = 0;

        // Count active listings
        for (uint256 i = 1; i < nextListingId; i++) {
            if (listings[i].active) {
                activeCount++;
            }
        }

        ListingDetails[] memory activeListings = new ListingDetails[](activeCount);
        uint256 index = 0;

        // Populate active listings
        for (uint256 i = 1; i < nextListingId && index < activeCount; i++) {
            if (listings[i].active) {
                activeListings[index] = ListingDetails({
                    tokenId: listings[i].tokenId,
                    seller: listings[i].seller,
                    price: listings[i].price,
                    active: listings[i].active,
                    listingId: listings[i].listingId
                });
                index++;
            }
        }

        return activeListings;
    }

    function getWalletListings(address _wallet) external view returns (ListingDetails[] memory) {
        require(_wallet != address(0), "Invalid wallet address");
        // uint256 totalSupply = nftContract.totalSupply();
        uint256 walletCount = 0;

        // Count listings by wallet
        for (uint256 i = 1; i < nextListingId; i++) {
            if (listings[i].active && listings[i].seller == _wallet) {
                walletCount++;
            }
        }

        ListingDetails[] memory walletListings = new ListingDetails[](walletCount);
        uint256 index = 0;

        // Populate wallet listings
        for (uint256 i = 1; i < nextListingId && index < walletCount; i++) {
            if (listings[i].active && listings[i].seller == _wallet) {
                walletListings[index] = ListingDetails({
                    tokenId: i, // Adjust as needed
                    seller: listings[i].seller,
                    price: listings[i].price,
                    active: listings[i].active,
                    listingId: listings[i].listingId
                });
                index++;
            }
        }

        return walletListings;
    }

    function ownerCancelEveryListing() external onlyOwner nonReentrant {
        uint256 count = 0;
        for (uint256 i = 1; i < nextListingId; i++) {
            if (listings[i].active) {
                listings[i].active = false;
                count++;
                emit ListingCancelled(i, i);
            }
        }
        emit AllListingsCancelled(count);
    }

    function setPoints(uint256 _newBuyerPoints, uint256 _newSellerPoints) external onlyOwner {
        require(_newBuyerPoints > 0, "Buyer points must be greater than zero");
        require(_newSellerPoints > 0, "Seller points must be greater than zero");
        buyerPoints = _newBuyerPoints;
        sellerPoints = _newSellerPoints;
    }

    function setFeeBps(uint256 _newFeeBps) external onlyOwner {
        require(_newFeeBps <= BASIS_POINTS, "Fee too high");
        feeBps = _newFeeBps;
    }

    function setFeeRecipient(address _newFeeRecipient) external onlyOwner {
        require(_newFeeRecipient != address(0), "Invalid address");
        feeRecipient = _newFeeRecipient;
    }

    function setNFTContract(address payable _nftContract) external onlyOwner {
        require(_nftContract != address(0), "Invalid address");
        nftContract = INFTContract(_nftContract);
    }

    function setCurrency(address _currency) external onlyOwner {
        require(_currency != address(0), "Invalid address");
        currency = IERC20Extended(_currency);
    }

    function pause() external onlyOwner {
        _pause();
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit Unpaused(msg.sender);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[50] private __gap; // gap for future upgrades
}