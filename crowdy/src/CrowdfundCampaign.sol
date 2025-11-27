// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CrowdfundCampaign {
    using SafeERC20 for IERC20;

    struct Campaign {
        address owner;
        uint256 goalAmount;
        uint256 deadline;
        string title;
        string description;
        // token => total raised
        mapping(address => uint256) totalRaised;
        // token => contributor => amount
        mapping(address => mapping(address => uint256)) contributions;
        address[] contributors;
        bool withdrawn;
    }

    Campaign[] public campaigns;

    event CampaignCreated(
        uint256 indexed id,
        address indexed owner,
        uint256 goalAmount,
        uint256 deadline,
        string title
    );

    event ContributionReceived(
        uint256 indexed campaignId,
        address indexed contributor,
        address indexed token,
        uint256 amount
    );

    event FundsWithdrawn(
        uint256 indexed campaignId,
        address token,
        uint256 amount
    );

    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        address indexed token,
        uint256 amount
    );

    function createCampaign(
        uint256 _goalAmount,
        uint256 _deadline,
        string calldata _title,
        string calldata _description
    ) external {
        require(_goalAmount > 0, "Goal > 0");
        require(_deadline > block.timestamp, "Deadline must be future");

        campaigns.push();
        Campaign storage c = campaigns[campaigns.length - 1];

        c.owner = msg.sender;
        c.goalAmount = _goalAmount;
        c.deadline = _deadline;
        c.title = _title;
        c.description = _description;

        emit CampaignCreated(
            campaigns.length - 1,
            msg.sender,
            _goalAmount,
            _deadline,
            _title
        );
    }

    /// @notice Contribute ETH (token = address(0))
    function contributeETH(uint256 campaignId) external payable {
        require(msg.value > 0, "No ETH sent");

        _contribute(campaignId, address(0), msg.value);
    }

    /// @notice Contribute ERC20 tokens (token = ERC20 address)
    function contributeToken(
        uint256 campaignId,
        address token,
        uint256 amount
    ) external {
        require(amount > 0, "Amount > 0");
        require(token != address(0), "Use contributeETH for ETH");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        _contribute(campaignId, token, amount);
    }

    function _contribute(
        uint256 campaignId,
        address token,
        uint256 amount
    ) internal {
        Campaign storage c = campaigns[campaignId];

        require(block.timestamp < c.deadline, "Campaign ended");

        // If first contribution from user → register user, check the amount of specific token
        if (c.contributions[token][msg.sender] == 0) {
            c.contributors.push(msg.sender);
        }

        c.contributions[token][msg.sender] += amount;
        c.totalRaised[token] += amount;

        emit ContributionReceived(campaignId, msg.sender, token, amount);
    }

    function withdraw(uint256 campaignId) external {
        Campaign storage c = campaigns[campaignId];

        require(msg.sender == c.owner, "Not owner");
        require(block.timestamp >= c.deadline, "Deadline not reached");
        require(!c.withdrawn, "Already withdrawn");
        require(c.totalRaised[address(0)] >= c.goalAmount, "ETH goal not met");

        c.withdrawn = true;

        uint256 ethAmount = c.totalRaised[address(0)];
        c.totalRaised[address(0)] = 0;

        (bool sent, ) = c.owner.call{value: ethAmount}("");
        require(sent, "ETH transfer failed");

        emit FundsWithdrawn(campaignId, address(0), ethAmount);
    }

    function refund(uint256 campaignId, address token) external {
        Campaign storage c = campaigns[campaignId];

        require(block.timestamp >= c.deadline, "Deadline not passed");
        require(!c.withdrawn, "Campaign already withdrawn");
        require(c.totalRaised[address(0)] < c.goalAmount, "Goal met no refund");

        uint256 contributed = c.contributions[token][msg.sender];
        require(contributed > 0, "No contributions");

        c.contributions[token][msg.sender] = 0;

        if (token == address(0)) {
            (bool sent, ) = msg.sender.call{value: contributed}("");
            require(sent, "ETH refund failed");
        } else {
            IERC20(token).safeTransfer(msg.sender, contributed);
        }

        emit RefundIssued(campaignId, msg.sender, token, contributed);
    }

    function getContribution(
        uint256 campaignId,
        address token,
        address contributor
    ) external view returns (uint256) {
        return campaigns[campaignId].contributions[token][contributor];
    }

    function getTotalRaised(
        uint256 campaignId,
        address token
    ) external view returns (uint256) {
        return campaigns[campaignId].totalRaised[token];
    }

    function totalCampaigns() external view returns (uint256) {
        return campaigns.length;
    }
}
