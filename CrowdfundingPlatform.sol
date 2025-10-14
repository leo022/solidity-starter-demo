// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CrowdfundingPlatform
 * @dev A comprehensive smart contract demonstrating advanced Solidity concepts
 * @notice This contract allows users to create campaigns, donate, and withdraw funds
 * @author TC
 */
contract CrowdfundingPlatform {

    // ============================================
    // STATE VARIABLES
    // ============================================

    // Campaign categories for better organization
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

    // Campaign structure to store campaign details
    struct Campaign {
        address payable creator;      // Campaign creator's address
        string title;                 // Campaign title
        string description;           // Campaign description
        uint256 goalAmount;           // Funding goal in wei
        uint256 minContribution;      // Minimum contribution amount
        uint256 deadline;             // Campaign deadline (Unix timestamp)
        uint256 amountRaised;         // Total amount raised
        uint256 totalContributions;   // Number of contributions
        CampaignCategory category;    // Campaign category
        bool withdrawn;               // Whether funds have been withdrawn
        bool active;                  // Campaign status
        bool verified;                // Verified by platform (optional trust signal)
    }

    // Milestone structure for milestone-based funding
    struct Milestone {
        string description;
        uint256 amount;
        bool completed;
        bool approved;
        uint256 approvalCount;
    }

    // Storage
    mapping(uint256 => Campaign) public campaigns;                           // Campaign ID to Campaign
    mapping(uint256 => mapping(address => uint256)) public contributions;    // Campaign ID -> Donor -> Amount
    mapping(uint256 => address[]) private campaignDonors;                    // Track all donors per campaign
    mapping(uint256 => Milestone[]) public campaignMilestones;              // Campaign milestones
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public milestoneApprovals;  // Campaign -> Milestone -> Donor -> Approved
    mapping(address => uint256[]) private userCampaigns;                     // User to their campaigns
    mapping(address => uint256[]) private userDonations;                     // User to campaigns they donated to
    mapping(bytes32 => bool) private usedCampaignHashes;                     // Prevent duplicate campaign names
    mapping(address => bool) public blacklistedAddresses;                    // Blacklist for malicious actors
    mapping(uint256 => string) public campaignUpdates;                       // Campaign updates/announcements
    mapping(uint256 => uint256) public updateCount;                          // Number of updates per campaign

    uint256 public campaignCounter;                                          // Total number of campaigns
    uint256 public platformFeePercent = 2;                                   // 2% platform fee (can be adjusted)
    uint256 public constant MAX_PLATFORM_FEE = 5;                           // Maximum platform fee (5%)
    uint256 public constant MIN_CAMPAIGN_DURATION = 1 days;                 // Minimum campaign duration
    uint256 public constant MAX_CAMPAIGN_DURATION = 365 days;               // Maximum campaign duration
    uint256 public constant MAX_DONORS_RETURN = 100;                        // Max donors to return in one call
    address payable public platformOwner;                                    // Platform owner address
    uint256 public totalPlatformFees;                                        // Accumulated platform fees
    bool public paused;                                                      // Emergency pause state

    // Reentrancy guard
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private reentrancyStatus;

    // ============================================
    // EVENTS
    // ============================================

    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goalAmount,
        uint256 deadline,
        CampaignCategory category
    );

    event DonationReceived(
        uint256 indexed campaignId,
        address indexed donor,
        uint256 amount,
        uint256 totalRaised
    );

    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount,
        uint256 fee
    );

    event RefundIssued(
        uint256 indexed campaignId,
        address indexed donor,
        uint256 amount
    );

    event CampaignCancelled(
        uint256 indexed campaignId,
        address indexed creator,
        string reason
    );

    event CampaignUpdated(
        uint256 indexed campaignId,
        string updateMessage,
        uint256 timestamp
    );

    event MilestoneAdded(
        uint256 indexed campaignId,
        uint256 milestoneIndex,
        string description,
        uint256 amount
    );

    event MilestoneCompleted(
        uint256 indexed campaignId,
        uint256 milestoneIndex
    );

    event MilestoneApproved(
        uint256 indexed campaignId,
        uint256 milestoneIndex,
        address indexed approver
    );

    event PlatformFeeUpdated(
        uint256 oldFee,
        uint256 newFee
    );

    event CampaignVerified(
        uint256 indexed campaignId,
        bool verified
    );

    event AddressBlacklisted(
        address indexed account,
        bool blacklisted
    );

    event EmergencyWithdrawal(
        uint256 indexed campaignId,
        address indexed to,
        uint256 amount
    );

    event PlatformPaused(bool paused);

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    // ============================================
    // MODIFIERS
    // ============================================

    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner can call this");
        _;
    }

    modifier onlyCampaignCreator(uint256 _campaignId) {
        require(
            msg.sender == campaigns[_campaignId].creator,
            "Only campaign creator can call this"
        );
        _;
    }

    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        _;
    }

    modifier campaignActive(uint256 _campaignId) {
        require(campaigns[_campaignId].active, "Campaign is not active");
        _;
    }

    modifier notBlacklisted(address _account) {
        require(!blacklistedAddresses[_account], "Address is blacklisted");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "Contract is not paused");
        _;
    }

    modifier nonReentrant() {
        require(reentrancyStatus != ENTERED, "ReentrancyGuard: reentrant call");
        reentrancyStatus = ENTERED;
        _;
        reentrancyStatus = NOT_ENTERED;
    }

    // ============================================
    // CONSTRUCTOR
    // ============================================

    constructor() {
        platformOwner = payable(msg.sender);
        campaignCounter = 0;
        paused = false;
        reentrancyStatus = NOT_ENTERED;
    }

    // ============================================
    // CORE FUNCTIONS
    // ============================================

    /**
     * @dev Create a new crowdfunding campaign
     * @param _title Campaign title
     * @param _description Campaign description
     * @param _goalAmount Funding goal in wei
     * @param _minContribution Minimum contribution amount
     * @param _durationDays Campaign duration in days
     * @param _category Campaign category
     */
    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _minContribution,
        uint256 _durationDays,
        CampaignCategory _category
    ) external whenNotPaused notBlacklisted(msg.sender) {
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_minContribution >= 0, "Min contribution cannot be negative");
        require(_durationDays >= 1 && _durationDays <= 365, "Duration must be between 1 and 365 days");
        require(bytes(_title).length > 0 && bytes(_title).length <= 100, "Title must be 1-100 characters");
        require(bytes(_description).length > 0 && bytes(_description).length <= 1000, "Description must be 1-1000 characters");

        // Prevent duplicate campaign names from same creator
        bytes32 campaignHash = keccak256(abi.encodePacked(_title, msg.sender));
        require(!usedCampaignHashes[campaignHash], "Campaign with this title already exists");
        usedCampaignHashes[campaignHash] = true;

        uint256 deadline = block.timestamp + (_durationDays * 1 days);

        campaigns[campaignCounter] = Campaign({
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goalAmount: _goalAmount,
            minContribution: _minContribution,
            deadline: deadline,
            amountRaised: 0,
            totalContributions: 0,
            category: _category,
            withdrawn: false,
            active: true,
            verified: false
        });

        userCampaigns[msg.sender].push(campaignCounter);

        emit CampaignCreated(
            campaignCounter,
            msg.sender,
            _title,
            _goalAmount,
            deadline,
            _category
        );

        campaignCounter++;
    }

    /**
     * @dev Donate to a campaign
     * @param _campaignId The ID of the campaign to donate to
     */
    function donate(uint256 _campaignId)
        external
        payable
        whenNotPaused
        campaignExists(_campaignId)
        campaignActive(_campaignId)
        notBlacklisted(msg.sender)
        nonReentrant
    {
        Campaign storage campaign = campaigns[_campaignId];

        require(block.timestamp < campaign.deadline, "Campaign has ended");
        require(msg.value > 0, "Donation must be greater than 0");
        require(msg.value >= campaign.minContribution, "Donation below minimum contribution");
        require(msg.sender != campaign.creator, "Creator cannot donate to own campaign");

        // Track new donors
        if (contributions[_campaignId][msg.sender] == 0) {
            campaignDonors[_campaignId].push(msg.sender);
            userDonations[msg.sender].push(_campaignId);
        }

        // Update contribution amounts
        contributions[_campaignId][msg.sender] += msg.value;
        campaign.amountRaised += msg.value;
        campaign.totalContributions++;

        emit DonationReceived(_campaignId, msg.sender, msg.value, campaign.amountRaised);
    }

    /**
     * @dev Withdraw funds from a successful campaign (creator only)
     * @param _campaignId The ID of the campaign
     */
    function withdrawFunds(uint256 _campaignId)
        external
        whenNotPaused
        campaignExists(_campaignId)
        onlyCampaignCreator(_campaignId)
        nonReentrant
    {
        Campaign storage campaign = campaigns[_campaignId];

        require(block.timestamp >= campaign.deadline, "Campaign still ongoing");
        require(campaign.amountRaised >= campaign.goalAmount, "Goal not reached");
        require(!campaign.withdrawn, "Funds already withdrawn");
        require(campaign.active, "Campaign not active");

        campaign.withdrawn = true;
        campaign.active = false;

        // Calculate platform fee
        uint256 fee = (campaign.amountRaised * platformFeePercent) / 100;
        uint256 amountToCreator = campaign.amountRaised - fee;

        // Update platform fees
        totalPlatformFees += fee;

        // Transfer funds
        (bool success, ) = campaign.creator.call{value: amountToCreator}("");
        require(success, "Transfer to creator failed");

        emit FundsWithdrawn(_campaignId, campaign.creator, amountToCreator, fee);
    }

    /**
     * @dev Refund a donor if campaign fails to reach goal
     * @param _campaignId The ID of the campaign
     */
    function getRefund(uint256 _campaignId)
        external
        whenNotPaused
        campaignExists(_campaignId)
        nonReentrant
    {
        Campaign storage campaign = campaigns[_campaignId];

        require(block.timestamp >= campaign.deadline || !campaign.active, "Campaign still ongoing");
        require(campaign.amountRaised < campaign.goalAmount, "Campaign was successful");
        require(contributions[_campaignId][msg.sender] > 0, "No contribution found");

        uint256 refundAmount = contributions[_campaignId][msg.sender];
        contributions[_campaignId][msg.sender] = 0;

        // Transfer refund
        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Refund transfer failed");

        emit RefundIssued(_campaignId, msg.sender, refundAmount);
    }

    /**
     * @dev Cancel a campaign before deadline (creator only)
     * @param _campaignId The ID of the campaign
     * @param _reason Reason for cancellation
     */
    function cancelCampaign(uint256 _campaignId, string memory _reason)
        external
        campaignExists(_campaignId)
        onlyCampaignCreator(_campaignId)
        campaignActive(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp < campaign.deadline, "Campaign already ended");

        campaign.active = false;

        emit CampaignCancelled(_campaignId, msg.sender, _reason);
    }

    /**
     * @dev Add an update/announcement to a campaign
     * @param _campaignId The ID of the campaign
     * @param _updateMessage Update message
     */
    function addCampaignUpdate(uint256 _campaignId, string memory _updateMessage)
        external
        campaignExists(_campaignId)
        onlyCampaignCreator(_campaignId)
    {
        require(bytes(_updateMessage).length > 0 && bytes(_updateMessage).length <= 500, "Update must be 1-500 characters");

        uint256 count = updateCount[_campaignId];
        campaignUpdates[_campaignId * 10000 + count] = _updateMessage;  // Simple key generation
        updateCount[_campaignId]++;

        emit CampaignUpdated(_campaignId, _updateMessage, block.timestamp);
    }

    /**
     * @dev Add milestone to campaign (before campaign starts getting significant funding)
     * @param _campaignId Campaign ID
     * @param _description Milestone description
     * @param _amount Amount needed for milestone
     */
    function addMilestone(
        uint256 _campaignId,
        string memory _description,
        uint256 _amount
    ) external campaignExists(_campaignId) onlyCampaignCreator(_campaignId) {
        require(bytes(_description).length > 0, "Milestone description required");
        require(_amount > 0, "Milestone amount must be greater than 0");

        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.active, "Campaign not active");

        campaignMilestones[_campaignId].push(Milestone({
            description: _description,
            amount: _amount,
            completed: false,
            approved: false,
            approvalCount: 0
        }));

        emit MilestoneAdded(_campaignId, campaignMilestones[_campaignId].length - 1, _description, _amount);
    }

    /**
     * @dev Mark milestone as completed (creator only)
     * @param _campaignId Campaign ID
     * @param _milestoneIndex Milestone index
     */
    function completeMilestone(uint256 _campaignId, uint256 _milestoneIndex)
        external
        campaignExists(_campaignId)
        onlyCampaignCreator(_campaignId)
    {
        require(_milestoneIndex < campaignMilestones[_campaignId].length, "Invalid milestone index");

        Milestone storage milestone = campaignMilestones[_campaignId][_milestoneIndex];
        require(!milestone.completed, "Milestone already completed");

        milestone.completed = true;

        emit MilestoneCompleted(_campaignId, _milestoneIndex);
    }

    /**
     * @dev Donors can approve milestones
     * @param _campaignId Campaign ID
     * @param _milestoneIndex Milestone index
     */
    function approveMilestone(uint256 _campaignId, uint256 _milestoneIndex)
        external
        campaignExists(_campaignId)
    {
        require(contributions[_campaignId][msg.sender] > 0, "Only donors can approve");
        require(_milestoneIndex < campaignMilestones[_campaignId].length, "Invalid milestone index");
        require(!milestoneApprovals[_campaignId][_milestoneIndex][msg.sender], "Already approved");

        Milestone storage milestone = campaignMilestones[_campaignId][_milestoneIndex];
        require(milestone.completed, "Milestone not completed yet");

        milestoneApprovals[_campaignId][_milestoneIndex][msg.sender] = true;
        milestone.approvalCount++;

        emit MilestoneApproved(_campaignId, _milestoneIndex, msg.sender);
    }

    // ============================================
    // ADMIN FUNCTIONS
    // ============================================

    /**
     * @dev Withdraw platform fees (owner only)
     */
    function withdrawPlatformFees() external onlyPlatformOwner nonReentrant {
        require(totalPlatformFees > 0, "No fees to withdraw");

        uint256 amount = totalPlatformFees;
        totalPlatformFees = 0;

        (bool success, ) = platformOwner.call{value: amount}("");
        require(success, "Fee withdrawal failed");
    }

    /**
     * @dev Update platform fee percentage
     * @param _newFeePercent New fee percentage
     */
    function updatePlatformFee(uint256 _newFeePercent) external onlyPlatformOwner {
        require(_newFeePercent <= MAX_PLATFORM_FEE, "Fee exceeds maximum");

        uint256 oldFee = platformFeePercent;
        platformFeePercent = _newFeePercent;

        emit PlatformFeeUpdated(oldFee, _newFeePercent);
    }

    /**
     * @dev Verify a campaign (trust signal)
     * @param _campaignId Campaign ID
     * @param _verified Verification status
     */
    function verifyCampaign(uint256 _campaignId, bool _verified)
        external
        onlyPlatformOwner
        campaignExists(_campaignId)
    {
        campaigns[_campaignId].verified = _verified;
        emit CampaignVerified(_campaignId, _verified);
    }

    /**
     * @dev Blacklist or unblacklist an address
     * @param _account Address to blacklist/unblacklist
     * @param _blacklisted Blacklist status
     */
    function setBlacklist(address _account, bool _blacklisted) external onlyPlatformOwner {
        require(_account != platformOwner, "Cannot blacklist owner");
        blacklistedAddresses[_account] = _blacklisted;
        emit AddressBlacklisted(_account, _blacklisted);
    }

    /**
     * @dev Emergency pause
     */
    function pause() external onlyPlatformOwner {
        paused = true;
        emit PlatformPaused(true);
    }

    /**
     * @dev Unpause
     */
    function unpause() external onlyPlatformOwner {
        paused = false;
        emit PlatformPaused(false);
    }

    /**
     * @dev Transfer ownership
     * @param _newOwner New owner address
     */
    function transferOwnership(address payable _newOwner) external onlyPlatformOwner {
        require(_newOwner != address(0), "Invalid address");
        require(_newOwner != platformOwner, "Already owner");

        address oldOwner = platformOwner;
        platformOwner = _newOwner;

        emit OwnershipTransferred(oldOwner, _newOwner);
    }

    /**
     * @dev Emergency withdrawal for stuck funds (only when paused)
     * @param _campaignId Campaign ID
     */
    function emergencyWithdraw(uint256 _campaignId)
        external
        onlyPlatformOwner
        whenPaused
        campaignExists(_campaignId)
        nonReentrant
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.amountRaised > 0, "No funds to withdraw");

        uint256 amount = campaign.amountRaised;
        campaign.amountRaised = 0;

        (bool success, ) = platformOwner.call{value: amount}("");
        require(success, "Emergency withdrawal failed");

        emit EmergencyWithdrawal(_campaignId, platformOwner, amount);
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /**
     * @dev Get campaign details
     * @param _campaignId The ID of the campaign
     */
    function getCampaign(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (
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
        )
    {
        Campaign memory campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goalAmount,
            campaign.minContribution,
            campaign.deadline,
            campaign.amountRaised,
            campaign.totalContributions,
            campaign.category,
            campaign.withdrawn,
            campaign.active,
            campaign.verified
        );
    }

    /**
     * @dev Get donor's contribution to a campaign
     * @param _campaignId The ID of the campaign
     * @param _donor Address of the donor
     */
    function getContribution(uint256 _campaignId, address _donor)
        external
        view
        campaignExists(_campaignId)
        returns (uint256)
    {
        return contributions[_campaignId][_donor];
    }

    /**
     * @dev Get donors count for a campaign
     * @param _campaignId The ID of the campaign
     */
    function getDonorsCount(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (uint256)
    {
        return campaignDonors[_campaignId].length;
    }

    /**
     * @dev Get campaign donors with pagination
     * @param _campaignId Campaign ID
     * @param _offset Starting index
     * @param _limit Number of donors to return
     */
    function getCampaignDonors(uint256 _campaignId, uint256 _offset, uint256 _limit)
        external
        view
        campaignExists(_campaignId)
        returns (address[] memory, uint256[] memory)
    {
        address[] storage allDonors = campaignDonors[_campaignId];
        uint256 end = _offset + _limit;
        if (end > allDonors.length) {
            end = allDonors.length;
        }

        require(_limit <= MAX_DONORS_RETURN, "Limit exceeds maximum");
        require(_offset < allDonors.length, "Offset out of bounds");

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

    /**
     * @dev Get user's created campaigns
     * @param _user User address
     */
    function getUserCampaigns(address _user) external view returns (uint256[] memory) {
        return userCampaigns[_user];
    }

    /**
     * @dev Get campaigns user has donated to
     * @param _user User address
     */
    function getUserDonations(address _user) external view returns (uint256[] memory) {
        return userDonations[_user];
    }

    /**
     * @dev Get campaign milestones
     * @param _campaignId Campaign ID
     */
    function getCampaignMilestones(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (Milestone[] memory)
    {
        return campaignMilestones[_campaignId];
    }

    /**
     * @dev Check if campaign is successful
     * @param _campaignId The ID of the campaign
     */
    function isCampaignSuccessful(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (bool)
    {
        Campaign memory campaign = campaigns[_campaignId];
        return (
            block.timestamp >= campaign.deadline &&
            campaign.amountRaised >= campaign.goalAmount
        );
    }

    /**
     * @dev Get time remaining for campaign
     * @param _campaignId The ID of the campaign
     */
    function getTimeRemaining(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (uint256)
    {
        Campaign memory campaign = campaigns[_campaignId];
        if (block.timestamp >= campaign.deadline) {
            return 0;
        }
        return campaign.deadline - block.timestamp;
    }

    /**
     * @dev Get campaign progress percentage
     * @param _campaignId Campaign ID
     */
    function getCampaignProgress(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (uint256)
    {
        Campaign memory campaign = campaigns[_campaignId];
        if (campaign.goalAmount == 0) return 0;
        return (campaign.amountRaised * 100) / campaign.goalAmount;
    }

    /**
     * @dev Get active campaigns by category
     * @param _category Campaign category
     * @param _limit Maximum number of campaigns to return
     */
    function getActiveCampaignsByCategory(CampaignCategory _category, uint256 _limit)
        external
        view
        returns (uint256[] memory)
    {
        require(_limit > 0 && _limit <= 100, "Invalid limit");

        uint256[] memory tempCampaigns = new uint256[](_limit);
        uint256 count = 0;

        for (uint256 i = 0; i < campaignCounter && count < _limit; i++) {
            Campaign memory campaign = campaigns[i];
            if (campaign.active && campaign.category == _category && block.timestamp < campaign.deadline) {
                tempCampaigns[count] = i;
                count++;
            }
        }

        // Create result array with actual size
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = tempCampaigns[i];
        }

        return result;
    }

    /**
     * @dev Get contract balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Get campaign update
     * @param _campaignId Campaign ID
     * @param _updateIndex Update index
     */
    function getCampaignUpdate(uint256 _campaignId, uint256 _updateIndex)
        external
        view
        campaignExists(_campaignId)
        returns (string memory)
    {
        require(_updateIndex < updateCount[_campaignId], "Invalid update index");
        return campaignUpdates[_campaignId * 10000 + _updateIndex];
    }

    /**
     * @dev Check if address is blacklisted
     * @param _account Address to check
     */
    function isBlacklisted(address _account) external view returns (bool) {
        return blacklistedAddresses[_account];
    }

    // ============================================
    // FALLBACK & RECEIVE
    // ============================================

    /**
     * @dev Fallback function to reject direct ETH transfers
     */
    fallback() external payable {
        revert("Direct transfers not allowed. Use donate() function");
    }

    /**
     * @dev Receive function to reject direct ETH transfers
     */
    receive() external payable {
        revert("Direct transfers not allowed. Use donate() function");
    }
}
