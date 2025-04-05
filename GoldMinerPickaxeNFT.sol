// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title GoldMinerPickaxeNFT
 * @dev Implementation of the Gold Miner Pickaxe NFT using ERC721Enumerable standard
 */
contract GoldMinerPickaxeNFT is ERC721Enumerable {
    using Strings for uint256;
    
    // Events specific to our implementation
    event PickaxeMinted(address indexed to, uint256 indexed tokenId, uint8 pickaxeType);
    event PickaxeStaked(address indexed owner, uint256 indexed tokenId, uint8 pickaxeType);
    event PickaxeUnstaked(address indexed owner, uint256 indexed tokenId, uint8 pickaxeType);
    
    // Pickaxe types (0: BRONZE, 1: SILVER, 2: GOLD, 3: DIAMOND)
    uint8 public constant BRONZE = 0;
    uint8 public constant SILVER = 1;
    uint8 public constant GOLD = 2;
    uint8 public constant DIAMOND = 3;
    
    // Maximum supply of NFTs
    uint256 public constant MAX_SUPPLY = 1500;
    
    // Minting price (100 ETH)
    uint256 public mintPrice = 100 ether;
    
    // Base URIs for metadata by pickaxe type
    string private _bronzeBaseURI;
    string private _silverBaseURI;
    string private _goldBaseURI;
    string private _diamondBaseURI;
    
    // Contract owner
    address private _owner;
    
    // Mapping from token ID to pickaxe type
    mapping(uint256 => uint8) private _pickaxeTypes;
    
    // Mapping from token ID to staking status
    mapping(uint256 => bool) private _stakedPickaxes;
    
    // Mapping from owner to staked pickaxes count by type
    mapping(address => mapping(uint8 => uint256)) private _stakedPickaxesByType;
    
    // Mapping to track total minted pickaxes by type
    mapping(uint8 => uint256) private _mintedByType;
    
    // Maximum counts for each type
    uint256 public constant MAX_DIAMOND = 75;  // 5% of 1500
    uint256 public constant MAX_GOLD = 225;    // 15% of 1500
    uint256 public constant MAX_SILVER = 450;  // 30% of 1500
    uint256 public constant MAX_BRONZE = 750;  // 50% of 1500
    
    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }
    
    /**
     * @dev Checks if a token exists by trying to find its owner
     */
    function _isValidToken(uint256 tokenId) internal view returns (bool) {
        try this.ownerOf(tokenId) returns (address) {
            return true;
        } catch {
            return false;
        }
    }
    
    /**
     * @dev Determines the pickaxe type based on available supply and randomness
     */
    function _determinePickaxeType() internal view returns (uint8) {
        // Check if we can still mint each type
        bool canMintDiamond = _mintedByType[DIAMOND] < MAX_DIAMOND;
        bool canMintGold = _mintedByType[GOLD] < MAX_GOLD;
        bool canMintSilver = _mintedByType[SILVER] < MAX_SILVER;
        bool canMintBronze = _mintedByType[BRONZE] < MAX_BRONZE;
        
        // Simple randomness based on block timestamp
        uint256 randomValue = block.timestamp % 100;
        
        // Determine type based on randomness and available supply
        if (canMintDiamond && randomValue < 5) {
            return DIAMOND;
        } else if (canMintGold && randomValue < 20) { // 5 + 15 = 20
            return GOLD;
        } else if (canMintSilver && randomValue < 50) { // 20 + 30 = 50
            return SILVER;
        } else if (canMintBronze) {
            return BRONZE;
        }
        
        // If we can't mint the randomly selected type, find the first available type
        if (canMintDiamond) return DIAMOND;
        if (canMintGold) return GOLD;
        if (canMintSilver) return SILVER;
        return BRONZE;
    }
    
    /**
     * @dev Internal function to mint a pickaxe and assign its type
     */
    function _mintPickaxe(address to, uint256 tokenId) internal {
        // Determine pickaxe type based on available supply and randomness
        uint8 pickaxeType = _determinePickaxeType();
        
        // Mint the token using OpenZeppelin's _safeMint
        _safeMint(to, tokenId);
        
        // Assign pickaxe type
        _pickaxeTypes[tokenId] = pickaxeType;
        _mintedByType[pickaxeType]++;
        
        emit PickaxeMinted(to, tokenId, pickaxeType);
    }
    
    /**
     * @dev Initializes the contract by setting a `name` and a `symbol`
     */
    constructor() ERC721("Gold Miner Pickaxe", "PICKAXE") {
        _bronzeBaseURI = "";
        _silverBaseURI = "";
        _goldBaseURI = "";
        _diamondBaseURI = "";
        _owner = msg.sender;
        
        // Mint 300 NFTs directly for the owner
        address ownerAddress = msg.sender;
        for (uint256 i = 0; i < 300; i++) {
            uint256 tokenId = i + 1;
            _mintPickaxe(ownerAddress, tokenId);
        }
    }
    
    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }
    
    /**
     * @dev Sets the base URI for all token metadata (legacy support)
     */
    function setBaseURI(string memory baseURI) external onlyOwner {
        _bronzeBaseURI = baseURI;
        _silverBaseURI = baseURI;
        _goldBaseURI = baseURI;
        _diamondBaseURI = baseURI;
    }
    
    /**
     * @dev Sets the base URI for a specific pickaxe type
     */
    function setTypeBaseURI(uint8 pickaxeType, string memory baseURI) external onlyOwner {
        require(pickaxeType <= DIAMOND, "Invalid pickaxe type");
        
        if (pickaxeType == BRONZE) {
            _bronzeBaseURI = baseURI;
        } else if (pickaxeType == SILVER) {
            _silverBaseURI = baseURI;
        } else if (pickaxeType == GOLD) {
            _goldBaseURI = baseURI;
        } else if (pickaxeType == DIAMOND) {
            _diamondBaseURI = baseURI;
        }
    }
    
    /**
     * @dev Returns the base URI for token metadata based on pickaxe type
     */
    function _baseURI() internal view override returns (string memory) {
        return "";
    }
    
    /**
     * @dev Returns the token URI for a given token ID
     * Overrides the ERC721 implementation to return type-specific URIs
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_isValidToken(tokenId), "ERC721Metadata: URI query for nonexistent token");
        
        uint8 pickaxeType = _pickaxeTypes[tokenId];
        string memory baseURI;
        
        if (pickaxeType == BRONZE) {
            baseURI = _bronzeBaseURI;
        } else if (pickaxeType == SILVER) {
            baseURI = _silverBaseURI;
        } else if (pickaxeType == GOLD) {
            baseURI = _goldBaseURI;
        } else if (pickaxeType == DIAMOND) {
            baseURI = _diamondBaseURI;
        }
        
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }
    
    /**
     * @dev Public mint function - sends ETH directly to owner
     * @param amount Number of pickaxes to mint (1-10)
     */
    function mint(uint256 amount) external payable {
        require(amount > 0 && amount <= 10, "Can mint 1-10 pickaxes at once");
        require(totalSupply() + amount <= MAX_SUPPLY, "Would exceed max supply");
        
        // Owner can mint for free
        if (msg.sender != owner()) {
            require(msg.value >= mintPrice * amount, "Insufficient payment");
            // Send ETH directly to owner
            payable(owner()).transfer(msg.value);
        }
        
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = totalSupply() + 1;
            _mintPickaxe(msg.sender, tokenId);
        }
    }
    
    /**
     * @dev Owner mint function (free minting)
     */
    function ownerMint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Would exceed max supply");
        
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = totalSupply() + 1;
            _mintPickaxe(to, tokenId);
        }
    }
    
    /**
     * @dev Returns the pickaxe type for a given token ID
     */
    function getPickaxeType(uint256 tokenId) external view returns (uint8) {
        require(_isValidToken(tokenId), "Token does not exist");
        return _pickaxeTypes[tokenId];
    }
    
    /**
     * @dev Returns the staking status for a given token ID
     */
    function isStaked(uint256 tokenId) external view returns (bool) {
        require(_isValidToken(tokenId), "Token does not exist");
        return _stakedPickaxes[tokenId];
    }
    
    /**
     * @dev Stakes a pickaxe
     */
    function stakePickaxe(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        require(!_stakedPickaxes[tokenId], "Already staked");
        
        _stakedPickaxes[tokenId] = true;
        uint8 pickaxeType = _pickaxeTypes[tokenId];
        _stakedPickaxesByType[msg.sender][pickaxeType]++;
        
        emit PickaxeStaked(msg.sender, tokenId, pickaxeType);
    }
    
    /**
     * @dev Unstakes a pickaxe
     */
    function unstakePickaxe(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        require(_stakedPickaxes[tokenId], "Not staked");
        
        _stakedPickaxes[tokenId] = false;
        uint8 pickaxeType = _pickaxeTypes[tokenId];
        _stakedPickaxesByType[msg.sender][pickaxeType]--;
        
        emit PickaxeUnstaked(msg.sender, tokenId, pickaxeType);
    }
    
    /**
     * @dev Returns the number of staked pickaxes by type for an address
     */
    function getStakedPickaxesByType(address owner) external view returns (uint256 bronze, uint256 silver, uint256 gold, uint256 diamond) {
        bronze = _stakedPickaxesByType[owner][BRONZE];
        silver = _stakedPickaxesByType[owner][SILVER];
        gold = _stakedPickaxesByType[owner][GOLD];
        diamond = _stakedPickaxesByType[owner][DIAMOND];
    }
    
    /**
     * @dev Returns the total minted pickaxes by type
     */
    function getMintedByType() external view returns (uint256 bronze, uint256 silver, uint256 gold, uint256 diamond) {
        bronze = _mintedByType[BRONZE];
        silver = _mintedByType[SILVER];
        gold = _mintedByType[GOLD];
        diamond = _mintedByType[DIAMOND];
    }
    
    /**
     * @dev Withdraws contract balance to owner
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }
    
    /**
     * @dev Set the mint price
     */
    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }
    
    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _owner = newOwner;
    }
}
