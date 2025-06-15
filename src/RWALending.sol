// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./RWAToken.sol";

contract RWALending is IERC721Receiver, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct LoanDetails {
        uint256 collateralTokenId;
        uint256 loanAmount;
        uint256 lastRepaymentTime;
        bool isActive;
    }

    uint256 public constant LTV_RATIO = 70;
    uint256 public constant PRECISION = 10000;
    uint256 public constant OUNCE_TO_GRAM = 31103476800000000000; // 31.1034768 grams per ounce (with 18 decimals)

    IERC20 public immutable stablecoin;
    RWAToken public immutable token;

    AggregatorV3Interface public goldPriceFeed;
    uint256 public interestRate; // in base points (1% = 100)

    uint256 public totalLoans;
    uint256 public baseInterestRate;

    mapping(uint256 => mapping(address => LoanDetails)) public loans;
    mapping(uint256 => uint256) public tokenToLoanId;
    mapping(address => uint256[]) public userLoans;

    bool public paused;

    error ContractPaused();
    error ContractNotPaused();

    event Paused(address account);
    event Unpaused(address account);

    event LoanCreated(uint256 indexed loanId, address indexed borrower, uint256 amount, uint256 collateralTokenId);
    event LoanRepaid(uint256 indexed loanId, uint256 amount);
    event InterestRateUpdated(uint256 newRate);

    error AlreadyBorrowed(address borrower, uint256 tokenId);
    error InvalidValuation();
    error SlippageToleranceExceeded();
    error PriceFeedDdosed();
    error InvalidRoundId();
    error StalePriceFeed();
    error NothingToRepay();
    error OnlyRWATokenSupported();

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ContractNotPaused();
        _;
    }

    constructor(address _stablecoin, address _token, address _goldPriceFeed, uint256 _interestRate)
        Ownable(msg.sender)
    {
        stablecoin = IERC20(_stablecoin);
        token = RWAToken(_token);
        goldPriceFeed = AggregatorV3Interface(_goldPriceFeed);
        interestRate = _interestRate;
    }

    /**
     * @dev Create a new loan
     */
    function createLoan(uint256 _tokenId) external nonReentrant whenNotPaused returns (uint256) {
        if (loans[_tokenId][msg.sender].isActive) revert AlreadyBorrowed(msg.sender, _tokenId);

        uint256 collateralValue = calculateCollateralValue(_tokenId);
        if (collateralValue == 0) revert InvalidValuation();

        uint256 loanAmount = (collateralValue * LTV_RATIO) / 100;

        uint256 loanId = ++totalLoans;
        loans[_tokenId][msg.sender] = LoanDetails({
            collateralTokenId: _tokenId,
            loanAmount: loanAmount,
            lastRepaymentTime: block.timestamp,
            isActive: true
        });

        tokenToLoanId[_tokenId] = loanId;
        userLoans[msg.sender].push(loanId);

        token.transferFrom(msg.sender, address(this), _tokenId);

        stablecoin.safeTransfer(msg.sender, loanAmount);

        emit LoanCreated(loanId, msg.sender, loanAmount, _tokenId);
        return loanId;
    }

    /**
     * @dev Repay a loan
     */
    function repayLoan(uint256 _tokenId) external nonReentrant whenNotPaused {
        LoanDetails storage loan = loans[_tokenId][msg.sender];
        if (!loan.isActive) revert NothingToRepay();

        uint256 interest = calculateInterest(_tokenId, msg.sender);
        uint256 totalDue = loan.loanAmount + interest;

        stablecoin.safeTransferFrom(msg.sender, address(this), totalDue);

        token.transferFrom(address(this), msg.sender, loan.collateralTokenId);

        loan.isActive = false;
        emit LoanRepaid(_tokenId, totalDue);
    }

    /**
     * @dev Update the base interest rate
     */
    function updateBaseInterestRate(uint256 _newRate) external onlyOwner {
        baseInterestRate = _newRate;
        emit InterestRateUpdated(_newRate);
    }

    /**
     * @dev Calculate the collateral value
     */
    function calculateCollateralValue(uint256 _tokenId) public view returns (uint256) {
        RWAToken.GoldAsset memory asset = token.getGoldAsset(_tokenId);
        require(asset.isActive, "Asset is not active");
        AggregatorV3Interface priceFeed = AggregatorV3Interface(goldPriceFeed);
        (, int256 price,,,) = priceFeed.latestRoundData();

        uint256 pricePerGram = (uint256(price) * 1e10) / OUNCE_TO_GRAM;

        uint256 value = (asset.weight * 1e18) * pricePerGram;
        return value;
    }

    /**
     * @dev Calculate the interest
     */
    function calculateInterest(uint256 _tokenId, address _borrower) public view returns (uint256) {
        LoanDetails storage loan = loans[_tokenId][_borrower];
        if (!loan.isActive) return 0;

        uint256 timeElapsed = block.timestamp - loan.lastRepaymentTime;

        return (loan.loanAmount * interestRate * timeElapsed) / (365 days * PRECISION);
    }

    /**
     * @dev Update the interest rate
     */
    function updateInterestRate(uint256 _newRate) external onlyOwner {
        interestRate = _newRate;
        emit InterestRateUpdated(_newRate);
    }

    /**
     * @dev Update the gold price feed
     */
    function updatePriceFeed(address _newFeed) external onlyOwner {
        goldPriceFeed = AggregatorV3Interface(_newFeed);
    }

    /**
     * @dev Get the user's loans
     */
    function getUserLoans(address _user) external view returns (uint256[] memory) {
        return userLoans[_user];
    }

    /**
     * @dev Get the total amount needed to repay the loan
     * @param _tokenId ID of the collateral token
     * @param _borrower Address of the borrower
     * @return totalDue Total amount to repay (loan amount + interest)
     * @return loanAmount Original loan amount
     * @return interest Current interest amount
     */
    function getRepaymentAmount(uint256 _tokenId, address _borrower)
        external
        view
        returns (uint256 totalDue, uint256 loanAmount, uint256 interest)
    {
        LoanDetails storage loan = loans[_tokenId][_borrower];
        if (!loan.isActive) revert NothingToRepay();

        interest = calculateInterest(_tokenId, _borrower);
        loanAmount = loan.loanAmount;
        totalDue = loanAmount + interest;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external view returns (bytes4) {
        if (msg.sender != address(token)) {
            revert OnlyRWATokenSupported();
        }
        return IERC721Receiver.onERC721Received.selector;
    }

    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }
}
