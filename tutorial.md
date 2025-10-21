---
title: Crowdfunding Platform Smart Contract Tutorial
author: TC
date: '2025-10-16'
---

# Crowdfunding Platform Smart Contract Tutorial

## Table of Contents
1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Contract Overview](#contract-overview)
4. [Core Concepts](#core-concepts)
5. [Architecture Deep Dive](#architecture-deep-dive)
6. [Key Features Explained](#key-features-explained)
7. [Security Mechanisms](#security-mechanisms)
8. [How to Use the Contract](#how-to-use-the-contract)
9. [Advanced Topics](#advanced-topics)
10. [Best Practices and Patterns](#best-practices-and-patterns)

---

## Introduction

This tutorial will guide you through understanding a professional-grade crowdfunding platform smart contract built with Solidity. This contract demonstrates advanced Solidity concepts including access control, state management, security patterns, and complex data structures.

**What you'll learn:**
- How to structure a real-world smart contract
- Advanced Solidity patterns and best practices
- Security mechanisms (reentrancy protection, access control, pause functionality)
- State management with mappings and structs
- Event-driven architecture for frontend integration

---

## Prerequisites

Before diving into this tutorial, you should understand:

### Basic Blockchain Concepts
- What is Ethereum and how it works
- Understanding of wallets and addresses
- Gas fees and transactions
- Wei vs Ether (1 ETH = 10^18 wei)

### Solidity Fundamentals
- Data types (uint256, address, bool, string)
- Functions and modifiers
- Visibility modifiers (public, private, external, internal)
- Storage vs Memory vs Calldata

### Recommended Knowledge
- Basic understanding of mappings and arrays
- Events and how they work
- The concept of gas optimization

---

## Contract Overview

### What Does This Contract Do?

The `CrowdfundingPlatform` contract allows users to:

1. **Create Campaigns**: Anyone can create a fundraising campaign with a goal and deadline
2. **Donate to Campaigns**: Users can contribute ETH to active campaigns
3. **Withdraw Funds**: Campaign creators can withdraw funds if goals are met
4. **Request Refunds**: Donors can get refunds if campaigns fail
5. **Track Milestones**: Campaigns can have milestones that donors approve
6. **Platform Administration**: Owner can manage platform fees and security

### High-Level Architecture

```
┌─────────────────────────────────────────────────┐
│         CrowdfundingPlatform Contract           │
├─────────────────────────────────────────────────┤
│  Campaign Creation  │  Donations  │  Withdrawals│
│  Refunds           │  Milestones │  Admin      │
├─────────────────────────────────────────────────┤
│  Security: Reentrancy Guard, Access Control    │
│  State: Mappings, Structs, Events              │
└─────────────────────────────────────────────────┘
```

---

## Core Concepts

### 1. Contract State Variables

State variables are stored permanently on the blockchain. Let's break down the key ones:

#### Campaign Counter
```solidity
uint256 public campaignCounter;
```
- Tracks the total number of campaigns created
- Each new campaign gets an ID equal to the current counter
- Starts at 0 and increments with each campaign

#### Storage Mappings

**Campaigns Mapping** (`CrowdfundingPlatform.sol:54`)
```solidity
mapping(uint256 => Campaign) public campaigns;
```
- Maps campaign ID → Campaign data
- The core storage for all campaign information

**Contributions Mapping** (`CrowdfundingPlatform.sol:55`)
```solidity
mapping(uint256 => mapping(address => uint256)) public contributions;
```
- Nested mapping: Campaign ID → Donor Address → Amount donated
- Tracks how much each person donated to each campaign

**Campaign Donors** (`CrowdfundingPlatform.sol:56`)
```solidity
mapping(uint256 => address[]) private campaignDonors;
```
- Maps Campaign ID → Array of donor addresses
- Used to iterate through all donors (e.g., for refunds)

### 2. Data Structures

#### Campaign Struct (`CrowdfundingPlatform.sol:29-42`)

```solidity
struct Campaign {
    address payable creator;      // Who created the campaign
    string title;                 // Campaign name
    string description;           // Details about the campaign
    uint256 goalAmount;           // Target amount in wei
    uint256 minContribution;      // Minimum donation amount
    uint256 deadline;             // Unix timestamp when campaign ends
    uint256 amountRaised;         // Current total donations
    uint256 totalContributions;   // Number of donations received
    CampaignCategory category;    // Category enum
    bool withdrawn;               // Has creator withdrawn funds?
    bool active;                  // Is campaign still running?
    bool verified;                // Platform verification badge
}
```

**Key Points:**
- `address payable` allows the creator to receive ETH
- `deadline` uses Unix timestamps (seconds since Jan 1, 1970)
- Boolean flags track campaign state

#### Milestone Struct (`CrowdfundingPlatform.sol:45-51`)

```solidity
struct Milestone {
    string description;      // What this milestone represents
    uint256 amount;         // Funding needed for this milestone
    bool completed;         // Has creator marked it complete?
    bool approved;          // Has community approved it?
    uint256 approvalCount;  // Number of donor approvals
}
```

Milestones allow campaigns to have phased funding with community oversight.

#### Campaign Category Enum (`CrowdfundingPlatform.sol:17-26`)

```solidity
enum CampaignCategory {
    Technology,
    Arts,
    Community,
    Education,
    Health,
    Environment,
    Business,
    Other
}
```

Enums provide a type-safe way to categorize campaigns.

---

## Architecture Deep Dive

### 3. Modifiers: The Gatekeepers

Modifiers are reusable code that runs before function execution. Think of them as security guards checking requirements.

#### Access Control Modifiers

**Only Platform Owner** (`CrowdfundingPlatform.sol:176-179`)
```solidity
modifier onlyPlatformOwner() {
    require(msg.sender == platformOwner, "Only platform owner can call this");
    _;
}
```
- `msg.sender` is the address calling the function
- `require()` reverts the transaction if condition is false
- `_;` means "run the rest of the function here"

**Only Campaign Creator** (`CrowdfundingPlatform.sol:181-187`)
```solidity
modifier onlyCampaignCreator(uint256 _campaignId) {
    require(
        msg.sender == campaigns[_campaignId].creator,
        "Only campaign creator can call this"
    );
    _;
}
```
- Takes a parameter to check which campaign
- Ensures only the creator can modify their campaign

#### State Check Modifiers

**Campaign Exists** (`CrowdfundingPlatform.sol:189-192`)
```solidity
modifier campaignExists(uint256 _campaignId) {
    require(_campaignId < campaignCounter, "Campaign does not exist");
    _;
}
```
- Prevents accessing non-existent campaigns
- Since IDs start at 0, valid IDs are 0 to (campaignCounter - 1)

**Campaign Active** (`CrowdfundingPlatform.sol:194-197`)
```solidity
modifier campaignActive(uint256 _campaignId) {
    require(campaigns[_campaignId].active, "Campaign is not active");
    _;
}
```
- Checks the `active` boolean flag
- Prevents donations to cancelled/completed campaigns

#### Security Modifiers

**When Not Paused** (`CrowdfundingPlatform.sol:204-207`)
```solidity
modifier whenNotPaused() {
    require(!paused, "Contract is paused");
    _;
}
```
- Emergency stop mechanism
- Owner can pause contract to prevent operations during emergencies

**Non-Reentrant** (`CrowdfundingPlatform.sol:214-219`)
```solidity
modifier nonReentrant() {
    require(reentrancyStatus != ENTERED, "ReentrancyGuard: reentrant call");
    reentrancyStatus = ENTERED;
    _;
    reentrancyStatus = NOT_ENTERED;
}
```
- Prevents reentrancy attacks (explained in Security section)
- Uses a state variable as a lock

### 4. Events: Communication with the Outside World

Events are logged on the blockchain and are crucial for frontend applications to track what's happening.

**Campaign Created Event** (`CrowdfundingPlatform.sol:85-92`)
```solidity
event CampaignCreated(
    uint256 indexed campaignId,
    address indexed creator,
    string title,
    uint256 goalAmount,
    uint256 deadline,
    CampaignCategory category
);
```

**Why use `indexed`?**
- Makes the parameter searchable/filterable
- Frontend apps can filter events by campaignId or creator address
- Maximum 3 indexed parameters per event

**Emitting Events**
```solidity
emit CampaignCreated(
    campaignCounter,
    msg.sender,
    _title,
    _goalAmount,
    deadline,
    _category
);
```

Events are NOT stored in contract state (cheaper than storage).

---

## Key Features Explained

### Feature 1: Creating a Campaign

**Function:** `createCampaign()` (`CrowdfundingPlatform.sol:245-293`)

```solidity
function createCampaign(
    string memory _title,
    string memory _description,
    uint256 _goalAmount,
    uint256 _minContribution,
    uint256 _durationDays,
    CampaignCategory _category
) external whenNotPaused notBlacklisted(msg.sender)
```

**Step-by-Step Breakdown:**

1. **Input Validation** (`CrowdfundingPlatform.sol:253-257`)
   ```solidity
   require(_goalAmount > 0, "Goal amount must be greater than 0");
   require(_minContribution >= 0, "Min contribution cannot be negative");
   require(_durationDays >= 1 && _durationDays <= 365, "Duration must be between 1 and 365 days");
   ```
   - Ensures data makes sense before proceeding
   - Prevents common mistakes

2. **Duplicate Prevention** (`CrowdfundingPlatform.sol:260-262`)
   ```solidity
   bytes32 campaignHash = keccak256(abi.encodePacked(_title, msg.sender));
   require(!usedCampaignHashes[campaignHash], "Campaign with this title already exists");
   usedCampaignHashes[campaignHash] = true;
   ```
   - `keccak256()` is a cryptographic hash function
   - `abi.encodePacked()` combines title + creator address
   - Prevents same user from creating duplicate campaign names

3. **Calculate Deadline** (`CrowdfundingPlatform.sol:264`)
   ```solidity
   uint256 deadline = block.timestamp + (_durationDays * 1 days);
   ```
   - `block.timestamp` is current time in seconds
   - `1 days` is a Solidity time unit (86400 seconds)

4. **Create Campaign Struct** (`CrowdfundingPlatform.sol:266-279`)
   ```solidity
   campaigns[campaignCounter] = Campaign({
       creator: payable(msg.sender),
       title: _title,
       // ... other fields
       withdrawn: false,
       active: true,
       verified: false
   });
   ```
   - Stores campaign in the campaigns mapping
   - `payable(msg.sender)` converts address to payable address

5. **Track User's Campaigns** (`CrowdfundingPlatform.sol:281`)
   ```solidity
   userCampaigns[msg.sender].push(campaignCounter);
   ```
   - Adds campaign ID to creator's list
   - Allows querying all campaigns by a user

6. **Emit Event and Increment Counter** (`CrowdfundingPlatform.sol:283-292`)
   ```solidity
   emit CampaignCreated(...);
   campaignCounter++;
   ```

### Feature 2: Donating to a Campaign

**Function:** `donate()` (`CrowdfundingPlatform.sol:299-327`)

```solidity
function donate(uint256 _campaignId)
    external
    payable  // Key: Function can receive ETH
    whenNotPaused
    campaignExists(_campaignId)
    campaignActive(_campaignId)
    notBlacklisted(msg.sender)
    nonReentrant
```

**Understanding `payable`:**
- Allows function to receive ETH
- `msg.value` contains the amount of ETH sent
- Without `payable`, function rejects ETH transfers

**Step-by-Step Process:**

1. **Get Campaign Reference** (`CrowdfundingPlatform.sol:308`)
   ```solidity
   Campaign storage campaign = campaigns[_campaignId];
   ```
   - `storage` means we're referencing the actual stored data
   - Changes to `campaign` modify the blockchain state

2. **Validation Checks** (`CrowdfundingPlatform.sol:310-313`)
   ```solidity
   require(block.timestamp < campaign.deadline, "Campaign has ended");
   require(msg.value > 0, "Donation must be greater than 0");
   require(msg.value >= campaign.minContribution, "Donation below minimum");
   require(msg.sender != campaign.creator, "Creator cannot donate to own campaign");
   ```

3. **Track New Donors** (`CrowdfundingPlatform.sol:316-319`)
   ```solidity
   if (contributions[_campaignId][msg.sender] == 0) {
       campaignDonors[_campaignId].push(msg.sender);
       userDonations[msg.sender].push(_campaignId);
   }
   ```
   - Only adds donor to list on first donation
   - Prevents duplicate entries

4. **Update Amounts** (`CrowdfundingPlatform.sol:322-324`)
   ```solidity
   contributions[_campaignId][msg.sender] += msg.value;
   campaign.amountRaised += msg.value;
   campaign.totalContributions++;
   ```
   - `+=` adds to existing amount (supports multiple donations)
   - ETH is automatically transferred to contract

5. **Emit Event** (`CrowdfundingPlatform.sol:326`)

### Feature 3: Withdrawing Funds

**Function:** `withdrawFunds()` (`CrowdfundingPlatform.sol:333-362`)

```solidity
function withdrawFunds(uint256 _campaignId)
    external
    whenNotPaused
    campaignExists(_campaignId)
    onlyCampaignCreator(_campaignId)
    nonReentrant  // Critical for preventing attacks
```

**Why This is Complex:**

1. **Strict Requirements** (`CrowdfundingPlatform.sol:342-345`)
   ```solidity
   require(block.timestamp >= campaign.deadline, "Campaign still ongoing");
   require(campaign.amountRaised >= campaign.goalAmount, "Goal not reached");
   require(!campaign.withdrawn, "Funds already withdrawn");
   require(campaign.active, "Campaign not active");
   ```
   - Must wait until deadline passes
   - Must reach goal (all-or-nothing model)
   - Can only withdraw once

2. **Update State BEFORE Transfer** (`CrowdfundingPlatform.sol:347-348`)
   ```solidity
   campaign.withdrawn = true;
   campaign.active = false;
   ```
   - **CRITICAL:** Update state before sending ETH
   - Prevents reentrancy attacks (explained in Security section)

3. **Calculate Platform Fee** (`CrowdfundingPlatform.sol:351-352`)
   ```solidity
   uint256 fee = (campaign.amountRaised * platformFeePercent) / 100;
   uint256 amountToCreator = campaign.amountRaised - fee;
   ```
   - Platform takes a small percentage (default 2%)
   - Integer division in Solidity (no decimals)

4. **Safe ETH Transfer** (`CrowdfundingPlatform.sol:358-359`)
   ```solidity
   (bool success, ) = campaign.creator.call{value: amountToCreator}("");
   require(success, "Transfer to creator failed");
   ```
   - `.call{value: amount}("")` is the modern way to send ETH
   - Returns boolean indicating success
   - Empty string `""` means no function call, just ETH transfer

### Feature 4: Getting Refunds

**Function:** `getRefund()` (`CrowdfundingPlatform.sol:368-388`)

```solidity
function getRefund(uint256 _campaignId)
    external
    whenNotPaused
    campaignExists(_campaignId)
    nonReentrant
```

**When Can You Get a Refund?**

1. Campaign deadline passed AND goal not reached
2. Campaign was cancelled by creator

**Key Security Pattern:**

```solidity
uint256 refundAmount = contributions[_campaignId][msg.sender];
contributions[_campaignId][msg.sender] = 0;  // Set to 0 BEFORE transfer

(bool success, ) = payable(msg.sender).call{value: refundAmount}("");
require(success, "Refund transfer failed");
```

**Why set to 0 first?**
- Prevents reentrancy attacks
- If transfer fails, transaction reverts and contribution remains

### Feature 5: Milestone System

Milestones allow campaigns to have phased funding with community accountability.

#### Adding Milestones (`CrowdfundingPlatform.sol:434-454`)

```solidity
function addMilestone(
    uint256 _campaignId,
    string memory _description,
    uint256 _amount
) external campaignExists(_campaignId) onlyCampaignCreator(_campaignId)
```

**Example Milestones:**
1. "Complete product design" - 30% of goal
2. "Build prototype" - 40% of goal
3. "Launch production" - 30% of goal

#### Completing Milestones (`CrowdfundingPlatform.sol:461-474`)

Creator marks milestone as completed:
```solidity
function completeMilestone(uint256 _campaignId, uint256 _milestoneIndex)
    external
    campaignExists(_campaignId)
    onlyCampaignCreator(_campaignId)
```

#### Approving Milestones (`CrowdfundingPlatform.sol:481-496`)

Donors can approve completed milestones:
```solidity
function approveMilestone(uint256 _campaignId, uint256 _milestoneIndex)
    external
    campaignExists(_campaignId)
{
    require(contributions[_campaignId][msg.sender] > 0, "Only donors can approve");
    require(!milestoneApprovals[_campaignId][_milestoneIndex][msg.sender], "Already approved");

    milestone.approvalCount++;
}
```

This creates accountability - donors can see if creators deliver on promises.

---

## Security Mechanisms

### 1. Reentrancy Protection

**What is Reentrancy?**

A reentrancy attack occurs when:
1. Contract A calls Contract B
2. Before Contract A finishes, Contract B calls back into Contract A
3. Contract A's state is inconsistent, allowing exploitation

**Famous Example: The DAO Hack (2016)**
- Attacker drained 3.6 million ETH (~$70M)
- Exploited reentrancy in withdrawal function

**How This Contract Prevents It:**

```solidity
uint256 private reentrancyStatus;
uint256 private constant NOT_ENTERED = 1;
uint256 private constant ENTERED = 2;

modifier nonReentrant() {
    require(reentrancyStatus != ENTERED, "ReentrancyGuard: reentrant call");
    reentrancyStatus = ENTERED;
    _;
    reentrancyStatus = NOT_ENTERED;
}
```

**How It Works:**
1. First call: Status is NOT_ENTERED (1), set to ENTERED (2), proceed
2. Reentrant call: Status is ENTERED (2), require fails, transaction reverts
3. After completion: Status reset to NOT_ENTERED (1)

**Additional Pattern: Checks-Effects-Interactions**

```solidity
// 1. CHECKS
require(campaign.amountRaised >= campaign.goalAmount, "Goal not reached");

// 2. EFFECTS (state changes)
campaign.withdrawn = true;
campaign.active = false;

// 3. INTERACTIONS (external calls)
(bool success, ) = campaign.creator.call{value: amountToCreator}("");
```

Always change state BEFORE external calls!

### 2. Access Control

**Multiple Layers:**

1. **Owner-Only Functions**
   ```solidity
   modifier onlyPlatformOwner() {
       require(msg.sender == platformOwner, "Only platform owner can call this");
       _;
   }
   ```

2. **Creator-Only Functions**
   ```solidity
   modifier onlyCampaignCreator(uint256 _campaignId) {
       require(msg.sender == campaigns[_campaignId].creator, "Only campaign creator");
       _;
   }
   ```

3. **Blacklist System** (`CrowdfundingPlatform.sol:547-551`)
   ```solidity
   function setBlacklist(address _account, bool _blacklisted)
       external
       onlyPlatformOwner
   {
       require(_account != platformOwner, "Cannot blacklist owner");
       blacklistedAddresses[_account] = _blacklisted;
   }
   ```

### 3. Emergency Controls

**Pause Mechanism** (`CrowdfundingPlatform.sol:556-567`)

```solidity
bool public paused;

function pause() external onlyPlatformOwner {
    paused = true;
    emit PlatformPaused(true);
}

function unpause() external onlyPlatformOwner {
    paused = false;
    emit PlatformPaused(false);
}
```

When paused:
- No new campaigns
- No donations
- No withdrawals
- Only owner can unpause

**Emergency Withdrawal** (`CrowdfundingPlatform.sol:587-604`)

```solidity
function emergencyWithdraw(uint256 _campaignId)
    external
    onlyPlatformOwner
    whenPaused  // Only when paused!
    campaignExists(_campaignId)
    nonReentrant
```

Last resort for recovering stuck funds.

### 4. Input Validation

**Extensive Checks:**

```solidity
require(_goalAmount > 0, "Goal amount must be greater than 0");
require(bytes(_title).length > 0 && bytes(_title).length <= 100, "Title must be 1-100 characters");
require(_durationDays >= 1 && _durationDays <= 365, "Duration must be between 1 and 365 days");
```

**Why This Matters:**
- Prevents accidental mistakes
- Blocks malicious inputs
- Ensures data integrity

### 5. Integer Overflow Protection

Solidity 0.8.0+ has built-in overflow protection:

```solidity
uint256 x = 2**256 - 1;  // Maximum uint256
x = x + 1;  // This REVERTS instead of wrapping to 0
```

Before 0.8.0, this would silently wrap to 0 (dangerous!).

---

## How to Use the Contract

### For Campaign Creators

#### Step 1: Create a Campaign

```solidity
createCampaign(
    "Build Community Garden",           // title
    "A green space for our neighborhood", // description
    5 ether,                            // goal (5 ETH)
    0.01 ether,                         // minimum contribution
    30,                                 // duration in days
    CampaignCategory.Community          // category
);
```

**Note:** `1 ether` is 1,000,000,000,000,000,000 wei (10^18)

#### Step 2: Add Milestones (Optional)

```solidity
addMilestone(
    0,                              // campaign ID
    "Purchase land",                // description
    2 ether                         // amount for this milestone
);

addMilestone(
    0,
    "Build garden infrastructure",
    3 ether
);
```

#### Step 3: Post Updates

```solidity
addCampaignUpdate(
    0,                              // campaign ID
    "We've reached 50% of our goal! Thank you all!"
);
```

#### Step 4: Complete Milestones

```solidity
completeMilestone(0, 0);  // Mark milestone 0 as complete
```

#### Step 5: Withdraw Funds (After Success)

```solidity
withdrawFunds(0);  // Withdraw funds from campaign 0
```

### For Donors

#### Step 1: View Campaign Details

```solidity
(
    address creator,
    string memory title,
    string memory description,
    uint256 goalAmount,
    uint256 minContribution,
    uint256 deadline,
    uint256 amountRaised,
    uint256 totalContributions,
    CampaignCategory category,
    bool withdrawn,
    bool active,
    bool verified
) = getCampaign(0);  // Get campaign 0 details
```

#### Step 2: Check Time Remaining

```solidity
uint256 timeLeft = getTimeRemaining(0);  // Returns seconds remaining
```

#### Step 3: Donate

```solidity
donate{value: 0.1 ether}(0);  // Donate 0.1 ETH to campaign 0
```

**Important:** Use `{value: amount}` syntax to send ETH!

#### Step 4: Approve Milestones

```solidity
approveMilestone(0, 0);  // Approve milestone 0 of campaign 0
```

#### Step 5: Get Refund (If Campaign Fails)

```solidity
getRefund(0);  // Get refund from campaign 0
```

### For Platform Owner

#### Verify Campaigns

```solidity
verifyCampaign(0, true);  // Verify campaign 0
```

#### Adjust Platform Fee

```solidity
updatePlatformFee(3);  // Set fee to 3%
```

#### Withdraw Platform Fees

```solidity
withdrawPlatformFees();  // Collect accumulated fees
```

#### Emergency Actions

```solidity
pause();  // Pause contract

blacklist(0x123..., true);  // Blacklist malicious address

emergencyWithdraw(0);  // Emergency withdrawal (only when paused)
```

---

## Advanced Topics

### 1. Gas Optimization Techniques

**Used in This Contract:**

#### Packing State Variables
```solidity
bool withdrawn;
bool active;
bool verified;
```
- Booleans are packed together in storage
- Saves gas by using same storage slot

#### Using Constants
```solidity
uint256 public constant MAX_PLATFORM_FEE = 5;
uint256 public constant MIN_CAMPAIGN_DURATION = 1 days;
```
- Constants don't use storage (compiled into bytecode)
- Cheaper to access than regular variables

#### Caching Storage Reads
```solidity
Campaign storage campaign = campaigns[_campaignId];  // Read once
// Use 'campaign' multiple times instead of 'campaigns[_campaignId]'
```

### 2. Pagination Pattern

**Why Needed?**

Returning large arrays costs lots of gas and can hit gas limits.

**Implementation:** (`CrowdfundingPlatform.sol:683-709`)

```solidity
function getCampaignDonors(uint256 _campaignId, uint256 _offset, uint256 _limit)
    external
    view
    returns (address[] memory, uint256[] memory)
{
    address[] storage allDonors = campaignDonors[_campaignId];
    uint256 end = _offset + _limit;
    if (end > allDonors.length) {
        end = allDonors.length;
    }

    // Create arrays of exact size needed
    uint256 resultLength = end - _offset;
    address[] memory donorAddresses = new address[](resultLength);
    uint256[] memory donorContributions = new uint256[](resultLength);

    for (uint256 i = 0; i < resultLength; i++) {
        address donor = allDonors[_offset + i];
        donorAddresses[i] = donor;
        donorContributions[i] = contributions[_campaignId][donor];
    }

    return (donorAddresses, donorContributions);
}
```

**Usage:**
```solidity
// Get first 100 donors
(addresses, amounts) = getCampaignDonors(0, 0, 100);

// Get next 100 donors
(addresses, amounts) = getCampaignDonors(0, 100, 100);
```

### 3. The Fallback and Receive Functions

**Purpose:** Handle direct ETH transfers to contract

```solidity
fallback() external payable {
    revert("Direct transfers not allowed. Use donate() function");
}

receive() external payable {
    revert("Direct transfers not allowed. Use donate() function");
}
```

**When They're Called:**
- `receive()`: Called when ETH sent with no data
- `fallback()`: Called when function doesn't exist or ETH sent with data

**Why Revert Here?**
- Forces users to use `donate()` function
- Ensures proper tracking of donations
- Prevents accidental loss of funds

### 4. Time-Based Logic

**Unix Timestamps:**

```solidity
uint256 deadline = block.timestamp + (_durationDays * 1 days);
```

- `block.timestamp`: Current time in seconds since Jan 1, 1970
- Miners can manipulate by ~15 seconds
- Don't use for critical security, OK for campaign deadlines

**Time Units:**
- `1 seconds` = 1
- `1 minutes` = 60
- `1 hours` = 3600
- `1 days` = 86400
- `1 weeks` = 604800

### 5. The `memory` vs `storage` Distinction

**Storage:**
```solidity
Campaign storage campaign = campaigns[_campaignId];
campaign.amountRaised += msg.value;  // Modifies blockchain state
```
- References actual blockchain storage
- Changes persist
- More expensive

**Memory:**
```solidity
Campaign memory campaign = campaigns[_campaignId];
campaign.amountRaised += msg.value;  // Only changes local copy!
```
- Temporary copy in memory
- Changes DON'T persist
- Cheaper

**Rule of Thumb:**
- Use `storage` when modifying data
- Use `memory` for read-only operations

---

## Best Practices and Patterns

### 1. The Checks-Effects-Interactions Pattern

```solidity
function withdrawFunds(uint256 _campaignId) external {
    // 1. CHECKS - Validate everything first
    require(block.timestamp >= campaign.deadline, "Campaign still ongoing");
    require(campaign.amountRaised >= campaign.goalAmount, "Goal not reached");
    require(!campaign.withdrawn, "Funds already withdrawn");

    // 2. EFFECTS - Update state
    campaign.withdrawn = true;
    campaign.active = false;
    totalPlatformFees += fee;

    // 3. INTERACTIONS - External calls last
    (bool success, ) = campaign.creator.call{value: amountToCreator}("");
    require(success, "Transfer failed");
}
```

**Why This Order?**
1. Catch errors early (gas refund if fails)
2. Update state before external calls (prevents reentrancy)
3. External calls can't exploit inconsistent state

### 2. Fail Fast with `require()`

```solidity
require(_goalAmount > 0, "Goal amount must be greater than 0");
require(_durationDays >= 1 && _durationDays <= 365, "Duration must be between 1 and 365 days");
```

- Check inputs at function start
- Provide clear error messages
- Save gas by failing early

### 3. Use Events for All State Changes

```solidity
emit CampaignCreated(campaignCounter, msg.sender, _title, _goalAmount, deadline, _category);
emit DonationReceived(_campaignId, msg.sender, msg.value, campaign.amountRaised);
```

**Benefits:**
- Frontend apps can track changes
- Creates audit trail
- Cheaper than storing in state

### 4. Modifiers for Reusable Checks

Instead of:
```solidity
function foo() external {
    require(msg.sender == owner, "Not owner");
    // ... function code
}

function bar() external {
    require(msg.sender == owner, "Not owner");
    // ... function code
}
```

Use:
```solidity
modifier onlyOwner() {
    require(msg.sender == owner, "Not owner");
    _;
}

function foo() external onlyOwner { /* ... */ }
function bar() external onlyOwner { /* ... */ }
```

### 5. Explicit Over Implicit

```solidity
// Good: Explicit visibility
function donate(uint256 _campaignId) external payable { }

// Good: Explicit data location
function createCampaign(string memory _title) external { }

// Good: Explicit parameter naming
function getCampaign(uint256 _campaignId) external view { }
```

### 6. SafeMath No Longer Needed

Solidity 0.8.0+ has automatic overflow checking:

```solidity
// Old way (Solidity < 0.8.0)
using SafeMath for uint256;
amount = amount.add(msg.value);

// New way (Solidity >= 0.8.0)
amount = amount + msg.value;  // Automatically safe!
```

---

## Common Pitfalls to Avoid

### 1. Not Using `nonReentrant` on ETH Transfers

```solidity
// BAD - Vulnerable to reentrancy
function withdraw() external {
    uint256 amount = balances[msg.sender];
    (bool success, ) = msg.sender.call{value: amount}("");
    balances[msg.sender] = 0;
}

// GOOD - Protected
function withdraw() external nonReentrant {
    uint256 amount = balances[msg.sender];
    balances[msg.sender] = 0;  // Update first!
    (bool success, ) = msg.sender.call{value: amount}("");
}
```

### 2. Using `transfer()` or `send()`

```solidity
// BAD - Can fail with certain wallets
payable(recipient).transfer(amount);

// GOOD - Modern best practice
(bool success, ) = recipient.call{value: amount}("");
require(success, "Transfer failed");
```

### 3. Forgetting to Make Addresses Payable

```solidity
// BAD
address creator;
creator.transfer(1 ether);  // Won't compile!

// GOOD
address payable creator;
creator.transfer(1 ether);  // Works

// Or cast
(bool success, ) = payable(creator).call{value: 1 ether}("");
```

### 4. Assuming ETH Transfer Always Succeeds

```solidity
// BAD - Ignoring return value
recipient.call{value: amount}("");

// GOOD - Checking success
(bool success, ) = recipient.call{value: amount}("");
require(success, "Transfer failed");
```

### 5. Not Validating Array Indices

```solidity
// BAD - Can go out of bounds
milestone = milestones[index];

// GOOD - Check first
require(index < milestones.length, "Invalid index");
milestone = milestones[index];
```

---

## Testing Strategy

### What to Test

1. **Happy Path**
   - Create campaign successfully
   - Donate to active campaign
   - Withdraw after successful campaign

2. **Failure Cases**
   - Cannot donate to inactive campaign
   - Cannot withdraw before deadline
   - Cannot withdraw without reaching goal
   - Refunds work when campaign fails

3. **Edge Cases**
   - Exact goal amount reached
   - Donation at last second before deadline
   - Multiple donations from same address

4. **Security**
   - Reentrancy protection works
   - Only owner can access admin functions
   - Only creator can withdraw their campaign

5. **Access Control**
   - Blacklisted addresses blocked
   - Only campaign creator can cancel

### Testing Frameworks

- **Hardhat**: Modern, JavaScript/TypeScript-based
- **Foundry**: Rust-based, very fast, uses Solidity for tests
- **Truffle**: Older, still widely used

---

## Deployment Checklist

Before deploying to mainnet:

- [ ] All tests passing
- [ ] Security audit completed
- [ ] Gas optimization verified
- [ ] Frontend integration tested
- [ ] Emergency procedures documented
- [ ] Multi-sig wallet for owner (recommended)
- [ ] Platform fee configured
- [ ] Verified on Etherscan

---

## Further Learning Resources

### Official Documentation
- Solidity Docs: https://docs.soliditylang.org/
- Ethereum.org: https://ethereum.org/developers

### Security
- Consensys Smart Contract Best Practices: https://consensys.github.io/smart-contract-best-practices/
- OpenZeppelin Contracts: https://docs.openzeppelin.com/contracts/

### Advanced Topics
- Gas Optimization: Patrick Collins YouTube channel
- Design Patterns: Solidity Patterns website
- MEV (Miner Extractable Value): Flashbots docs

---

## Glossary

**Address**: 20-byte identifier for accounts/contracts (e.g., 0x1234...)

**Gas**: Computational fee for executing transactions

**Wei**: Smallest unit of ETH (1 ETH = 10^18 wei)

**Modifier**: Reusable code that runs before function execution

**Mapping**: Key-value storage (like a hash table)

**Struct**: Custom data type with multiple fields

**Event**: Logged output for frontend applications

**Require**: Validation that reverts transaction if false

**Payable**: Allows function/address to receive ETH

**View**: Function that reads but doesn't modify state

**Pure**: Function that neither reads nor modifies state

**Storage**: Persistent blockchain storage

**Memory**: Temporary function-local storage

**Calldata**: Read-only function parameter storage

---

## Summary

You've learned:

1. How to structure a professional smart contract
2. Key Solidity concepts (structs, mappings, modifiers, events)
3. Security patterns (reentrancy protection, access control)
4. Best practices for writing safe, efficient code
5. How to implement complex business logic on-chain

**Next Steps:**

1. Deploy this contract on a testnet (Goerli, Sepolia)
2. Build a frontend interface with Web3.js or Ethers.js
3. Write comprehensive tests
4. Study other DeFi protocols
5. Join Ethereum development communities

Remember: Smart contracts are immutable once deployed. Test thoroughly, audit carefully, and always prioritize security!

---

## Questions and Exercises

### Beginner Exercises

1. What happens if you try to donate 0 ETH to a campaign?
2. Can a campaign creator donate to their own campaign? Why not?
3. What's the minimum and maximum duration for a campaign?

### Intermediate Exercises

1. Add a feature to extend campaign deadlines
2. Implement a "featured campaigns" list
3. Add support for ERC20 token donations

### Advanced Exercises

1. Implement quadratic funding
2. Add support for recurring donations
3. Create a reputation system for campaign creators

---

**Happy coding, and welcome to the world of decentralized applications!**
