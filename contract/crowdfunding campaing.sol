// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22; // Updated to a version compatible with Cancun EVM

/**
 * @title CrowdfundingCampaign
 * @dev A smart contract for creating and managing crowdfunding campaigns
 * @custom:evm-version cancun
 */
contract CrowdfundingCampaign {
    // Campaign structure
    struct Campaign {
        address creator;
        string title;
        string description;
        uint256 targetAmount;
        uint256 deadline;
        uint256 amountCollected;
        bool ended;
        bool claimed;
    }
    
    // Mapping from campaign ID to Campaign
    mapping(uint256 => Campaign) public campaigns;
    
    // Mapping from campaign ID to contributor address to contribution amount
    mapping(uint256 => mapping(address => uint256)) public contributions;
    
    // List of contributors for each campaign
    mapping(uint256 => address[]) public contributorsList;
    
    // Total number of campaigns
    uint256 public campaignCount;
    
    // Events
    event CampaignCreated(uint256 indexed campaignId, address indexed creator, string title, uint256 targetAmount, uint256 deadline);
    event ContributionMade(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event FundsClaimed(uint256 indexed campaignId, address indexed creator, uint256 amount);
    event RefundClaimed(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event CampaignEnded(uint256 indexed campaignId, bool successful);
    
    /**
     * @dev Creates a new crowdfunding campaign
     * @param _title Campaign title
     * @param _description Campaign description
     * @param _targetAmount Target amount to be raised in wei
     * @param _durationInDays Duration of the campaign in days
     * @return The ID of the newly created campaign
     */
    function createCampaign(
        string calldata _title,
        string calldata _description,
        uint256 _targetAmount,
        uint256 _durationInDays
    ) public returns (uint256) {
        require(_targetAmount > 0, "Target amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);
        
        uint256 campaignId = campaignCount;
        
        campaigns[campaignId] = Campaign({
            creator: msg.sender,
            title: _title,
            description: _description,
            targetAmount: _targetAmount,
            deadline: deadline,
            amountCollected: 0,
            ended: false,
            claimed: false
        });
        
        campaignCount++;
        
        emit CampaignCreated(campaignId, msg.sender, _title, _targetAmount, deadline);
        return campaignId;
    }
    
    /**
     * @dev Contributes funds to a campaign
     * @param _campaignId ID of the campaign to contribute to
     */
    function contribute(uint256 _campaignId) public payable {
        Campaign storage campaign = campaigns[_campaignId];
        
        require(!campaign.ended, "Campaign has ended");
        require(block.timestamp < campaign.deadline, "Campaign deadline has passed");
        require(msg.value > 0, "Contribution must be greater than 0");
        
        // If this is the first contribution from this address, add to the contributors list
        if (contributions[_campaignId][msg.sender] == 0) {
            contributorsList[_campaignId].push(msg.sender);
        }
        
        contributions[_campaignId][msg.sender] += msg.value;
        campaign.amountCollected += msg.value;
        
        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }
    
    /**
     * @dev Ends a campaign and determines if it was successful
     * @param _campaignId ID of the campaign to end
     */
    function endCampaign(uint256 _campaignId) public {
        Campaign storage campaign = campaigns[_campaignId];
        
        require(msg.sender == campaign.creator, "Only campaign creator can end the campaign");
        require(!campaign.ended, "Campaign already ended");
        require(block.timestamp >= campaign.deadline, "Campaign deadline not reached yet");
        
        campaign.ended = true;
        
        bool successful = campaign.amountCollected >= campaign.targetAmount;
        emit CampaignEnded(_campaignId, successful);
    }
    
    /**
     * @dev Creator claims funds from a successful campaign
     * @param _campaignId ID of the campaign to claim funds from
     */
    function claimFunds(uint256 _campaignId) public {
        Campaign storage campaign = campaigns[_campaignId];
        
        require(msg.sender == campaign.creator, "Only campaign creator can claim funds");
        require(campaign.ended, "Campaign not ended yet");
        require(!campaign.claimed, "Funds already claimed");
        require(campaign.amountCollected >= campaign.targetAmount, "Campaign did not reach target");
        
        campaign.claimed = true;
        uint256 amountToSend = campaign.amountCollected;
        
        // Transfer funds to campaign creator using more secure pattern
        (bool sent, ) = payable(campaign.creator).call{value: amountToSend}("");
        require(sent, "Failed to send funds");
        
        emit FundsClaimed(_campaignId, campaign.creator, amountToSend);
    }
    
    /**
     * @dev Contributors claim refunds from an unsuccessful campaign
     * @param _campaignId ID of the campaign to claim refund from
     */
    function claimRefund(uint256 _campaignId) public {
        Campaign storage campaign = campaigns[_campaignId];
        uint256 contributionAmount = contributions[_campaignId][msg.sender];
        
        require(campaign.ended, "Campaign not ended yet");
        require(campaign.amountCollected < campaign.targetAmount, "Campaign was successful, no refunds");
        require(contributionAmount > 0, "No contribution to refund");
        
        // Reset contribution amount before transfer to prevent reentrancy
        contributions[_campaignId][msg.sender] = 0;
        
        // Transfer refund to contributor
        (bool sent, ) = payable(msg.sender).call{value: contributionAmount}("");
        require(sent, "Failed to send refund");
        
        emit RefundClaimed(_campaignId, msg.sender, contributionAmount);
    }
    
    /**
     * @dev Gets campaign details
     * @param _campaignId ID of the campaign
     * @return creator The address of the campaign creator
     * @return title The title of the campaign
     * @return description The description of the campaign
     * @return targetAmount The target amount to be raised
     * @return deadline The deadline of the campaign
     * @return amountCollected The total amount collected
     * @return ended Whether the campaign has ended
     * @return claimed Whether the funds have been claimed
     */
    function getCampaign(uint256 _campaignId) public view returns (
        address creator,
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        uint256 amountCollected,
        bool ended,
        bool claimed
    ) {
        Campaign storage campaign = campaigns[_campaignId];
        
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.targetAmount,
            campaign.deadline,
            campaign.amountCollected,
            campaign.ended,
            campaign.claimed
        );
    }
    
    /**
     * @dev Gets the number of contributors for a campaign
     * @param _campaignId ID of the campaign
     * @return Number of contributors
     */
    function getContributorsCount(uint256 _campaignId) public view returns (uint256) {
        return contributorsList[_campaignId].length;
    }
    
    /**
     * @dev Gets the contribution amount of a specific contributor
     * @param _campaignId ID of the campaign
     * @param _contributor Address of the contributor
     * @return Contribution amount
     */
    function getContribution(uint256 _campaignId, address _contributor) public view returns (uint256) {
        return contributions[_campaignId][_contributor];
    }
    
    /**
     * @dev Checks if a campaign is active
     * @param _campaignId ID of the campaign
     * @return True if campaign is active, false otherwise
     */
    function isCampaignActive(uint256 _campaignId) public view returns (bool) {
        Campaign storage campaign = campaigns[_campaignId];
        return (!campaign.ended && block.timestamp < campaign.deadline);
    }
    
    /**
     * @dev Get all contributors for a campaign
     * @param _campaignId ID of the campaign
     * @return Array of contributor addresses
     */
    function getContributors(uint256 _campaignId) public view returns (address[] memory) {
        return contributorsList[_campaignId];
    }
}
