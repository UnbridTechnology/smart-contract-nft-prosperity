// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts@5.0.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@5.0.0/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@5.0.0/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts@5.0.0/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Unbrid NFT Prosperity
 * @dev Implements an NFT contract with additional functionalities.
 * This contract inherits from ERC721, ERC721URIStorage, ERC721Burnable, Ownable, and ReentrancyGuard.
 */
contract UnbridNFTProsperity is
    ERC721,
    ERC721URIStorage,
    ERC721Burnable,
    Ownable,
    ReentrancyGuard
{
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    mapping(uint256 => bool) public transferBlocked; // Mapping to indicate if a token's transfer is blocked
    EnumerableMap.UintToAddressMap private _tokenOwners; // Enumerable map to store token owners
    uint256 public MAX_SUPPLY = 5000; // Maximum supply of tokens that can be minted
    string public baseTokenURI; // Base URI for token metadata
    uint256 public totalNFTsMinted = 0; // Total number of NFTs minted
    mapping(uint256 => bool) public mintedIds; // Mapping to track which token IDs have been minted
    IERC20 public usdtToken; // Interface for the USDT token on Polygon network
    event USDTTokenSet(address indexed newUsdtToken);
    event NFTMinted(address indexed to, uint256 tokenId, string uri);
    event TransferBlockedSet(uint256 tokenId, bool blocked);
    event NFTUnlocked(uint256 tokenId, address to);
    event Withdrawn(address indexed to, uint256 amount);
    event UnbridMintExecuted(address indexed user, uint256 tokenId, uint256 totalAmount, uint256 timestamp);
    // Add this state variable to the contract
    uint256 private _minMintAmount = 100 * 10**18; // Initial value of 100 USDT

    /**
     * @dev Constructor for the contract.
     * @param initialOwner Address of the initial contract owner.
     * @param _usdtToken Address of the USDT token contract on Polygon.
     */
    constructor(address initialOwner, address _usdtToken)
        ERC721("UNBRID NFT Prosperity", "UNBRID NFT Prosperity")
        Ownable(initialOwner)
    {
        setUsdtToken(_usdtToken);
    }

    /**
     * @dev Sets a new USDT token contract address.
     * @param newUsdtToken The address of the new USDT token contract.
     */
    function setUsdtToken(address newUsdtToken) public onlyOwner {
        require(newUsdtToken != address(0), "Invalid token address");
        usdtToken = IERC20(newUsdtToken);
        emit USDTTokenSet(newUsdtToken);
    }

    /**
     * @dev Function to mint a new NFT.
     * @param tokenId ID of the token to be minted.
     * @param addrs Array of addresses for commission distribution.
     * @param amounts Array of amounts corresponding to commissions.
     * @param uri URI of the token metadata.
     * @param totalAmount Total amount of USDT to be transferred.
     */
    function unbridMint(
    address user,
    uint256 tokenId,
    address[] memory addrs,
    uint256[] memory amounts,
    string memory uri,
    uint256 totalAmount
) public onlyOwner nonReentrant {
    require(tokenId <= MAX_SUPPLY, "Maximum supply exceeded");
    require(!mintedIds[tokenId], "Token ID already minted");
    require(
        totalAmount >= _minMintAmount,
        "Minting amount is below the minimum"
    );

    totalNFTsMinted++;

    uint256 remainingAmount = totalAmount;

    for (uint256 i = 0; i < addrs.length; i++) {
        require(
            usdtToken.transferFrom(user, addrs[i], amounts[i]),
            "Commission transfer failed"
        );
        remainingAmount -= amounts[i];
    }

    // Transfer remaining amount to owner
    require(
        usdtToken.transferFrom(user, owner(), remainingAmount),
        "Owner transfer failed"
    );

    _safeMint(user, tokenId);
    _setTokenURI(tokenId, uri);
    mintedIds[tokenId] = true;
    transferBlocked[tokenId] = true;
    emit NFTMinted(user, tokenId, uri);
    emit UnbridMintExecuted(user, tokenId, totalAmount, block.timestamp);
}

    /**
     * @dev Mints a new NFT with upgrade privileges and assigns it to a specific address.
     * @param to The address that will own the minted NFT.
     * @param tokenId The ID of the token to be minted.
     * @param uri The URI for the token's metadata.
     */
    function upgradeMint(
        address to,
        uint256 tokenId,
        string memory uri
    ) public nonReentrant onlyOwner {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        transferBlocked[tokenId] = true;
    }

    /**
     * @dev Mints a new NFT as a gift and assigns it to a specific address.
     * @param to The address that will receive the gifted NFT.
     * @param tokenId The ID of the token to be minted.
     * @param uri The URI for the token's metadata.
     */
    function giftMint(
        address to,
        uint256 tokenId,
        string memory uri
    ) public nonReentrant onlyOwner {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        emit NFTMinted(to, tokenId, uri);
    }

    /**
     * @dev Sets the URI for a given token ID.
     * @param tokenId The ID of the token to set the URI for.
     * @param uri The new URI for the token's metadata.
     */
    function setTokenURI(uint256 tokenId, string memory uri) public onlyOwner {
        _setTokenURI(tokenId, uri);
    }

    /**
     * @dev Updates the maximum supply of tokens that can be minted.
     * @param newMaxSupply The new maximum supply value.
     */
    function setMaxSupply(uint256 newMaxSupply) public onlyOwner {
        MAX_SUPPLY = newMaxSupply;
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     * @param tokenId The ID of the token to query.
     * @return A string containing the token URI.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     * @param interfaceId The interface identifier, as specified in ERC-165.
     * @return bool True if the contract supports `interfaceId`, false otherwise.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Burns a specific NFT.
     * @param tokenId The ID of the token to be burned.
     */
    function burn(uint256 tokenId) public override onlyOwner {
        _burn(tokenId);
    }

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     * @param from The current owner of the token.
     * @param to The new owner of the token.
     * @param tokenId The ID of the token to be transferred.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721, IERC721) {
        require(!transferBlocked[tokenId], "Transfer blocked for this NFT");
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @dev Sets the transfer blocked status for a specific token.
     * @param tokenId The ID of the token to set the blocked status for.
     * @param blocked The new blocked status.
     */
    function setTransferBlocked(uint256 tokenId, bool blocked)
        public
        onlyOwner
    {
        transferBlocked[tokenId] = blocked;
        emit TransferBlockedSet(tokenId, blocked);
    }

    /**
     * @dev Unlocks an NFT and transfers it to a specified address.
     * @param tokenId The ID of the token to unlock and transfer.
     * @param to The address to transfer the unlocked NFT to.
     */
    function unlockNFT(address to, uint256 tokenId) public onlyOwner {
        require(transferBlocked[tokenId], "Token is already unlocked");
        transferBlocked[tokenId] = false;
        _transfer(owner(), to, tokenId);
        emit NFTUnlocked(tokenId, to);
    }

    /**
     * @dev Withdraws Ether from the contract.
     * @param to The address to send the Ether to.
     */
    function withdraw(address payable to) public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No Ether to withdraw");
        to.transfer(balance);
        emit Withdrawn(to, balance);
    }

    /**
    * @dev Gets the current minimum amount to mint an NFT.
    * @return The current minimum amount in USDT units (18 decimal places).
    */
    function getMinMintAmount() public view returns (uint256) {
        return _minMintAmount;
    }

    /**
    * @dev Set the minimum amount to mint an NFT.
    * @param newMinAmount New minimum amount in USDT units (18 decimal places).
    */
    function setMinMintAmount(uint256 newMinAmount) public onlyOwner {
        _minMintAmount = newMinAmount;
    }
}
