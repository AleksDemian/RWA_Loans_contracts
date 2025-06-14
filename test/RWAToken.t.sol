// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2} from "forge-std/Test.sol";
import {RWAToken} from "../src/RWAToken.sol";

contract RWATokenTest is Test {
    RWAToken public token;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    string public testURI = "ipfs://QmTest123";

    function setUp() public {
        token = new RWAToken();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function test_TokenizeGold() public {
        vm.startPrank(alice);

        uint256 tokenId = token.tokenizeGold(
            100, 999, "CERT123", "Vault A, Box 42", "ipfs://bafybeihcv7mvyxze27p2x5ic3w26nro6kok26cs54be4xsq2xaif2qrkla"
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

        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A, Box 42", "ipfs://Qm...");
        vm.stopPrank();

        token.updateAssetStatus(tokenId, false);
        assertFalse(token.getGoldAsset(tokenId).isActive);

        token.updateAssetStatus(tokenId, true);
        assertTrue(token.getGoldAsset(tokenId).isActive);
    }

    function test_RevertWhen_UpdateAssetStatusNotOwner() public {
        vm.startPrank(alice);
        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A, Box 42", "ipfs://Qm...");
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", bob));
        token.updateAssetStatus(tokenId, false);
        vm.stopPrank();
    }

    function test_TokenURI() public {
        vm.startPrank(alice);

        string memory uri = "ipfs://Qm...";
        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A, Box 42", uri);

        assertEq(token.tokenURI(tokenId), uri);

        vm.stopPrank();
    }

    function test_RevertWhen_TokenizeGoldZeroWeight() public {
        vm.startPrank(alice);

        vm.expectRevert("Weight must be greater than 0");
        token.tokenizeGold(0, 999, "CERT123", "Vault A, Box 42", testURI);

        vm.stopPrank();
    }

    function test_TokenizeGoldAndSetURI() public {
        vm.startPrank(alice);

        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A", testURI);

        assertEq(token.ownerOf(tokenId), alice, "Wrong token owner");

        string memory storedURI = token.tokenURI(tokenId);
        assertEq(storedURI, testURI, "Wrong token URI");

        RWAToken.GoldAsset memory asset = token.getGoldAsset(tokenId);
        assertEq(asset.weight, 100, "Wrong weight");
        assertEq(asset.purity, 999, "Wrong purity");
        assertEq(asset.certificateId, "CERT123", "Wrong certificate ID");
        assertEq(asset.vaultLocation, "Vault A", "Wrong vault location");
        assertTrue(asset.isActive, "Asset should be active");

        vm.stopPrank();
    }

    function test_RevertWhen_TokenizeGoldWithInvalidURI() public {
        vm.startPrank(alice);

        token.tokenizeGold(100, 999, "CERT123", "Vault A", "");
    }

    function test_TokenizeGoldAndTransfer() public {
        vm.startPrank(alice);

        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A", testURI);

        string memory uriBefore = token.tokenURI(tokenId);
        assertEq(uriBefore, testURI, "Wrong URI before transfer");

        address newOwner = makeAddr("newOwner");
        token.transferFrom(alice, newOwner, tokenId);

        string memory uriAfter = token.tokenURI(tokenId);
        assertEq(uriAfter, testURI, "URI should remain the same after transfer");

        vm.stopPrank();
    }

    function test_TokenizeGoldMultipleTokens() public {
        vm.startPrank(alice);

        for (uint256 i = 0; i < 3; i++) {
            uint256 tokenId = token.tokenizeGold(
                100 + i,
                999,
                string(abi.encodePacked("CERT", vm.toString(i))),
                string(abi.encodePacked("Vault ", vm.toString(i))),
                string(abi.encodePacked(testURI, vm.toString(i)))
            );

            string memory storedURI = token.tokenURI(tokenId);
            assertEq(storedURI, string(abi.encodePacked(testURI, vm.toString(i))), "Wrong token URI");
        }

        vm.stopPrank();
    }

    function test_TokensOfOwner() public {
        vm.startPrank(alice);
        uint256 tokenId1 = token.tokenizeGold(100, 999, "CERT1", "Vault A", "ipfs://Qm1");
        uint256 tokenId2 = token.tokenizeGold(200, 999, "CERT2", "Vault B", "ipfs://Qm2");
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 tokenId3 = token.tokenizeGold(400, 999, "CERT3", "Vault C", "ipfs://Qm3");
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 tokenId4 = token.tokenizeGold(300, 999, "CERT3", "Vault E", "ipfs://Qm3");
        vm.stopPrank();

        uint256[] memory aliceTokens = token.tokensOfOwner(alice);
        assertEq(aliceTokens.length, 3, "Alice should have 3 tokens");
        assertEq(aliceTokens[0], tokenId1, "First token should be tokenId1");
        assertEq(aliceTokens[1], tokenId2, "Second token should be tokenId2");
        assertEq(aliceTokens[2], tokenId4, "Third token should be tokenId3");

        uint256[] memory bobTokens = token.tokensOfOwner(bob);
        assertEq(bobTokens.length, 1, "Bob should have 0 tokens");

        vm.startPrank(alice);
        token.transferFrom(alice, bob, tokenId2);
        vm.stopPrank();

        aliceTokens = token.tokensOfOwner(alice);
        assertEq(aliceTokens.length, 2, "Alice should have 2 tokens after transfer");
        assertEq(aliceTokens[0], tokenId1, "First token should still be tokenId1");
        assertEq(aliceTokens[1], tokenId4, "Second token should be tokenId3");

        bobTokens = token.tokensOfOwner(bob);
        assertEq(bobTokens.length, 2, "Bob should have 1 token after transfer");
        assertEq(bobTokens[0], tokenId3, "Bob's token should be tokenId3");
        assertEq(bobTokens[1], tokenId2, "Bob's token should be tokenId2");
    }
}
