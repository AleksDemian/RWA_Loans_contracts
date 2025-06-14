// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RWAToken is ERC721Enumerable, Ownable {
    uint256 private _nextTokenId;

    struct GoldAsset {
        uint256 weight;
        uint256 purity;
        string certificateId;
        string vaultLocation;
        bool isActive;
    }

    struct TokenInfo {
        uint256 tokenId;
        GoldAsset asset;
        string tokenURI;
    }

    mapping(uint256 => GoldAsset) public goldAssets;
    mapping(uint256 => string) private _tokenURIs;

    event GoldTokenized(uint256 indexed tokenId, address indexed owner, uint256 weight, uint256 purity);
    event GoldAssetUpdated(uint256 indexed tokenId, bool isActive);

    constructor() ERC721("RWA Gold Token", "RWAG") Ownable(msg.sender) {}

    /**
     * @dev Getting all the owner's tokens
     */
    function tokensOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        uint256[] memory tokens = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            tokens[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokens;
    }

    /**
     * @dev Getting extended information about all owner's tokens
     * @param _owner Address of the token owner
     * @return Array of TokenInfo structs containing token ID, asset details and metadata URI
     */
    function getOwnerTokensInfo(address _owner) external view returns (TokenInfo[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        TokenInfo[] memory tokensInfo = new TokenInfo[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(_owner, i);
            tokensInfo[i] = TokenInfo({tokenId: tokenId, asset: goldAssets[tokenId], tokenURI: _tokenURIs[tokenId]});
        }

        return tokensInfo;
    }

    /**
     * @dev Gold tokenization
     * @param _weight Weight in grams
     * @param _purity Purity
     * @param _certificateId Certificate ID
     * @param _vaultLocation Vault Location
     * @param _tokenURI URI metadata
     */
    function tokenizeGold(
        uint256 _weight,
        uint256 _purity,
        string memory _certificateId,
        string memory _vaultLocation,
        string memory _tokenURI
    ) public returns (uint256) {
        require(_weight > 0, "Weight must be greater than 0");

        uint256 tokenId = _nextTokenId++;

        goldAssets[tokenId] = GoldAsset({
            weight: _weight,
            purity: _purity,
            certificateId: _certificateId,
            vaultLocation: _vaultLocation,
            isActive: true
        });

        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);

        emit GoldTokenized(tokenId, msg.sender, _weight, _purity);
        return tokenId;
    }

    /**
     * @dev Update asset status
     * @param _tokenId Token ID
     * @param _isActive New status
     */
    function updateAssetStatus(uint256 _tokenId, bool _isActive) public onlyOwner {
        require(_exists(_tokenId), "Token does not exist");

        goldAssets[_tokenId].isActive = _isActive;
        emit GoldAssetUpdated(_tokenId, _isActive);
    }

    /**
     * @dev Get token metadata
     * @param _tokenId Token ID
     */
    function getGoldAsset(uint256 _tokenId) public view returns (GoldAsset memory) {
        require(_exists(_tokenId), "Token does not exist");
        return goldAssets[_tokenId];
    }

    /**
     * @dev Set token metadata
     * @param _tokenId Token ID
     * @param _tokenURI Metadata URI
     */
    function _setTokenURI(uint256 _tokenId, string memory _tokenURI) internal {
        _tokenURIs[_tokenId] = _tokenURI;
    }

    /**
     * @dev Get token metadata
     * @param _tokenId Token ID
     */
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), "Token does not exist");
        return _tokenURIs[_tokenId];
    }

    /**
     * @dev Check if token exists
     * @param _tokenId Token ID
     */
    function _exists(uint256 _tokenId) internal view returns (bool) {
        return _ownerOf(_tokenId) != address(0);
    }
}
