// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2} from "forge-std/Test.sol";
import {RWAToken} from "../src/RWAToken.sol";

contract RWATokenTest is Test {
    RWAToken public token;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        token = new RWAToken();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function test_TokenizeGold() public {
        vm.startPrank(alice);
        
        uint256 tokenId = token.tokenizeGold(
            100,                    // 100 грам
            999,               // Проба
            "CERT123",             // Номер сертифікату
            "Vault A, Box 42",     // Місце зберігання
            "ipfs://bafybeihcv7mvyxze27p2x5ic3w26nro6kok26cs54be4xsq2xaif2qrkla"         // URI метаданих
        );

        assertEq(token.ownerOf(tokenId), alice);
        assertEq(token.getGoldAsset(tokenId).weight, 100);
        assertEq(token.getGoldAsset(tokenId).purity, 999);
        assertEq(token.getGoldAsset(tokenId).certificateId, "CERT123");
        assertEq(token.getGoldAsset(tokenId).vaultLocation, "Vault A, Box 42");
        assertTrue(token.getGoldAsset(tokenId).isActive);
        
        vm.stopPrank();
    }

    function test_UpdateAssetStatus() public {
        vm.startPrank(alice);
        
        uint256 tokenId = token.tokenizeGold(
            100,
            999,
            "CERT123",
            "Vault A, Box 42",
            "ipfs://Qm..."
        );

        token.updateAssetStatus(tokenId, false);
        assertFalse(token.getGoldAsset(tokenId).isActive);

        token.updateAssetStatus(tokenId, true);
        assertTrue(token.getGoldAsset(tokenId).isActive);
        
        vm.stopPrank();
    }

    function test_RevertWhen_UpdateAssetStatusNotOwner() public {
        vm.startPrank(alice);
        uint256 tokenId = token.tokenizeGold(
            100,
            999,
            "CERT123",
            "Vault A, Box 42",
            "ipfs://Qm..."
        );
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert("Not authorized");
        token.updateAssetStatus(tokenId, false);
        vm.stopPrank();
    }

    function test_TokenURI() public {
        vm.startPrank(alice);
        
        string memory uri = "ipfs://Qm...";
        uint256 tokenId = token.tokenizeGold(
            100,
            999,
            "CERT123",
            "Vault A, Box 42",
            uri
        );

        assertEq(token.tokenURI(tokenId), uri);
        
        vm.stopPrank();
    }

    function test_RevertWhen_TokenizeGoldZeroWeight() public {
        vm.startPrank(alice);
        
        vm.expectRevert("Weight must be greater than 0");
        token.tokenizeGold(
            0,                     // Має викинути помилку
            999,
            "CERT123",
            "Vault A, Box 42",
            "ipfs://Qm..."
        );
        
        vm.stopPrank();
    }
} 