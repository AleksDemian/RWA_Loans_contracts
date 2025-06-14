// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2} from "forge-std/Test.sol";
import {RWAToken} from "../src/RWAToken.sol";
import {RWALending} from "../src/RWALending.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockChainlinkAggregator} from "./mocks/MockChainlinkAggregator.sol";

contract RWALendingTest is Test {
    RWAToken public token;
    RWALending public lending;
    MockERC20 public stablecoin;
    MockChainlinkAggregator public priceFeed;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    uint256 public constant INITIAL_BALANCE = 1000000 * 1e18;
    uint256 public constant GOLD_PRICE = 2000 * 1e8;
    uint32 public constant HEARTBEAT = 3600;

    function setUp() public {
        stablecoin = new MockERC20("Stablecoin", "STB", 18);
        token = new RWAToken();
        priceFeed = new MockChainlinkAggregator(8, int256(GOLD_PRICE));

        lending = new RWALending(address(stablecoin), address(token), address(priceFeed), 500);

        stablecoin.mint(alice, INITIAL_BALANCE);
        stablecoin.mint(bob, INITIAL_BALANCE);
        stablecoin.mint(address(lending), INITIAL_BALANCE * 2);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function test_Constructor() public view {
        assertEq(address(lending.stablecoin()), address(stablecoin), "Wrong stablecoin address");
        assertEq(address(lending.token()), address(token), "Wrong token address");
        assertEq(address(lending.goldPriceFeed()), address(priceFeed), "Wrong price feed address");
        assertEq(lending.interestRate(), 500, "Wrong interest rate");
    }

    function test_InitialState() public view {
        assertEq(lending.totalLoans(), 0, "Total loans should be 0");
        assertEq(lending.owner(), address(this), "Wrong owner");
    }

    function test_CalculateCollateralValue() public {
        vm.startPrank(alice);
        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A", "ipfs://Qm...");
        vm.stopPrank();

        uint256 collateralValue = lending.calculateCollateralValue(tokenId);
        uint256 expectedValue = 6400 * 1e18;
        assertEq(collateralValue, expectedValue, "Wrong collateral value");
    }

    function test_CreateLoan() public {
        vm.startPrank(alice);
        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A", "ipfs://Qm...");
        token.approve(address(lending), tokenId);

        uint256 loanId = lending.createLoan(tokenId);
        assertEq(loanId, 1, "Wrong loan ID");

        (uint256 collateralTokenId, uint256 amount, uint256 lastRepaymentTime, bool isActive) =
            lending.loans(tokenId, alice);
        assertEq(collateralTokenId, tokenId, "Wrong collateral token ID");

        assertEq(amount, 4480 * 1e18, "Wrong loan amount");
        assertEq(lastRepaymentTime, block.timestamp, "Wrong last repayment time");
        assertTrue(isActive, "Loan should be active");
        vm.stopPrank();
    }

    function test_RevertWhen_AlreadyBorrowed() public {
        vm.startPrank(alice);
        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A", "ipfs://Qm...");
        token.approve(address(lending), tokenId);

        lending.createLoan(tokenId);
        vm.expectRevert(abi.encodeWithSelector(RWALending.AlreadyBorrowed.selector, alice, tokenId));
        lending.createLoan(tokenId);
        vm.stopPrank();
    }

    function test_RevertWhen_InvalidTokenId() public {
        vm.startPrank(alice);
        uint256 invalidTokenId = 999;
        vm.expectRevert("Token does not exist");
        lending.createLoan(invalidTokenId);
        vm.stopPrank();
    }

    function test_CreateLoan_CheckBalances() public {
        vm.startPrank(alice);
        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A", "ipfs://Qm...");
        token.approve(address(lending), tokenId);

        uint256 initialStablecoinBalance = stablecoin.balanceOf(alice);
        uint256 initialTokenBalance = token.balanceOf(alice);

        lending.createLoan(tokenId);

        assertEq(stablecoin.balanceOf(alice), initialStablecoinBalance + 4480 * 1e18, "Wrong stablecoin balance");
        assertEq(token.balanceOf(alice), initialTokenBalance - 1, "Wrong token balance");
        assertEq(token.ownerOf(tokenId), address(lending), "Token should be transferred to lending");
        vm.stopPrank();
    }

    function test_RepayLoan() public {
        vm.startPrank(alice);
        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A", "ipfs://Qm...");
        token.approve(address(lending), tokenId);

        lending.createLoan(tokenId);
        uint256 initialTokenBalance = token.balanceOf(alice);

        stablecoin.approve(address(lending), 140000 * 1e18);
        lending.repayLoan(tokenId);

        assertEq(token.balanceOf(alice), initialTokenBalance + 1, "Token should be returned");
        (,,, bool isActive) = lending.loans(tokenId, alice);
        assertFalse(isActive, "Loan should be inactive");
        vm.stopPrank();
    }

    function test_RepayLoan_WithInterest() public {
        vm.startPrank(alice);
        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A", "ipfs://Qm...");
        token.approve(address(lending), tokenId);

        lending.createLoan(tokenId);

        vm.warp(block.timestamp + 30 days);

        uint256 interest = lending.calculateInterest(tokenId, alice);
        uint256 totalDue = 140000 * 1e18 + interest;

        stablecoin.approve(address(lending), totalDue);
        lending.repayLoan(tokenId);

        (,,, bool isActive) = lending.loans(tokenId, alice);
        assertFalse(isActive, "Loan should be inactive");
        vm.stopPrank();
    }

    function test_RevertWhen_NothingToRepay() public {
        vm.startPrank(alice);
        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A", "ipfs://Qm...");
        token.approve(address(lending), tokenId);

        lending.createLoan(tokenId);
        stablecoin.approve(address(lending), 140000 * 1e18);
        lending.repayLoan(tokenId);

        vm.expectRevert(RWALending.NothingToRepay.selector);
        lending.repayLoan(tokenId);
        vm.stopPrank();
    }

    function test_RevertWhen_InsufficientBalance() public {
        vm.startPrank(alice);
        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A", "ipfs://Qm...");
        token.approve(address(lending), tokenId);

        lending.createLoan(tokenId);

        stablecoin.transfer(bob, stablecoin.balanceOf(alice));

        vm.expectRevert();
        lending.repayLoan(tokenId);
        vm.stopPrank();
    }

    function test_CalculateInterest() public {
        vm.startPrank(alice);
        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A", "ipfs://Qm...");
        token.approve(address(lending), tokenId);

        lending.createLoan(tokenId);

        vm.warp(block.timestamp + 30 days);

        uint256 interest = lending.calculateInterest(tokenId, alice);
        // 140000 * 0.05 * (30/365) = 575.34
        uint256 expectedInterest = 18 * 1e18;
        assertApproxEqAbs(interest, expectedInterest, 1e18, "Wrong interest calculation");
        vm.stopPrank();
    }

    function test_CalculateInterest_ZeroTime() public {
        vm.startPrank(alice);
        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A", "ipfs://Qm...");
        token.approve(address(lending), tokenId);

        lending.createLoan(tokenId);

        uint256 interest = lending.calculateInterest(tokenId, alice);
        assertEq(interest, 0, "Interest should be 0 for zero time");
        vm.stopPrank();
    }

    function test_CalculateInterest_LongPeriod() public {
        vm.startPrank(alice);
        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A", "ipfs://Qm...");
        token.approve(address(lending), tokenId);

        lending.createLoan(tokenId);

        vm.warp(block.timestamp + 365 days);

        uint256 interest = lending.calculateInterest(tokenId, alice);

        uint256 expectedInterest = 224 * 1e18;
        assertEq(interest, expectedInterest, "Wrong interest calculation for long period");
        vm.stopPrank();
    }

    function test_GetUserLoans() public {
        vm.startPrank(alice);
        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A", "ipfs://Qm...");
        token.approve(address(lending), tokenId);

        lending.createLoan(tokenId);

        uint256[] memory loans = lending.getUserLoans(alice);
        assertEq(loans.length, 1, "Should have 1 loan");
        assertEq(loans[0], 1, "Wrong loan ID");
        vm.stopPrank();
    }

    function test_GetUserLoans_Empty() public view {
        uint256[] memory loans = lending.getUserLoans(alice);
        assertEq(loans.length, 0, "Should have no loans");
    }

    function test_GetUserLoans_Multiple() public {
        vm.startPrank(alice);
        uint256 tokenId1 = token.tokenizeGold(100, 999, "CERT1", "Vault A", "ipfs://Qm1");
        uint256 tokenId2 = token.tokenizeGold(100, 999, "CERT2", "Vault A", "ipfs://Qm2");

        token.approve(address(lending), tokenId1);
        token.approve(address(lending), tokenId2);

        lending.createLoan(tokenId1);
        lending.createLoan(tokenId2);

        uint256[] memory loans = lending.getUserLoans(alice);
        assertEq(loans.length, 2, "Should have 2 loans");
        assertEq(loans[0], 1, "Wrong first loan ID");
        assertEq(loans[1], 2, "Wrong second loan ID");
        vm.stopPrank();
    }

    function test_GetRepaymentAmount() public {
        vm.startPrank(alice);
        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A", "ipfs://Qm...");
        token.approve(address(lending), tokenId);

        lending.createLoan(tokenId);

        (uint256 totalDue, uint256 loanAmount, uint256 interest) = lending.getRepaymentAmount(tokenId, alice);
        assertEq(loanAmount, 4480 * 1e18, "Wrong loan amount");
        assertEq(interest, 0, "Interest should be 0 for zero time");
        assertEq(totalDue, 4480 * 1e18, "Total due should equal loan amount for zero time");
        vm.stopPrank();
    }

    function test_GetRepaymentAmount_WithInterest() public {
        vm.startPrank(alice);
        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A", "ipfs://Qm...");
        token.approve(address(lending), tokenId);

        lending.createLoan(tokenId);

        vm.warp(block.timestamp + 30 days);

        (uint256 totalDue, uint256 loanAmount, uint256 interest) = lending.getRepaymentAmount(tokenId, alice);
        assertEq(loanAmount, 4480 * 1e18, "Wrong loan amount");
        assertApproxEqAbs(interest, 18 * 1e18, 1e18, "Wrong interest amount");
        assertApproxEqAbs(totalDue, 4498 * 1e18, 1e18, "Wrong total due amount");
        vm.stopPrank();
    }

    function test_GetRepaymentAmount_RevertWhen_NoLoan() public {
        vm.startPrank(alice);
        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A", "ipfs://Qm...");

        vm.expectRevert(RWALending.NothingToRepay.selector);
        lending.getRepaymentAmount(tokenId, alice);
        vm.stopPrank();
    }

    function test_GetRepaymentAmount_RevertWhen_LoanRepaid() public {
        vm.startPrank(alice);
        uint256 tokenId = token.tokenizeGold(100, 999, "CERT123", "Vault A", "ipfs://Qm...");
        token.approve(address(lending), tokenId);

        lending.createLoan(tokenId);
        stablecoin.approve(address(lending), 4501 * 1e18);
        lending.repayLoan(tokenId);

        vm.expectRevert(RWALending.NothingToRepay.selector);
        lending.getRepaymentAmount(tokenId, alice);
        vm.stopPrank();
    }
}
