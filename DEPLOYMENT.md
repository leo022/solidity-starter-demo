# Deployment & Testing Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Development Setup](#development-setup)
3. [Testing with Remix IDE](#testing-with-remix-ide)
4. [Hardhat Setup & Testing](#hardhat-setup--testing)
5. [Testnet Deployment](#testnet-deployment)
6. [Frontend Integration](#frontend-integration)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

1. **MetaMask Wallet**
   - Download: [metamask.io](https://metamask.io)
   - Browser extension for Chrome/Firefox/Brave
   - Used for account management and transaction signing

2. **Testnet ETH (Free)**
   - Sepolia Faucet: [sepoliafaucet.com](https://sepoliafaucet.com)
   - Alternative: [faucets.chain.link](https://faucets.chain.link)
   - Needed for deploying and testing on testnets

3. **Development Environment (Choose One)**
   - **Remix IDE**: No installation needed (web-based)
   - **Hardhat**: Requires Node.js installation
   - **Foundry**: Fast Rust-based framework

### Recommended Knowledge

- Basic understanding of blockchain concepts
- Familiarity with Ethereum addresses and transactions
- Basic JavaScript (for Hardhat/frontend integration)

---

## Development Setup

### Option 1: No Setup Required (Remix IDE)

Remix is a browser-based IDE - perfect for beginners!

**Advantages:**
- Zero installation required
- Built-in Solidity compiler
- Deploy to testnets easily
- Great for learning

**Go to:** [remix.ethereum.org](https://remix.ethereum.org)

### Option 2: Local Development (Hardhat)

For more advanced development and testing.

**Installation:**

```bash
# Create project directory
mkdir crowdfunding-platform
cd crowdfunding-platform

# Initialize Node.js project
npm init -y

# Install Hardhat
npm install --save-dev hardhat

# Initialize Hardhat project
npx hardhat init
# Select: "Create a JavaScript project"

# Install dependencies
npm install --save-dev @nomicfoundation/hardhat-toolbox
npm install --save-dev @openzeppelin/contracts

# Install testing libraries
npm install --save-dev chai @nomicfoundation/hardhat-chai-matchers
```

**Project Structure:**
```
crowdfunding-platform/
├── contracts/
│   └── CrowdfundingPlatform.sol
├── test/
│   └── CrowdfundingPlatform.test.js
├── scripts/
│   └── deploy.js
├── hardhat.config.js
└── package.json
```

---

## Testing with Remix IDE

### Step-by-Step Tutorial

#### 1. Open Remix IDE

Visit [remix.ethereum.org](https://remix.ethereum.org)

#### 2. Create Contract File

1. In **File Explorer** (left panel), click **New File** icon
2. Name it: `CrowdfundingPlatform.sol`
3. Copy and paste the contract code from `CrowdfundingPlatform.sol`

#### 3. Compile the Contract

1. Click **Solidity Compiler** icon (left sidebar)
2. Select compiler version: `0.8.0` or higher
3. Click **Compile CrowdfundingPlatform.sol**
4. Green checkmark = successful compilation
5. Red X = compilation errors (check error messages)

**Common Compilation Errors:**
```
Error: Source not found
→ Solution: Ensure SPDX license identifier is present

Error: Parser error: Expected pragma
→ Solution: Check pragma directive syntax
```

#### 4. Deploy the Contract

1. Click **Deploy & Run Transactions** icon (left sidebar)
2. **Environment:** Select "Remix VM (Shanghai)" for local testing
   - Remix VM: Simulated blockchain in browser (fastest)
   - Injected Provider: Uses MetaMask (for testnet deployment)
3. **Contract:** Select "CrowdfundingPlatform"
4. Click **Deploy** button
5. Deployed contract appears under "Deployed Contracts"

#### 5. Interact with Contract

Expand deployed contract to see all functions.

**Read Functions (Blue - Free):**
- `campaignCounter`
- `platformOwner`
- `getCampaign`
- `getContribution`
- etc.

**Write Functions (Orange - Costs Gas):**
- `createCampaign`
- `donate`
- `withdrawFunds`
- etc.

---

### Testing Scenarios in Remix

#### Scenario 1: Create a Campaign

1. **Expand `createCampaign` function**
2. **Enter parameters:**
   ```
   _title: "Help Build Community Center"
   _description: "Raising funds to build a community center in our neighborhood"
   _goalAmount: 5000000000000000000  (5 ETH in wei)
   _durationDays: 30
   ```
3. **Click "transact"**
4. **Check console** for transaction receipt
5. **Verify campaign created:**
   - Call `campaignCounter` → Should return `1`
   - Call `getCampaign(0)` → See campaign details

**Helper: Wei Converter**
- 1 ETH = 1,000,000,000,000,000,000 wei (10^18)
- Use [eth-converter.com](https://eth-converter.com) for conversions

#### Scenario 2: Donate to Campaign

1. **Switch Account:**
   - In "Account" dropdown (top), select different address
   - Simulates different user

2. **Set Value to Send:**
   - Above function list, find "VALUE" input
   - Enter: `1` and select `ether` from dropdown
   - This sends 1 ETH with transaction

3. **Call `donate` function:**
   ```
   _campaignId: 0
   ```

4. **Verify donation:**
   - Call `getCampaign(0)` → Check `amountRaised`
   - Call `getContribution(0, YOUR_ADDRESS)` → Check your contribution

#### Scenario 3: Multiple Donations

Repeat Scenario 2 with different accounts and amounts:

```
Account 1: Donate 1 ETH
Account 2: Donate 2 ETH
Account 3: Donate 2.5 ETH
Total: 5.5 ETH (goal met!)
```

#### Scenario 4: Check Campaign Status

```javascript
// Call isCampaignSuccessful(0)
// Returns: false (deadline not reached yet in Remix VM)

// Call getTimeRemaining(0)
// Returns: ~2592000 (seconds remaining ≈ 30 days)
```

**Note:** Remix VM simulates time, so deadline won't naturally pass. For time-based testing, use Hardhat.

#### Scenario 5: Withdraw Funds (Successful Campaign)

**Problem:** Can't fast-forward time in Remix VM easily.

**Workaround:**
1. Create campaign with `_durationDays: 0` (will fail validation)
2. OR modify contract temporarily for testing:
   ```solidity
   // Temporary testing change
   uint256 deadline = block.timestamp + 1;  // 1 second
   ```
3. OR use Hardhat (recommended)

**If deadline passed:**
1. Switch to campaign creator account
2. Call `withdrawFunds(0)`
3. Check account balance increased
4. Call `totalPlatformFees` → Verify 2% fee collected

#### Scenario 6: Get Refund (Failed Campaign)

1. Create new campaign: Goal 10 ETH, 30 days
2. Donate only 3 ETH (below goal)
3. Wait for deadline (or modify contract)
4. Switch to donor account
5. Call `getRefund(0)`
6. Check account balance increased

---

### Testing Edge Cases

#### Test 1: Double Withdrawal Prevention

```
1. Create and fund successful campaign
2. Call withdrawFunds(0)
3. Try calling withdrawFunds(0) again
Expected: Transaction reverts with "Funds already withdrawn"
```

#### Test 2: Donate After Deadline

```
1. Create campaign with 0-day duration (or wait)
2. Try to donate after deadline
Expected: Transaction reverts with "Campaign has ended"
```

#### Test 3: Withdraw Before Deadline

```
1. Create funded campaign (goal met)
2. Try withdrawFunds before deadline
Expected: Transaction reverts with "Campaign still ongoing"
```

#### Test 4: Access Control

```
1. Create campaign with Account A
2. Switch to Account B
3. Try to call withdrawFunds as Account B
Expected: Transaction reverts with "Only campaign creator can call this"
```

#### Test 5: Zero Amount Validation

```
1. Create campaign with _goalAmount: 0
Expected: Transaction reverts with "Goal amount must be greater than 0"
```

---

## Hardhat Setup & Testing

### Configuration

**hardhat.config.js:**

```javascript
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: "0.8.19",
  networks: {
    hardhat: {
      chainId: 1337
    },
    sepolia: {
      url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [PRIVATE_KEY]
    }
  }
};
```

### Writing Tests

**test/CrowdfundingPlatform.test.js:**

```javascript
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("CrowdfundingPlatform", function () {
  let platform;
  let owner;
  let creator;
  let donor1;
  let donor2;

  beforeEach(async function () {
    // Get signers
    [owner, creator, donor1, donor2] = await ethers.getSigners();

    // Deploy contract
    const Platform = await ethers.getContractFactory("CrowdfundingPlatform");
    platform = await Platform.deploy();
    await platform.waitForDeployment();
  });

  describe("Campaign Creation", function () {
    it("Should create a campaign successfully", async function () {
      await platform.connect(creator).createCampaign(
        "Test Campaign",
        "Description",
        ethers.parseEther("5"),
        30
      );

      expect(await platform.campaignCounter()).to.equal(1);

      const campaign = await platform.getCampaign(0);
      expect(campaign.title).to.equal("Test Campaign");
      expect(campaign.goalAmount).to.equal(ethers.parseEther("5"));
    });

    it("Should revert if goal amount is 0", async function () {
      await expect(
        platform.connect(creator).createCampaign(
          "Test",
          "Description",
          0,
          30
        )
      ).to.be.revertedWith("Goal amount must be greater than 0");
    });

    it("Should emit CampaignCreated event", async function () {
      await expect(
        platform.connect(creator).createCampaign(
          "Test Campaign",
          "Description",
          ethers.parseEther("5"),
          30
        )
      )
        .to.emit(platform, "CampaignCreated")
        .withArgs(0, creator.address, "Test Campaign", ethers.parseEther("5"));
    });
  });

  describe("Donations", function () {
    beforeEach(async function () {
      // Create campaign before each test
      await platform.connect(creator).createCampaign(
        "Test Campaign",
        "Description",
        ethers.parseEther("5"),
        30
      );
    });

    it("Should accept donations", async function () {
      await platform.connect(donor1).donate(0, {
        value: ethers.parseEther("1")
      });

      const campaign = await platform.getCampaign(0);
      expect(campaign.amountRaised).to.equal(ethers.parseEther("1"));

      const contribution = await platform.getContribution(0, donor1.address);
      expect(contribution).to.equal(ethers.parseEther("1"));
    });

    it("Should track multiple donations", async function () {
      await platform.connect(donor1).donate(0, {
        value: ethers.parseEther("2")
      });
      await platform.connect(donor2).donate(0, {
        value: ethers.parseEther("3")
      });

      const campaign = await platform.getCampaign(0);
      expect(campaign.amountRaised).to.equal(ethers.parseEther("5"));
    });

    it("Should revert if campaign has ended", async function () {
      // Fast-forward time past deadline
      await time.increase(31 * 24 * 60 * 60); // 31 days

      await expect(
        platform.connect(donor1).donate(0, {
          value: ethers.parseEther("1")
        })
      ).to.be.revertedWith("Campaign has ended");
    });

    it("Should emit DonationReceived event", async function () {
      await expect(
        platform.connect(donor1).donate(0, {
          value: ethers.parseEther("1")
        })
      )
        .to.emit(platform, "DonationReceived")
        .withArgs(0, donor1.address, ethers.parseEther("1"));
    });
  });

  describe("Fund Withdrawal", function () {
    beforeEach(async function () {
      // Create campaign
      await platform.connect(creator).createCampaign(
        "Test Campaign",
        "Description",
        ethers.parseEther("5"),
        30
      );

      // Fully fund campaign
      await platform.connect(donor1).donate(0, {
        value: ethers.parseEther("6")
      });
    });

    it("Should allow creator to withdraw after successful campaign", async function () {
      // Fast-forward past deadline
      await time.increase(31 * 24 * 60 * 60);

      const initialBalance = await ethers.provider.getBalance(creator.address);

      const tx = await platform.connect(creator).withdrawFunds(0);
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;

      const finalBalance = await ethers.provider.getBalance(creator.address);

      // Calculate expected amount (6 ETH - 2% fee = 5.88 ETH)
      const expectedAmount = ethers.parseEther("5.88");

      expect(finalBalance - initialBalance + gasUsed).to.be.closeTo(
        expectedAmount,
        ethers.parseEther("0.01") // Allow small variance
      );
    });

    it("Should revert if called before deadline", async function () {
      await expect(
        platform.connect(creator).withdrawFunds(0)
      ).to.be.revertedWith("Campaign still ongoing");
    });

    it("Should revert if goal not reached", async function () {
      // Create underfunded campaign
      await platform.connect(creator).createCampaign(
        "Test 2",
        "Description",
        ethers.parseEther("10"),
        30
      );

      await platform.connect(donor1).donate(1, {
        value: ethers.parseEther("3")
      });

      await time.increase(31 * 24 * 60 * 60);

      await expect(
        platform.connect(creator).withdrawFunds(1)
      ).to.be.revertedWith("Goal not reached");
    });

    it("Should prevent double withdrawal", async function () {
      await time.increase(31 * 24 * 60 * 60);

      await platform.connect(creator).withdrawFunds(0);

      await expect(
        platform.connect(creator).withdrawFunds(0)
      ).to.be.revertedWith("Funds already withdrawn");
    });

    it("Should revert if called by non-creator", async function () {
      await time.increase(31 * 24 * 60 * 60);

      await expect(
        platform.connect(donor1).withdrawFunds(0)
      ).to.be.revertedWith("Only campaign creator can call this");
    });

    it("Should accumulate platform fees correctly", async function () {
      await time.increase(31 * 24 * 60 * 60);
      await platform.connect(creator).withdrawFunds(0);

      const fees = await platform.totalPlatformFees();
      // 2% of 6 ETH = 0.12 ETH
      expect(fees).to.equal(ethers.parseEther("0.12"));
    });
  });

  describe("Refunds", function () {
    beforeEach(async function () {
      // Create underfunded campaign
      await platform.connect(creator).createCampaign(
        "Test Campaign",
        "Description",
        ethers.parseEther("10"),
        30
      );

      await platform.connect(donor1).donate(0, {
        value: ethers.parseEther("3")
      });
    });

    it("Should allow refund after failed campaign", async function () {
      await time.increase(31 * 24 * 60 * 60);

      const initialBalance = await ethers.provider.getBalance(donor1.address);

      const tx = await platform.connect(donor1).getRefund(0);
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;

      const finalBalance = await ethers.provider.getBalance(donor1.address);

      expect(finalBalance - initialBalance + gasUsed).to.equal(
        ethers.parseEther("3")
      );
    });

    it("Should revert if campaign was successful", async function () {
      // Create successful campaign
      await platform.connect(creator).createCampaign(
        "Test 2",
        "Description",
        ethers.parseEther("5"),
        30
      );

      await platform.connect(donor1).donate(1, {
        value: ethers.parseEther("6")
      });

      await time.increase(31 * 24 * 60 * 60);

      await expect(
        platform.connect(donor1).getRefund(1)
      ).to.be.revertedWith("Campaign was successful");
    });

    it("Should revert if no contribution found", async function () {
      await time.increase(31 * 24 * 60 * 60);

      await expect(
        platform.connect(donor2).getRefund(0)
      ).to.be.revertedWith("No contribution found");
    });

    it("Should prevent double refund", async function () {
      await time.increase(31 * 24 * 60 * 60);

      await platform.connect(donor1).getRefund(0);

      await expect(
        platform.connect(donor1).getRefund(0)
      ).to.be.revertedWith("No contribution found");
    });
  });

  describe("Campaign Cancellation", function () {
    beforeEach(async function () {
      await platform.connect(creator).createCampaign(
        "Test Campaign",
        "Description",
        ethers.parseEther("5"),
        30
      );
    });

    it("Should allow creator to cancel campaign", async function () {
      await platform.connect(creator).cancelCampaign(0);

      const campaign = await platform.getCampaign(0);
      expect(campaign.active).to.equal(false);
    });

    it("Should revert if called by non-creator", async function () {
      await expect(
        platform.connect(donor1).cancelCampaign(0)
      ).to.be.revertedWith("Only campaign creator can call this");
    });

    it("Should revert if campaign already ended", async function () {
      await time.increase(31 * 24 * 60 * 60);

      await expect(
        platform.connect(creator).cancelCampaign(0)
      ).to.be.revertedWith("Campaign already ended");
    });
  });

  describe("Platform Fees", function () {
    it("Should allow owner to withdraw platform fees", async function () {
      // Create and complete successful campaign
      await platform.connect(creator).createCampaign(
        "Test Campaign",
        "Description",
        ethers.parseEther("5"),
        30
      );

      await platform.connect(donor1).donate(0, {
        value: ethers.parseEther("6")
      });

      await time.increase(31 * 24 * 60 * 60);
      await platform.connect(creator).withdrawFunds(0);

      const initialBalance = await ethers.provider.getBalance(owner.address);

      const tx = await platform.connect(owner).withdrawPlatformFees();
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;

      const finalBalance = await ethers.provider.getBalance(owner.address);

      expect(finalBalance - initialBalance + gasUsed).to.equal(
        ethers.parseEther("0.12") // 2% of 6 ETH
      );
    });

    it("Should revert if called by non-owner", async function () {
      await expect(
        platform.connect(donor1).withdrawPlatformFees()
      ).to.be.revertedWith("Only platform owner can call this");
    });
  });
});
```

### Running Tests

```bash
# Run all tests
npx hardhat test

# Run specific test file
npx hardhat test test/CrowdfundingPlatform.test.js

# Run with gas reporting
REPORT_GAS=true npx hardhat test

# Run with coverage
npx hardhat coverage
```

**Expected Output:**
```
CrowdfundingPlatform
  Campaign Creation
    ✓ Should create a campaign successfully
    ✓ Should revert if goal amount is 0
    ✓ Should emit CampaignCreated event
  Donations
    ✓ Should accept donations
    ✓ Should track multiple donations
    ...

  45 passing (2s)
```

---

## Testnet Deployment

### Step 1: Get Testnet ETH

**Sepolia Testnet (Recommended):**
1. Go to [sepoliafaucet.com](https://sepoliafaucet.com)
2. Connect MetaMask
3. Request testnet ETH (free)
4. Wait 1-2 minutes for delivery

### Step 2: Setup Infura/Alchemy

**Infura (RPC Provider):**
1. Sign up at [infura.io](https://infura.io)
2. Create new project
3. Copy API key
4. Use endpoint: `https://sepolia.infura.io/v3/YOUR_API_KEY`

**Alternative: Alchemy**
1. Sign up at [alchemy.com](https://alchemy.com)
2. Create app (Sepolia network)
3. Copy HTTP endpoint

### Step 3: Deploy with Remix

1. **Switch Network in MetaMask:**
   - Click network dropdown
   - Select "Sepolia Test Network"

2. **In Remix:**
   - Go to **Deploy & Run Transactions**
   - Environment: Select **"Injected Provider - MetaMask"**
   - Account: Verify correct account connected
   - Click **Deploy**
   - Confirm transaction in MetaMask

3. **Verify Deployment:**
   - Transaction hash appears in Remix console
   - View on Etherscan: `https://sepolia.etherscan.io/tx/{TX_HASH}`
   - Copy contract address

### Step 4: Deploy with Hardhat

**scripts/deploy.js:**

```javascript
const hre = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contract with account:", deployer.address);
  console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

  const Platform = await ethers.getContractFactory("CrowdfundingPlatform");
  const platform = await Platform.deploy();

  await platform.waitForDeployment();

  console.log("CrowdfundingPlatform deployed to:", await platform.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

**Deploy:**

```bash
npx hardhat run scripts/deploy.js --network sepolia
```

### Step 5: Verify Contract on Etherscan

**Manual Verification:**
1. Go to contract on Etherscan
2. Click "Contract" tab
3. Click "Verify and Publish"
4. Select compiler version, license
5. Paste contract code
6. Submit

**Automated Verification (Hardhat):**

```bash
npm install --save-dev @nomiclabs/hardhat-etherscan

# In hardhat.config.js add:
etherscan: {
  apiKey: YOUR_ETHERSCAN_API_KEY
}

# Verify
npx hardhat verify --network sepolia CONTRACT_ADDRESS
```

---

## Frontend Integration

### Basic Web3.js Example

```javascript
// Install: npm install web3

const Web3 = require('web3');
const web3 = new Web3(window.ethereum);

// Contract ABI (get from compilation)
const abi = [ /* Contract ABI */ ];
const contractAddress = "0x...";

const contract = new web3.eth.Contract(abi, contractAddress);

// Connect wallet
async function connectWallet() {
  const accounts = await window.ethereum.request({
    method: 'eth_requestAccounts'
  });
  return accounts[0];
}

// Create campaign
async function createCampaign(title, description, goal, days) {
  const account = await connectWallet();

  await contract.methods.createCampaign(
    title,
    description,
    web3.utils.toWei(goal, 'ether'),
    days
  ).send({ from: account });
}

// Donate to campaign
async function donate(campaignId, amount) {
  const account = await connectWallet();

  await contract.methods.donate(campaignId).send({
    from: account,
    value: web3.utils.toWei(amount, 'ether')
  });
}

// Get campaign details
async function getCampaign(campaignId) {
  const campaign = await contract.methods.getCampaign(campaignId).call();
  return {
    creator: campaign.creator,
    title: campaign.title,
    description: campaign.description,
    goalAmount: web3.utils.fromWei(campaign.goalAmount, 'ether'),
    amountRaised: web3.utils.fromWei(campaign.amountRaised, 'ether'),
    deadline: new Date(campaign.deadline * 1000),
    active: campaign.active
  };
}
```

### Basic Ethers.js Example

```javascript
// Install: npm install ethers

const { ethers } = require('ethers');

// Connect to provider
const provider = new ethers.BrowserProvider(window.ethereum);

// Contract setup
const abi = [ /* Contract ABI */ ];
const contractAddress = "0x...";

async function getContract() {
  const signer = await provider.getSigner();
  return new ethers.Contract(contractAddress, abi, signer);
}

// Create campaign
async function createCampaign(title, description, goal, days) {
  const contract = await getContract();

  const tx = await contract.createCampaign(
    title,
    description,
    ethers.parseEther(goal),
    days
  );

  await tx.wait(); // Wait for confirmation
  console.log("Campaign created:", tx.hash);
}

// Listen for events
async function listenForDonations() {
  const contract = await getContract();

  contract.on("DonationReceived", (campaignId, donor, amount, event) => {
    console.log(`Campaign ${campaignId} received ${ethers.formatEther(amount)} ETH from ${donor}`);
  });
}
```

---

## Troubleshooting

### Common Deployment Issues

#### Issue 1: "Insufficient funds"

**Error:** `Error: insufficient funds for gas * price + value`

**Solutions:**
- Check account balance: `eth.getBalance(YOUR_ADDRESS)`
- Get more testnet ETH from faucet
- Reduce gas price or value sent

#### Issue 2: "Nonce too low"

**Error:** `Error: nonce has already been used`

**Solutions:**
- Reset MetaMask account: Settings → Advanced → Reset Account
- Wait for pending transactions to complete
- Check transaction history on Etherscan

#### Issue 3: "Contract creation failed"

**Error:** Transaction reverts during deployment

**Solutions:**
- Check constructor logic (our contract has simple constructor)
- Ensure sufficient gas limit
- Verify Solidity version compatibility

#### Issue 4: "Invalid address"

**Error:** When calling functions

**Solutions:**
- Ensure contract deployed successfully
- Copy full address (0x... with 40 characters)
- Verify correct network selected

### Common Testing Issues

#### Issue 1: "Campaign already exists" in tests

**Cause:** State persists between tests

**Solution:** Use `beforeEach` to reset state:
```javascript
beforeEach(async function () {
  const Platform = await ethers.getContractFactory("CrowdfundingPlatform");
  platform = await Platform.deploy();
});
```

#### Issue 2: Time-dependent tests failing

**Cause:** Can't control `block.timestamp` easily

**Solution:** Use Hardhat's `time` helpers:
```javascript
const { time } = require("@nomicfoundation/hardhat-network-helpers");
await time.increase(31 * 24 * 60 * 60); // Fast-forward 31 days
```

#### Issue 3: "Cannot read properties of undefined"

**Cause:** Contract not deployed or wrong reference

**Solution:**
```javascript
// Ensure await
const platform = await Platform.deploy();
await platform.waitForDeployment();

// Use correct method
const address = await platform.getAddress(); // Not platform.address
```

### Gas Optimization Tips

**Reduce Gas Costs:**

1. **Pack storage variables:**
```solidity
// Bad (2 slots)
bool active;
uint256 amount;
bool withdrawn;

// Good (2 slots)
bool active;
bool withdrawn;
uint256 amount;
```

2. **Use events instead of storage for historical data**

3. **Batch operations where possible**

4. **Use `calldata` instead of `memory` for external function parameters (saves gas but less flexible)**

5. **Avoid loops in state-changing functions**

---

## Next Steps

1. **Deploy to testnet** and test with real transactions
2. **Build a frontend** to interact with your contract
3. **Conduct security audit** before mainnet deployment
4. **Implement additional features:**
   - Campaign categories
   - Milestone-based funding
   - Token rewards for donors
   - Multi-currency support

5. **Learn advanced topics:**
   - Upgradeable contracts
   - Layer 2 deployment
   - Oracle integration
   - DAO governance

---

## Additional Resources

**Development Tools:**
- [Remix IDE](https://remix.ethereum.org)
- [Hardhat Documentation](https://hardhat.org/docs)
- [Foundry Book](https://book.getfoundry.sh)

**Testing:**
- [Hardhat Testing Guide](https://hardhat.org/hardhat-runner/docs/guides/test-contracts)
- [Waffle Matchers](https://ethereum-waffle.readthedocs.io/en/latest/matchers.html)

**Frontend:**
- [Web3.js Documentation](https://web3js.readthedocs.io)
- [Ethers.js Documentation](https://docs.ethers.org)
- [RainbowKit](https://www.rainbowkit.com/) - Wallet connection UI

**Best Practices:**
- [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)
- [Consensys Best Practices](https://consensys.github.io/smart-contract-best-practices/)

---

**Happy Building!**

For questions or issues, consult the Ethereum Stack Exchange or Solidity documentation.
