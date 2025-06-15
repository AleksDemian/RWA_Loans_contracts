# RWA Platform: Real World Assets Tokenization and Lending

> MVP developed for EthKyiv 2025 Hackathon

RWA Platform is a decentralized platform for tokenizing real-world assets and lending against tokenized assets. The platform enables:
1. Tokenizing real assets into NFTs
2. Obtaining loans against tokenized assets
3. Automatically calculating collateral value based on real-time prices from Oracles
4. Securely storing and transferring tokenized assets

> **Planned Features**:
> - Automatic liquidation of undercollateralized positions
> - Integration with DeFi lending protocols for liquidity sources

> **Note**: The current version (MVP) focuses on gold tokenization as an implementation example. The platform is designed to be extensible to other types of RWA.

## Architecture

### Smart Contracts

1. **RWAToken.sol**
   - ERC721 token for representing real-world assets
   - Stores metadata about physical assets
   - Enables asset tokenization and token management
   - Ready for extension to support various asset types

2. **RWALending.sol**
   - Contract for lending against tokenized assets
   - Integration with oracles for asset price feeds
   - LTV (Loan-to-Value) and interest calculations
   - Collateral and loan repayment management

> **Planned Features**:
> - Automatic liquidation mechanism
> - DeFi protocol integration for liquidity

### Key Parameters

- LTV (Loan-to-Value): 70%
- Annual Interest Rate: 5%
- Calculation Precision: 18 decimals

> **Planned Parameters**:
> - Liquidation Threshold: 85% LTV
> - Liquidation Penalty: 5%

## Workflow

### 1. Asset Tokenization

```solidity
function tokenizeGold(
    uint256 _weight,      // weight/quantity
    uint256 _purity,      // quality/characteristics
    string _certificateId, // certificate ID
    string _vaultLocation, // storage location
    string _tokenURI      // metadata URI
) returns (uint256)
```

### 2. Loan Creation

```solidity
function createLoan(uint256 _tokenId) returns (uint256)
```
- Collateral value verification
- Loan amount calculation (70% of value)
- Collateral token transfer
- Stablecoin issuance

### 3. Loan Repayment

```solidity
function repayLoan(uint256 _tokenId)
```
- Interest calculation
- Stablecoin acceptance
- Collateral token return

> **Planned Workflow**:
> ### 4. Automatic Liquidation
> ```solidity
> function liquidate(uint256 _tokenId, address _borrower)
> ```
> - Health factor monitoring
> - Automatic liquidation when threshold is reached
> - Collateral auction mechanism
> - Debt repayment from liquidation proceeds

## Security

1. **Reentrancy Protection**
   - ReentrancyGuard implementation
   - Safe token transfers

2. **Risk Management**
   - LTV limitations
   - Price feed staleness checks
   - Contract pause mechanism

> **Planned Security Features**:
> - Liquidation thresholds
> - Oracle price deviation checks
> - Liquidation role management

## Development

### Installation

```bash
git clone https://github.com/your-username/rwa-platform.git
cd rwa-platform
forge install
```

### Testing

```bash
forge test
```

### Deployment

```bash
forge script script/Deploy.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
```

## Roadmap

1. **Phase 1 (MVP)**
   - Gold tokenization
   - Basic lending functionality
   - Chainlink integration

2. **Phase 2**
   - Support for additional RWA types
   - Advanced asset valuation mechanisms
   - Additional loan types
   - Integration with Aave/Compound for liquidity
   - Basic liquidation mechanism

3. **Phase 3**
   - Decentralized asset valuation
   - Collateral insurance
   - Secondary market
   - Advanced liquidation system
   - Cross-protocol liquidity optimization

## License

MIT
