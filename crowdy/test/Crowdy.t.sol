// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CrowdfundCampaign.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("TestToken", "TT") {
        _mint(msg.sender, 1000 ether);
    }
}

contract CrowdyTest is Test {
    CrowdfundCampaign public campaign;
    TestToken public token;

    address owner = address(0xA1);
    address user1 = address(0xB1);
    address user2 = address(0xC1);

    function setUp() public {
        vm.prank(owner);
        campaign = new CrowdfundCampaign();

        token = new TestToken();
        token.transfer(user1, 100 ether);
        token.transfer(user2, 100 ether);

        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function test_CreateCampaign_Works() public {
        vm.prank(owner);
        campaign.createCampaign(
            5 ether,
            block.timestamp + 1000,
            "Test",
            "Desc"
        );
        assertEq(campaign.totalCampaigns(), 1);
    }

    function test_ContributeETH_Works() public {
        vm.prank(owner);
        campaign.createCampaign(5 ether, block.timestamp + 1000, "A", "B");

        vm.prank(user1);
        campaign.contributeETH{value: 1 ether}(0);

        uint256 c = campaign.getContribution(0, address(0), user1);
        assertEq(c, 1 ether);
    }

    function test_RevertWhen_ContributeETH_Zero() public {
        vm.prank(owner);
        campaign.createCampaign(5 ether, block.timestamp + 1000, "A", "B");

        vm.prank(user1);
        vm.expectRevert("No ETH sent");
        campaign.contributeETH{value: 0}(0);
    }

    function test_RevertWhen_ContributeETH_AfterDeadline() public {
        vm.prank(owner);
        campaign.createCampaign(5 ether, block.timestamp + 10, "A", "B");

        vm.warp(block.timestamp + 20);

        vm.prank(user1);
        vm.expectRevert("Campaign ended");
        campaign.contributeETH{value: 1 ether}(0);
    }

    function test_ContributeToken_Works() public {
        vm.prank(owner);
        campaign.createCampaign(5 ether, block.timestamp + 1000, "A", "B");

        vm.startPrank(user1);
        token.approve(address(campaign), 5 ether);
        campaign.contributeToken(0, address(token), 5 ether);
        vm.stopPrank();

        uint256 c = campaign.getContribution(0, address(token), user1);
        assertEq(c, 5 ether);
    }

    function test_RevertWhen_ContributeToken_Zero() public {
        vm.prank(owner);
        campaign.createCampaign(5 ether, block.timestamp + 1000, "A", "B");

        vm.prank(user1);
        token.approve(address(campaign), 0);
        vm.expectRevert("Amount > 0");
        campaign.contributeToken(0, address(token), 0);
    }

    function test_RevertWhen_ContributeToken_EthAddress() public {
        vm.prank(owner);
        campaign.createCampaign(5 ether, block.timestamp + 1000, "A", "B");

        vm.prank(user1);
        token.approve(address(campaign), 1 ether);
        vm.expectRevert("Use contributeETH for ETH");
        campaign.contributeToken(0, address(0), 1 ether);
    }

    function test_WithdrawETH_WorksWhenGoalMet() public {
        vm.prank(owner);
        campaign.createCampaign(1 ether, block.timestamp + 10, "A", "B");

        vm.prank(user1);
        campaign.contributeETH{value: 1 ether}(0);

        vm.warp(block.timestamp + 20);

        uint256 before = owner.balance;
        vm.prank(owner);
        campaign.withdraw(0);
        assertGt(owner.balance, before);
    }

    function test_RevertWhen_WithdrawETHBeforeDeadline() public {
        vm.prank(owner);
        campaign.createCampaign(1 ether, block.timestamp + 100, "A", "B");

        vm.prank(user1);
        campaign.contributeETH{value: 1 ether}(0);

        vm.prank(owner);
        vm.expectRevert("Deadline not reached");
        campaign.withdraw(0);
    }

    function test_RevertWhen_WithdrawETHGoalNotMet() public {
        vm.prank(owner);
        campaign.createCampaign(5 ether, block.timestamp + 10, "A", "B");

        vm.prank(user1);
        campaign.contributeETH{value: 1 ether}(0);

        vm.warp(block.timestamp + 20);

        vm.prank(owner);
        vm.expectRevert("ETH goal not met");
        campaign.withdraw(0);
    }

    function test_RefundETH_Works() public {
        vm.prank(owner);
        campaign.createCampaign(5 ether, block.timestamp + 10, "A", "B");

        vm.prank(user1);
        campaign.contributeETH{value: 1 ether}(0);

        vm.warp(block.timestamp + 20);

        uint256 before = user1.balance;
        vm.prank(user1);
        campaign.refund(0, address(0));
        assertEq(user1.balance, before + 1 ether);
    }

    function test_RefundToken_Works() public {
        vm.prank(owner);
        campaign.createCampaign(5 ether, block.timestamp + 10, "A", "B");

        vm.startPrank(user1);
        token.approve(address(campaign), 5 ether);
        campaign.contributeToken(0, address(token), 5 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 20);

        uint256 before = token.balanceOf(user1);
        vm.prank(user1);
        campaign.refund(0, address(token));
        assertEq(token.balanceOf(user1), before + 5 ether);
    }

    function test_RevertWhen_Withdraw_NotOwner() public {
        vm.prank(owner);
        campaign.createCampaign(1 ether, block.timestamp + 10, "A", "B");

        vm.prank(user1);
        campaign.contributeETH{value: 1 ether}(0);

        vm.warp(block.timestamp + 20);

        vm.prank(user1);
        vm.expectRevert("Not owner");
        campaign.withdraw(0);
    }

    function test_RevertWhen_Withdraw_AlreadyWithdrawn() public {
        vm.prank(owner);
        campaign.createCampaign(1 ether, block.timestamp + 10, "A", "B");

        vm.prank(user1);
        campaign.contributeETH{value: 1 ether}(0);

        vm.warp(block.timestamp + 20);

        vm.prank(owner);
        campaign.withdraw(0);

        vm.prank(owner);
        vm.expectRevert("Already withdrawn");
        campaign.withdraw(0);
    }

    function test_RevertWhen_Refund_DoubleRefund() public {
        vm.prank(owner);
        campaign.createCampaign(5 ether, block.timestamp + 10, "A", "B");

        vm.prank(user1);
        campaign.contributeETH{value: 1 ether}(0);

        vm.warp(block.timestamp + 20);

        vm.prank(user1);
        campaign.refund(0, address(0));

        vm.prank(user1);
        vm.expectRevert("No contributions");
        campaign.refund(0, address(0));
    }

    function test_RevertWhen_Refund_BeforeDeadline() public {
        vm.prank(owner);
        campaign.createCampaign(5 ether, block.timestamp + 100, "A", "B");

        vm.prank(user1);
        campaign.contributeETH{value: 1 ether}(0);

        vm.prank(user1);
        vm.expectRevert("Deadline not passed");
        campaign.refund(0, address(0));
    }

    function test_RevertWhen_Refund_GoalMet() public {
        vm.prank(owner);
        campaign.createCampaign(1 ether, block.timestamp + 10, "A", "B");

        vm.prank(user1);
        campaign.contributeETH{value: 1 ether}(0);

        vm.warp(block.timestamp + 20);

        vm.prank(user1);
        vm.expectRevert("Goal met no refund");
        campaign.refund(0, address(0));
    }

    function test_EdgeCase_DeadlineExactlyAtBlockTimestamp() public {
        vm.prank(owner);
        uint256 deadline = block.timestamp + 10;
        campaign.createCampaign(5 ether, deadline, "A", "B");

        vm.prank(user1);
        campaign.contributeETH{value: 1 ether}(0);

        vm.warp(deadline);
        vm.prank(user2);
        vm.expectRevert("Campaign ended");
        campaign.contributeETH{value: 1 ether}(0);

        // But should be able to refund
        vm.prank(user1);
        campaign.refund(0, address(0));
    }

    function test_EdgeCase_MultipleContributions() public {
        vm.prank(owner);
        campaign.createCampaign(5 ether, block.timestamp + 1000, "A", "B");

        vm.prank(user1);
        campaign.contributeETH{value: 1 ether}(0);

        vm.prank(user1);
        campaign.contributeETH{value: 2 ether}(0);

        uint256 total = campaign.getContribution(0, address(0), user1);
        assertEq(total, 3 ether);
    }

    function test_EdgeCase_MultipleContributors() public {
        vm.prank(owner);
        campaign.createCampaign(5 ether, block.timestamp + 10, "A", "B");

        vm.prank(user1);
        campaign.contributeETH{value: 1 ether}(0);

        vm.prank(user2);
        campaign.contributeETH{value: 2 ether}(0);

        vm.warp(block.timestamp + 20);

        // Both should be able to refund
        vm.prank(user1);
        campaign.refund(0, address(0));

        vm.prank(user2);
        campaign.refund(0, address(0));
    }

    function test_CampaignLockedAfterWithdrawal() public {
        vm.prank(owner);
        campaign.createCampaign(1 ether, block.timestamp + 10, "A", "B");

        vm.prank(user1);
        campaign.contributeETH{value: 1 ether}(0);

        vm.warp(block.timestamp + 20);

        vm.prank(owner);
        campaign.withdraw(0);

        vm.prank(user1);
        vm.expectRevert("Campaign already withdrawn");
        campaign.refund(0, address(0));
    }
}
