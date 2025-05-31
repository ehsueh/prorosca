// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Prorosca {
    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }

    struct Sail {
        string name;
        uint256 monthlyPrincipal;
        uint256 totalCrewmates;
        uint256 durationInDays;
        address[] crewmates;
        address captain;
        bool isSailing;
        uint256 startTime;
        uint256 nextPayoutTime;
        uint256 currentRound;
        Bid highestBid;
        mapping(address => bool) hasContributed;
        mapping(uint256 => address) roundWinners;
        mapping(address => uint256) contributions;
    }

    mapping(uint256 => Sail) public sails;
    uint256 public sailCount;

    event SailLaunched(
        uint256 indexed sailId,
        string name,
        address captain,
        uint256 monthlyPrincipal
    );
    event CrewmateJoined(uint256 indexed sailId, address indexed crewmate);
    event BidPlaced(
        uint256 indexed sailId,
        address indexed bidder,
        uint256 amount
    );
    event RoundCompleted(
        uint256 indexed sailId,
        uint256 indexed round,
        address winner,
        uint256 amount
    );
    event SailAbandoned(uint256 indexed sailId, address captain);

    modifier onlyCaptain(uint256 sailId) {
        require(
            msg.sender == sails[sailId].captain,
            "Only the captain can call this"
        );
        _;
    }

    modifier onlyCrewmate(uint256 sailId) {
        bool isCrewmate = false;
        for (uint256 i = 0; i < sails[sailId].crewmates.length; i++) {
            if (sails[sailId].crewmates[i] == msg.sender) {
                isCrewmate = true;
                break;
            }
        }
        require(isCrewmate, "Only crewmates can call this");
        _;
    }

    function launchSail(
        string memory name,
        uint256 monthlyPrincipal,
        uint256 totalCrewmates,
        uint256 durationInDays
    ) public returns (uint256) {
        require(totalCrewmates > 1, "Need at least 2 crewmates");
        require(durationInDays > 0, "Duration must be positive");
        require(monthlyPrincipal > 0, "Principal must be positive");

        uint256 sailId = sailCount++;
        Sail storage sail = sails[sailId];

        sail.name = name;
        sail.monthlyPrincipal = monthlyPrincipal;
        sail.totalCrewmates = totalCrewmates;
        sail.durationInDays = durationInDays;
        sail.captain = msg.sender;
        sail.isSailing = true;
        sail.startTime = block.timestamp;
        sail.nextPayoutTime = block.timestamp + (durationInDays * 1 days);
        sail.currentRound = 0;

        // Captain is the first crewmate
        sail.crewmates.push(msg.sender);

        emit SailLaunched(sailId, name, msg.sender, monthlyPrincipal);
        return sailId;
    }

    function joinSail(uint256 sailId) public payable {
        Sail storage sail = sails[sailId];
        require(sail.isSailing, "This sail is not active");
        require(
            msg.value == sail.monthlyPrincipal,
            "Must contribute monthly principal"
        );
        require(
            sail.crewmates.length < sail.totalCrewmates,
            "Crew is already full"
        );

        // Check if already a crewmate
        for (uint256 i = 0; i < sail.crewmates.length; i++) {
            require(
                sail.crewmates[i] != msg.sender,
                "Already part of the crew"
            );
        }

        sail.crewmates.push(msg.sender);
        sail.contributions[msg.sender] = msg.value;
        emit CrewmateJoined(sailId, msg.sender);
    }

    function placeBid(uint256 sailId, uint256 bidAmount) public onlyCrewmate(sailId) {
        Sail storage sail = sails[sailId];
        require(sail.isSailing, "This sail is not active");
        require(
            block.timestamp < sail.nextPayoutTime,
            "Bidding period has ended"
        );
        require(
            bidAmount > sail.highestBid.amount,
            "Bid must be higher than current highest"
        );
        require(
            sail.contributions[msg.sender] >= sail.monthlyPrincipal,
            "Must contribute monthly principal first"
        );

        sail.highestBid = Bid({
            bidder: msg.sender,
            amount: bidAmount,
            timestamp: block.timestamp
        });

        emit BidPlaced(sailId, msg.sender, bidAmount);
    }

    function completeRound(uint256 sailId) public {
        Sail storage sail = sails[sailId];
        require(sail.isSailing, "This sail is not active");
        require(
            block.timestamp >= sail.nextPayoutTime,
            "Round is not over yet"
        );
        require(
            sail.crewmates.length == sail.totalCrewmates,
            "Crew not full yet"
        );

        address winner = sail.highestBid.bidder;
        uint256 payout = sail.monthlyPrincipal * sail.totalCrewmates;

        // Record winner and reset for next round
        sail.roundWinners[sail.currentRound] = winner;
        
        // Transfer the pool to the winner
        payable(winner).transfer(payout);

        emit RoundCompleted(
            sailId,
            sail.currentRound,
            winner,
            payout
        );

        // Reset for next round
        sail.currentRound++;
        sail.nextPayoutTime += sail.durationInDays * 1 days;
        sail.highestBid = Bid(address(0), 0, 0);

        // Reset contributions tracking
        for (uint256 i = 0; i < sail.crewmates.length; i++) {
            sail.contributions[sail.crewmates[i]] = 0;
        }

        // Check if all rounds are complete
        if (sail.currentRound >= sail.totalCrewmates) {
            sail.isSailing = false;
        }
    }

    function abandonShip(uint256 sailId) public onlyCaptain(sailId) {
        Sail storage sail = sails[sailId];
        require(sail.isSailing, "This sail is not active");
        
        // Return remaining funds to crewmates
        for (uint256 i = 0; i < sail.crewmates.length; i++) {
            address crewmate = sail.crewmates[i];
            uint256 contribution = sail.contributions[crewmate];
            if (contribution > 0) {
                payable(crewmate).transfer(contribution);
            }
        }

        sail.isSailing = false;
        emit SailAbandoned(sailId, msg.sender);
    }

    // View functions
    function getSailInfo(uint256 sailId)
        public
        view
        returns (
            string memory name,
            uint256 monthlyPrincipal,
            uint256 totalCrewmates,
            uint256 durationInDays,
            bool isSailing,
            uint256 startTime,
            uint256 nextPayoutTime,
            uint256 currentRound,
            uint256 currentCrewmates,
            address captain,
            address highestBidder,
            uint256 highestBid
        )
    {
        Sail storage sail = sails[sailId];
        return (
            sail.name,
            sail.monthlyPrincipal,
            sail.totalCrewmates,
            sail.durationInDays,
            sail.isSailing,
            sail.startTime,
            sail.nextPayoutTime,
            sail.currentRound,
            sail.crewmates.length,
            sail.captain,
            sail.highestBid.bidder,
            sail.highestBid.amount
        );
    }

    function getCrewmates(uint256 sailId) public view returns (address[] memory) {
        return sails[sailId].crewmates;
    }

    function getRoundWinner(uint256 sailId, uint256 round)
        public
        view
        returns (address)
    {
        return sails[sailId].roundWinners[round];
    }

    function getContribution(uint256 sailId, address crewmate)
        public
        view
        returns (uint256)
    {
        return sails[sailId].contributions[crewmate];
    }
} 