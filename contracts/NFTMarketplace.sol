// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4; 

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";


contract NFTMarketplace is ERC721URIStorage {
 
    using Counters for Counters.Counter;

    // @notice when the first token is minted it'll get a value of zero, the second one is one
 
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;

    // @notice fee to list an nft on the marketplace, charing native token
 
    uint256 listingPrice = 0.025 ether;

    // @notice owner earns a commision on every item sold
    address payable owner;

    // @notice keeping up with all the items that have been created
    // @dev pass in the integer which is the item id and it returns a market item.
    mapping(uint256 => MarketItem) private idToMarketItem;

    struct MarketItem {
      uint256 tokenId;
      address payable seller;
      address payable owner;
      uint256 price;
      bool sold;
    }

    // @notice have an event for when a market item is created.
    // @notice this event matches the MarketItem
    event MarketItemCreated ( 
      uint256 indexed tokenId,
      address seller,
      address owner,
      uint256 price,
      bool sold
    );

    constructor() ERC721("Metaverse Tokens", "METT") {
      owner = payable(msg.sender);
    }

    // @notice Updates the listing price of the contract 

    
    function updateListingPrice(uint _listingPrice) public payable {
      require(owner == msg.sender, "Only marketplace owner can update listing price.");
      listingPrice = _listingPrice;
    }

    // @notice Returns the listing price of the contract 
    function getListingPrice() public view returns (uint256) {
      return listingPrice;
    }

    // @notice Mints a token and lists it in the marketplace 
    function createToken(string memory tokenURI, uint256 price) public payable returns (uint) {
      _tokenIds.increment();
      // @notice create a variable that get's the current value of the tokenIds
      uint256 newTokenId = _tokenIds.current();
      _mint(msg.sender, newTokenId);
      _setTokenURI(newTokenId, tokenURI);
      createMarketItem(newTokenId, price);
      return newTokenId;
    }



    function createMarketItem(uint256 tokenId, uint256 price) private {
      // @notice price must be greater than 0
      require(price > 0, "Price must be at least 1 wei");
      // @notice require that the users sending in the transaction is sending in the correct amount
      // @dev consider a refund mechanism when more eth is sent than required 
      require(msg.value == listingPrice, "Price must be equal to listing price");

      idToMarketItem[tokenId] =  MarketItem(
        tokenId,
        payable(msg.sender),
        payable(address(this)),
        price,
        false
      );

      // @notice transfer the ownership of the nft to the contract -> next buyer
      _transfer(msg.sender, address(this), tokenId);
      emit MarketItemCreated(
        tokenId,
        msg.sender,
        address(this),
        price,
        false
      );
    }

    // @notice allows someone to resell a token they have purchased 
    function resellToken(uint256 tokenId, uint256 price) public payable {
      require(idToMarketItem[tokenId].owner == msg.sender, "Only item owner can perform this operation");
      // @dev can be updated for the refund mechanism
      require(msg.value == listingPrice, "Price must be equal to listing price");
      idToMarketItem[tokenId].sold = false;
      idToMarketItem[tokenId].price = price;
      idToMarketItem[tokenId].seller = payable(msg.sender);
      idToMarketItem[tokenId].owner = payable(address(this));
      _itemsSold.decrement();

      _transfer(msg.sender, address(this), tokenId);
    }

    // @notice creates the sale of a marketplace item */
    // @notice Transfers ownership of the item, as well as funds between parties
    function createMarketSale(uint256 tokenId) public payable {
      uint price = idToMarketItem[tokenId].price;
      require(msg.value == price, "Please submit the asking price in order to complete the purchase");
      idToMarketItem[tokenId].owner = payable(msg.sender);
      idToMarketItem[tokenId].sold = true;
      idToMarketItem[tokenId].seller = payable(address(0));
      _itemsSold.increment();
      
      _transfer(address(this), msg.sender, tokenId);

      // check with C: why is that necessary? the seller paid the listing fee already... 
      payable(owner).transfer(listingPrice);
      payable(idToMarketItem[tokenId].seller).transfer(msg.value);
    }

    // @dev helper function for getting an array of id
    function fetchMarketItems() public view returns (MarketItem[] memory) {
      uint itemCount = _tokenIds.current();
      uint unsoldItemCount = _tokenIds.current() - _itemsSold.current();
      uint currentIndex = 0;

      // @dev looping over the number of items created and incremnet that number if we have an empty address 

      // @dev empty array called items
      // @dev the type of the element in the array is marketitem, and the unsolditemcount is the length
      MarketItem[] memory items = new MarketItem[](unsoldItemCount);
      for (uint i = 0; i < itemCount; i++) {
        // @dev check to see if the item is unsold -> checking if the owner is an empty address -> then it's unsold
        // above, where we were creating a new market item, we were setting the address to be an empty address
        if (idToMarketItem[i + 1].owner == address(this)) {
          // @dev the id of the item that we're currently interracting with
          uint currentId = i + 1;
          // @dev get the mapping of the idtomarketitem -> gives us the reference to the marketitem
          MarketItem storage currentItem = idToMarketItem[currentId];
          // @dev insert the market item to the items array
          items[currentIndex] = currentItem;
          // @dev increment the current index
          currentIndex += 1;
        }
      }

      return items;
    }

    // @notice Returns only items that a user has purchased 
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
      uint totalItemCount = _tokenIds.current();
      uint itemCount = 0;
      uint currentIndex = 0;

      // @dev gives us the number of items that the user owns
      for (uint i = 0; i < totalItemCount; i++) {
        // @dev check if nft belongs to the user 
        if (idToMarketItem[i + 1].owner == msg.sender) {
          itemCount += 1;
        }
      }

      //@dev same logic as fetchMarketItems

      MarketItem[] memory items = new MarketItem[](itemCount);
      for (uint i = 0; i < totalItemCount; i++) {
        if (idToMarketItem[i + 1].owner == msg.sender) {
          uint currentId = i + 1;
          MarketItem storage currentItem = idToMarketItem[currentId];
          items[currentIndex] = currentItem;
          currentIndex += 1;
        }
      }
      return items;
    }

    // @notice Returns only items a user has listed 
    function fetchItemsListed() public view returns (MarketItem[] memory) {
      uint totalItemCount = _tokenIds.current();
      uint itemCount = 0;
      uint currentIndex = 0;

      for (uint i = 0; i < totalItemCount; i++) {
        if (idToMarketItem[i + 1].seller == msg.sender) {
          itemCount += 1;
        }
      }

            //@dev same logic as fetchMarketItems

      MarketItem[] memory items = new MarketItem[](itemCount);
      for (uint i = 0; i < totalItemCount; i++) {
        if (idToMarketItem[i + 1].seller == msg.sender) {
          uint currentId = i + 1;
          MarketItem storage currentItem = idToMarketItem[currentId];
          items[currentIndex] = currentItem;
          currentIndex += 1;
        }
      }
      
      return items;
    }
}