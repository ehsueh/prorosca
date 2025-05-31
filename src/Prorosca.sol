// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Prorosca {
    struct Circle {
        string name;
        uint256 contributionAmount;
        uint256 totalParticipants;
        uint256 durationInDays;
        address[] participants;
        bool isActive;
        uint256 startTime;
        uint256 nextPayoutTime;
        uint256 currentRound;
    }

    mapping(uint256 => Circle) public circles;
    uint256 public circleCount;
    mapping(uint256 => mapping(address => bool)) public hasContributed;
    mapping(uint256 => mapping(uint256 => address)) public roundWinners;

    event CircleCreated(uint256 indexed circleId, string name, uint256 contributionAmount);
    event ContributionMade(uint256 indexed circleId, address indexed contributor);
    event WinnerSelected(uint256 indexed circleId, uint256 indexed round, address winner);

    function createCircle(
        string memory name,
        uint256 contributionAmount,
        uint256 totalParticipants,
        uint256 durationInDays
    ) public returns (uint256) {
        require(totalParticipants > 1, "Need at least 2 participants");
        require(durationInDays > 0, "Duration must be positive");
        require(contributionAmount > 0, "Contribution must be positive");

        uint256 circleId = circleCount++;
        Circle storage circle = circles[circleId];
        
        circle.name = name;
        circle.contributionAmount = contributionAmount;
        circle.totalParticipants = totalParticipants;
        circle.durationInDays = durationInDays;
        circle.isActive = true;
        circle.startTime = block.timestamp;
        circle.nextPayoutTime = block.timestamp + (durationInDays * 1 days);
        circle.currentRound = 0;

        emit CircleCreated(circleId, name, contributionAmount);
        return circleId;
    }

    function contribute(uint256 circleId) public payable {
        Circle storage circle = circles[circleId];
        require(circle.isActive, "Circle is not active");
        require(msg.value == circle.contributionAmount, "Incorrect contribution amount");
        require(!hasContributed[circleId][msg.sender], "Already contributed this round");
        require(circle.participants.length < circle.totalParticipants, "Circle is full");

        circle.participants.push(msg.sender);
        hasContributed[circleId][msg.sender] = true;

        emit ContributionMade(circleId, msg.sender);

        if (circle.participants.length == circle.totalParticipants) {
            selectWinner(circleId);
        }
    }

    function selectWinner(uint256 circleId) internal {
        Circle storage circle = circles[circleId];
        require(circle.isActive, "Circle is not active");
        require(circle.participants.length == circle.totalParticipants, "Not enough participants");

        // Simple random selection for demo purposes
        // In production, use a more secure randomness source
        uint256 winnerIndex = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            circle.currentRound
        ))) % circle.participants.length;

        address winner = circle.participants[winnerIndex];
        roundWinners[circleId][circle.currentRound] = winner;

        // Transfer the pool to the winner
        uint256 poolAmount = circle.contributionAmount * circle.totalParticipants;
        payable(winner).transfer(poolAmount);

        emit WinnerSelected(circleId, circle.currentRound, winner);

        // Reset for next round
        delete circle.participants;
        circle.currentRound++;
        circle.nextPayoutTime += circle.durationInDays * 1 days;

        // Clear contribution records for all participants
        for (uint256 i = 0; i < circle.totalParticipants; i++) {
            hasContributed[circleId][circle.participants[i]] = false;
        }

        // Check if all rounds are complete
        if (circle.currentRound >= circle.totalParticipants) {
            circle.isActive = false;
        }
    }

    function getCircleInfo(uint256 circleId) public view returns (
        string memory name,
        uint256 contributionAmount,
        uint256 totalParticipants,
        uint256 durationInDays,
        bool isActive,
        uint256 startTime,
        uint256 nextPayoutTime,
        uint256 currentRound,
        uint256 currentParticipants
    ) {
        Circle storage circle = circles[circleId];
        return (
            circle.name,
            circle.contributionAmount,
            circle.totalParticipants,
            circle.durationInDays,
            circle.isActive,
            circle.startTime,
            circle.nextPayoutTime,
            circle.currentRound,
            circle.participants.length
        );
    }

    function getParticipants(uint256 circleId) public view returns (address[] memory) {
        return circles[circleId].participants;
    }
} 