pragma solidity ^0.8.17;

import "./rai.sol";


contract Auction {
    uint public end;
    uint public prize;
    address public best_participant;
    mapping (address => uint) public bids;
    ERC20Interface public raiInstance;
    ERC20Interface public collateralInstance;
    address public cdpAddr;

    event Bid(address indexed bidder, uint amount);

    constructor(address _rai, address _col, uint _prize, address _cdpAddr) {
        end = block.timestamp + 5 minutes;
        best_participant = address(0);
        raiInstance = ERC20Interface(_rai);
        collateralInstance = ERC20Interface(_col);
        prize = _prize;
        cdpAddr = _cdpAddr;
    }

    function bid(uint amount) external {
        require(block.timestamp < end);

        bool success = raiInstance.transferFrom(msg.sender, address(this), amount);
        require(success);

        bids[msg.sender] += amount;

        if (best_participant == address(0) || bids[msg.sender] > bids[best_participant]) {
            best_participant = msg.sender;
        }
        emit Bid(msg.sender, bids[msg.sender]);
    }

    function withdraw(uint amount) external {
        require(block.timestamp > end);
        require(msg.sender != best_participant);
        require(bids[msg.sender] >= amount);

        bids[msg.sender] -= amount;
        bool success = raiInstance.transfer(msg.sender, amount);
        require(success);
    }

    function withdraw_prize(uint amount) external {
        require(block.timestamp > end);
        require(msg.sender == best_participant);
        require(amount <= prize);

        prize -= amount;
        bool success = collateralInstance.transfer(msg.sender, amount);
        require(success);
    }

    function exit() external {
        require(block.timestamp > end);
        require(best_participant != address(0));

        uint amount = bids[best_participant];
        require(amount > 0);

        bids[best_participant] = 0;

        bool success = raiInstance.transfer(cdpAddr, amount);
        require(success);
    }
}
