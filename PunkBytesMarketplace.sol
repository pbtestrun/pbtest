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
        address seller;
        uint256 price;
        uint256 tokenId;
        bool active;
    }

    // Storage for tracking listed token IDs

    // Array of all listed NFT tokenIds in the marketplace
    // Tracks active listings for iteration (e.g. in ownerCancelListings or frontends)
    uint256[] private listedTokenIds;

    // Maps tokenId to its index in listedTokenIds
    // Enables efficient removals in buy, cancel, or ownerCancelListings
    mapping(uint256 => uint256) private tokenIdToIndex;

    // Maps wallet address to its listed tokenIds
    // Tracks all NFTs listed by a wallet for user-specific queries or cancellations
    mapping(address => uint256[]) private walletToTokenIds;

    // Maps wallet address and tokenId to index in walletToTokenIds
    // Facilitates fast removals of specific tokenIds from a wallet’s listings
    mapping(address => mapping(uint256 => uint256)) private walletTokenIdToIndex;

    mapping(uint256 => Listing) public listings; // tokenId => Listing

    struct ListingDetails {
        uint256 tokenId;
        address seller;
        uint256 price;
        bool active;
    }

    // Storage for tracking collection offers

    struct Offer {
        address bidder; 
        uint256 price;
        bool active;
    }

    // Array of all active collection-wide offer IDs in the marketplace
    // Tracks open bids for iteration (e.g. in getEveryOffer or ownerCancelEveryOffer)
    uint256[] public activeOfferIds;

    // Counter for generating unique offer IDs
    // Increments for each new offer created in createOffer
    uint256 public nextOfferId;

    // Maps offer ID to its Offer struct containing bidder, price, and status
    // Stores details of each collection-wide bid for retrieval and processing
    mapping(uint256 => Offer) public offers;

    // Maps offer ID to its index in activeOfferIds array
    // Enables efficient removals in acceptOffer, cancelOffer, or ownerCancelEveryOffer
    mapping(uint256 => uint256) public offerIdToIndex;

    // Maps wallet address to their collection-wide offer IDs
    // Tracks all bids placed by a wallet for user-specific queries or cancellations
    mapping(address => uint256[]) public walletToOfferIds;

    // Maps wallet address and offer ID to index in walletToOfferIds array
    // Facilitates fast removals of specific offers from a wallet’s bids
    mapping(address => mapping(uint256 => uint256)) public walletOfferIdToIndex;

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
    }

    function list(uint256 _tokenId, uint256 _price) external whenNotPaused nonReentrant {

        // Checks
        require(_price > 0, "Price must be greater than zero");
        require(_price <= type(uint256).max / feeBps, "Price too high");
        require(nftContract.ownerOf(_tokenId) == msg.sender, "Not owner");
        require(listings[_tokenId].active == false, "Already listed");

        require(
            nftContract.getApproved(_tokenId) == address(this) ||
            nftContract.isApprovedForAll(msg.sender, address(this)),
            "Marketplace not approved"
        );

        // Effects (State updates)
        listings[_tokenId] = Listing({
            seller: msg.sender,
            tokenId: _tokenId,
            price: _price,
            active: true
        });

        listedTokenIds.push(_tokenId);
        tokenIdToIndex[_tokenId] = listedTokenIds.length - 1;
        walletToTokenIds[msg.sender].push(_tokenId);
        walletTokenIdToIndex[msg.sender][_tokenId] = walletToTokenIds[msg.sender].length - 1;

        // Interaction
        nftContract.safeTransferFrom(msg.sender, address(this), _tokenId);
    }

    function buy(uint256 _tokenId) external whenNotPaused nonReentrant {

        // Checks
        Listing memory listing = listings[_tokenId];
        require(listing.active, "Not listed");
        require(currency.balanceOf(msg.sender) >= listing.price, "Insufficient balance");
        require(currency.allowance(msg.sender, address(this)) >= listing.price, "Insufficient allowance");

        // Calculate fees and proceeds
        uint256 fee = (listing.price * feeBps) / BASIS_POINTS;
        uint256 sellerProceeds = listing.price - fee;

        listings[_tokenId].active = false;
        currency.safeTransferFrom(msg.sender, listing.seller, sellerProceeds);

        // External Interactions
        currency.safeTransferFrom(msg.sender, listing.seller, sellerProceeds);
        if (fee > 0) {
            currency.safeTransferFrom(msg.sender, feeRecipient, fee);
        }

        nftContract.safeTransferFrom(address(this), msg.sender, _tokenId);
        nftContract.assignPoints(msg.sender, buyerPoints);
        nftContract.assignPoints(listing.seller, sellerPoints);

        _removeListing(_tokenId, listing.seller);
    }

    function cancel(uint256 _tokenId) external whenNotPaused nonReentrant {

        // Checks
        Listing memory listing = listings[_tokenId];
        require(listing.active, "Not listed");
        require(listing.seller == msg.sender, "Not seller");

        listings[_tokenId].active = false;
        nftContract.safeTransferFrom(address(this), msg.sender, _tokenId);

        _removeListing(_tokenId, msg.sender);
    }

    // Collection offers
    
    function createOffer(uint256 _price) external whenNotPaused nonReentrant {

        require(_price > 0, "Price must be greater than zero");
        require(currency.balanceOf(msg.sender) >= _price, "Insufficient balance");
        require(currency.allowance(msg.sender, address(this)) >= _price, "Insufficient allowance");

        uint256 offerId = nextOfferId++;
        offers[offerId] = Offer({
            bidder: msg.sender,
            price: _price,
            active: true
        });

        activeOfferIds.push(offerId);
        offerIdToIndex[offerId] = activeOfferIds.length - 1;
        walletToOfferIds[msg.sender].push(offerId);
        walletOfferIdToIndex[msg.sender][offerId] = walletToOfferIds[msg.sender].length - 1;

        currency.safeTransferFrom(msg.sender, address(this), _price);
    }

    /// @notice accepts a collection-wide offer for a specific NFT
    /// @param _offerId the ID of the offer to accept
    /// @param _tokenId the NFT token ID to sell

    function acceptOffer(uint256 _offerId, uint256 _tokenId) external whenNotPaused nonReentrant {
        
        Offer memory offer = offers[_offerId];
        require(offer.active, "Offer not active");
        require(nftContract.ownerOf(_tokenId) == msg.sender, "Not token owner");

        require(
            nftContract.getApproved(_tokenId) == address(this) ||
            nftContract.isApprovedForAll(msg.sender, address(this)), 
            "Marketplace not approved"
        );

        uint256 fee = (offer.price * feeBps) / BASIS_POINTS;
        uint256 sellerProceeds = offer.price - fee;

        offers[_offerId].active = false;

        currency.safeTransfer(msg.sender, sellerProceeds);
        if (fee > 0) {
            currency.safeTransfer(feeRecipient, fee);
        }

        nftContract.safeTransferFrom(msg.sender, offer.bidder, _tokenId);
        nftContract.assignPoints(offer.bidder, buyerPoints);
        nftContract.assignPoints(msg.sender, sellerPoints);

        _removeOffer(_offerId, offer.bidder);
    }

    /// @notice cancels a specific collection-wide offer
    /// @param _offerId ID of the offer to cancel

    function cancelOffer(uint256 _offerId) external whenNotPaused nonReentrant {

        Offer memory offer = offers[_offerId];
        require(offer.active, "Offer not active");
        require(offer.bidder == msg.sender, "Not bidder");

        offers[_offerId].active = false;
        currency.safeTransfer(msg.sender, offer.price);

        _removeOffer(_offerId, msg.sender);
    }

    /// @notice Cancels all collection-wide offers made by the caller

    function cancelEveryOffer() external whenNotPaused nonReentrant {

        uint256[] memory offerIds = walletToOfferIds[msg.sender];
        // uint256 length = offerIds.length;

        for (uint256 i = 0; i < offerIds.length; i++) {
            uint256 offerId = offerIds[i];
            Offer memory offer = offers[offerId];

            if (offer.active) {
                offers[offerId].active = false;
                currency.safeTransfer(msg.sender, offer.price);
                _removeOffer(offerId, msg.sender);
            }
        }

        // Clear walletToOfferIds and walletOfferIdToIndex
            delete walletToOfferIds[msg.sender];
            // Implicitly clears walletOfferIdToIndex
    }

    /// @notice returns all active listings in the marketplace
    /// @return an array of ListingDetails for all active listings

    function getActiveListings() external view returns (ListingDetails[] memory) {

        ListingDetails[] memory activeListings = new ListingDetails[](listedTokenIds.length);

        for (uint256 i = 0; i < listedTokenIds.length; i++) {
            uint256 tokenId = listedTokenIds[i];
            activeListings[i] = ListingDetails({
                tokenId: tokenId,
                seller: listings[tokenId].seller,
                price: listings[tokenId].price,
                active: listings[tokenId].active
            });
        }
        return activeListings;
    }

    /// @notice returns all active listings for a specific wallet
    /// @param _wallet the address of the wallet to query
    /// @return an array of ListingDetails for the wallet's active listings

    function getWalletListings(address _wallet) external view returns (ListingDetails[] memory) {

        require(_wallet != address(0), "Invalid wallet address");
        uint256[] memory tokenIds = walletToTokenIds[_wallet];

        ListingDetails[] memory walletListings = new ListingDetails[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            walletListings[i] = ListingDetails({
                tokenId: tokenId,
                seller: _wallet,
                price: listings[tokenId].price,
                active: listings[tokenId].active
            });
        }
        return walletListings;
    }

    function getEveryOffer() external view returns (uint256[] memory offerIds, Offer[] memory offerDetails) {
        offerIds = activeOfferIds;
        offerDetails = new Offer[](offerIds.length);
        for (uint256 i = 0; i < offerIds.length; i++) {
            offerDetails[i] = offers[offerIds[i]];
        }
    }

    function getWalletOffers(address _wallet) external view returns (uint256[] memory offerIds, Offer[] memory offerDetails) {
        offerIds = walletToOfferIds[_wallet];
        offerDetails = new Offer[](offerIds.length);
        for (uint256 i = 0; i < offerIds.length; i++) {
            offerDetails[i] = offers[offerIds[i]];
        }
    }

    function getSingleOffer(uint256 _offerId) external view returns (Offer memory) {
        return offers[_offerId];
    }

    /// @notice cancels all active listings and returns NFTs from excrow to owners
    /// callable only by owner, emits Canceled for each listing and adminCanceledListings

    function ownerCancelListings(uint256 start, uint256 batchSize) external onlyOwner nonReentrant {

        require(start < listedTokenIds.length, "Invalid start index");
        uint256 end = start + batchSize < listedTokenIds.length ? start + batchSize : listedTokenIds.length;

        // Store state changes until after external calls (temp arrays)
        uint256[] memory tokenIdsToCancel = new uint256[](end - start);
        address[] memory sellers = new address[](end - start);
        uint256 cancelCount = 0;

        // Perform Checks and External Interactions
        for (uint256 i = start; i < end; i++) {
            uint256 tokenId = listedTokenIds[i];
            Listing memory listing = listings[tokenId];

            if (listing.active) {

                nftContract.safeTransferFrom(
                    address(this),
                    listing.seller,
                    tokenId
                );
                tokenIdsToCancel[cancelCount] = tokenId;
                sellers[cancelCount] = listing.seller;
                cancelCount++;
            }
        }

        // Perform state updates
        for (uint256 i = 0; i < cancelCount; i++) {
            uint256 tokenId = tokenIdsToCancel[i];
            address seller = sellers[i];

            listings[tokenId].active = false;
            _removeListing(tokenId, seller);
        }
    }

    /// @notice cancels all active collection-wide offers (owner only)
    /// @param start starting index in activeOfferIds to begin cancellation
    /// @param batchSize the number of offers to process in that specific batch
    
    function ownerCancelEveryOffer(uint256 start, uint256 batchSize) external onlyOwner nonReentrant {

        require(start < activeOfferIds.length, "Invalid start index");
        uint256 end = start + batchSize < activeOfferIds.length ? start + batchSize : activeOfferIds.length;

        // Store state changes until after external calls (temp arrays)
        uint256[] memory offerIdsToCancel = new uint256[](end - start);
        address[] memory bidders = new address[](end - start);
        uint256 cancelCount = 0;

        // Perform Checks and External Interactions
        for (uint256 i = start; i < end; i++) {
            uint256 offerId = activeOfferIds[i];
            Offer memory offer = offers[offerId];

            if (offer.active) {

                currency.safeTransfer(
                    offer.bidder,
                    offer.price
                );

                offerIdsToCancel[cancelCount] = offerId;
                bidders[cancelCount] = offer.bidder;
                cancelCount++;
            }
        }

        // Perform state updates
        for (uint256 i = 0; i < cancelCount; i++) {
            uint256 offerId = offerIdsToCancel[i];
            address bidder = bidders[i];

            offers[offerId].active = false;
            _removeOffer(offerId, bidder);
        }
    }

    function setPoints(uint256 _newBuyerPoints, uint256 _newSellerPoints) external onlyOwner {
        require(_newBuyerPoints > 0, "Buyer points must be greater than zero");
        require(_newSellerPoints > 0, "Seller points must be greater than zero");
        buyerPoints = _newBuyerPoints;
        sellerPoints = _newSellerPoints;
    }

    // Update fee percentage
    function setFeeBps(uint256 _newFeeBps) external onlyOwner {
        require(_newFeeBps <= BASIS_POINTS, "Fee too high");
        feeBps = _newFeeBps;
    }

    // Update fee recipient
    function setFeeRecipient(address _newFeeRecipient) external onlyOwner {
        require(_newFeeRecipient != address(0), "Invalid address");
        feeRecipient = _newFeeRecipient;
    }

    // Set both NFT related contracts
    function setNFTContract(address payable _nftContract) external onlyOwner {
        require(_nftContract != address(0), "Invalid address");
        nftContract = INFTContract(_nftContract);
    }

    function setCurrency(address _currency) external onlyOwner {
        require(_currency != address(0), "Invalid address");
        currency = IERC20Extended(_currency);
    }

    function getSingleListing(uint256 _tokenId) external view returns (Listing memory) {
        return listings[_tokenId];
    }

    function isListed(uint256 tokenId) external view returns (bool) {
        return listings[tokenId].active;
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function _removeListing(uint256 _tokenId, address _seller) private {
        uint256 index = tokenIdToIndex[_tokenId];
        if (listedTokenIds.length > 1) {
            listedTokenIds[index] = listedTokenIds[listedTokenIds.length - 1];
            tokenIdToIndex[listedTokenIds[index]] = index;
        }
        listedTokenIds.pop();
        delete tokenIdToIndex[_tokenId];

        uint256 walletIndex = walletTokenIdToIndex[_seller][_tokenId];
        if (walletToTokenIds[_seller].length > 1) {
            walletToTokenIds[_seller][walletIndex] = walletToTokenIds[_seller][walletToTokenIds[_seller].length - 1];
            walletTokenIdToIndex[_seller][walletToTokenIds[_seller][walletIndex]] = walletIndex;
        }
        walletToTokenIds[_seller].pop();
        delete walletTokenIdToIndex[_seller][_tokenId];
    }

    function _removeOffer(uint256 _offerId, address _bidder) private {
        uint256 index = offerIdToIndex[_offerId];
        if (activeOfferIds.length > 1) {
            activeOfferIds[index] = activeOfferIds[activeOfferIds.length - 1];
            offerIdToIndex[activeOfferIds[index]] = index;
        }
        activeOfferIds.pop();
        delete offerIdToIndex[_offerId];

        uint256 walletIndex = walletOfferIdToIndex[_bidder][_offerId];
        if (walletToOfferIds[_bidder].length > 1) {
            walletToOfferIds[_bidder][walletIndex] = walletToOfferIds[_bidder][walletToOfferIds[_bidder].length - 1];
            walletOfferIdToIndex[_bidder][walletToOfferIds[_bidder][walletIndex]] = walletIndex;
        }
        walletToOfferIds[_bidder].pop();
        delete walletOfferIdToIndex[_bidder][_offerId];
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {} // override required
    
    uint256[50] private __gap; // gap for future upgrades
}