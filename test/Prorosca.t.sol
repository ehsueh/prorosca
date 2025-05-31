// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Prorosca.sol";

contract ProroscaTest is Test {
    Prorosca public prorosca;
    address public alice = address(1);
    address public bob = address(2);
    address public charlie = address(3);

    function setUp() public {
        prorosca = new Prorosca();
        // Fund test accounts
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
    }

    function testCreateCircle() public {
        uint256 circleId = prorosca.createCircle("Test Circle", 1 ether, 3, 30);
        
        (
            string memory name,
            uint256 contributionAmount,
            uint256 totalParticipants,
            uint256 durationInDays,
            bool isActive,
            ,
            ,
            uint256 currentRound,
            uint256 currentParticipants
        ) = prorosca.getCircleInfo(circleId);

        assertEq(name, "Test Circle");
        assertEq(contributionAmount, 1 ether);
        assertEq(totalParticipants, 3);
        assertEq(durationInDays, 30);
        assertTrue(isActive);
        assertEq(currentRound, 0);
        assertEq(currentParticipants, 0);
    }

    function testContribute() public {
        uint256 circleId = prorosca.createCircle("Test Circle", 1 ether, 3, 30);

        vm.prank(alice);
        prorosca.contribute{value: 1 ether}(circleId);

        vm.prank(bob);
        prorosca.contribute{value: 1 ether}(circleId);

        (, , , , , , , , uint256 currentParticipants) = prorosca.getCircleInfo(circleId);
        assertEq(currentParticipants, 2);

        address[] memory participants = prorosca.getParticipants(circleId);
        assertEq(participants[0], alice);
        assertEq(participants[1], bob);
    }

    function testFullCircleAndWinner() public {
        uint256 circleId = prorosca.createCircle("Test Circle", 1 ether, 3, 30);

        vm.prank(alice);
        prorosca.contribute{value: 1 ether}(circleId);

        vm.prank(bob);
        prorosca.contribute{value: 1 ether}(circleId);

        vm.prank(charlie);
        prorosca.contribute{value: 1 ether}(circleId);

        (, , , , , , , uint256 currentRound, uint256 currentParticipants) = prorosca.getCircleInfo(circleId);
        assertEq(currentRound, 1); // Should have completed first round
        assertEq(currentParticipants, 0); // Should have reset participants
    }

    function testFailDoubleContribute() public {
        uint256 circleId = prorosca.createCircle("Test Circle", 1 ether, 3, 30);

        vm.prank(alice);
        prorosca.contribute{value: 1 ether}(circleId);

        vm.prank(alice);
        prorosca.contribute{value: 1 ether}(circleId); // Should fail
    }

    function testFailIncorrectAmount() public {
        uint256 circleId = prorosca.createCircle("Test Circle", 1 ether, 3, 30);

        vm.prank(alice);
        prorosca.contribute{value: 0.5 ether}(circleId); // Should fail
    }
} 