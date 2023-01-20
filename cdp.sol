pragma solidity ^0.8.17;


import "./rai.sol";
import "./auction.sol";


contract ERC20CDP {

    struct CDP {
        uint collateral;
        uint rai;
        bool exists;
    }

    uint public rub;
    uint public coll;
    ERC20Interface public collateralInstance;
    ERC20Interface public raiInstance;
    address public minter;
    mapping(address => mapping (bytes32 => CDP)) public cdps;

    event CdpUpdate(address indexed owner, bytes32 id, CDP cdp);

    constructor(
        address _rai,
        address _collateral,
        uint _rub, uint _col) {
        rub = _rub;
        coll = _col;
        raiInstance = ERC20Interface(_rai);
        collateralInstance = ERC20Interface(_collateral);
        minter = msg.sender;
    }

    function setRate(uint _rub, uint _col) public {
        require(msg.sender == minter);
        rub = _rub;
        coll = _col;
    }


    function open() external returns (bytes32 id)
    {
        id = keccak256(abi.encode(block.timestamp, block.difficulty, msg.sender));
        cdps[msg.sender][id] = CDP({collateral: 0, rai: 0, exists: true});
        emit CdpUpdate(msg.sender, id, cdps[msg.sender][id]);
    }

    function lock(uint amount, bytes32 id) external
    {
        require(cdps[msg.sender][id].exists, "this cdp doesn't exist");

        bool success = collateralInstance.transferFrom(msg.sender, address(this), amount);
        require(success, "buy failed"); 

        cdps[msg.sender][id].collateral += amount;

        emit CdpUpdate(msg.sender, id, cdps[msg.sender][id]);
    }

    function unlock(uint amount, bytes32 id) external
    {
        require(cdps[msg.sender][id].exists);
        require(cdps[msg.sender][id].collateral >= amount);
        require((cdps[msg.sender][id].collateral - amount) * rub > cdps[msg.sender][id].rai * coll);

        cdps[msg.sender][id].collateral -= amount;
        bool success = collateralInstance.transfer(msg.sender, amount);
        require(success, "transfer failed");

        emit CdpUpdate(msg.sender, id, cdps[msg.sender][id]);
    }

    function close(bytes32 id) external
    {
        require(cdps[msg.sender][id].exists);
        require(cdps[msg.sender][id].rai == 0);

        uint collateral = cdps[msg.sender][id].collateral;
        if (collateral > 0) {
            cdps[msg.sender][id].collateral = 0;
            bool success = collateralInstance.transfer(msg.sender, collateral);
            require(success);
        }

        cdps[msg.sender][id].exists = false;
        emit CdpUpdate(msg.sender, id, cdps[msg.sender][id]);
    }

    function mint(uint amount, bytes32 id) external
    {
        require(cdps[msg.sender][id].exists);
        require(cdps[msg.sender][id].collateral * rub > (cdps[msg.sender][id].rai + amount) * coll);

        cdps[msg.sender][id].rai += amount;
        bool success = raiInstance.transfer(msg.sender, amount);
        require(success, "transfer failed");
        emit CdpUpdate(msg.sender, id, cdps[msg.sender][id]);
    }

    function refund(uint amount, bytes32 id) external
    {
        require(cdps[msg.sender][id].exists);
        require(cdps[msg.sender][id].rai >= amount);
        
        bool success = raiInstance.transferFrom(msg.sender, address(this), amount);
        require(success, "transfer failed");

        cdps[msg.sender][id].rai -= amount;

        emit CdpUpdate(msg.sender, id, cdps[msg.sender][id]);
    }

    function liquidate(address addr, bytes32 id) external returns (address liqAddr)
    {
        require(cdps[addr][id].exists);
        require(cdps[addr][id].collateral * rub < cdps[addr][id].rai * coll);

        uint colAmount = cdps[addr][id].collateral;

        Auction liq = new Auction(address(raiInstance), address(collateralInstance), colAmount, address(this));

        collateralInstance.transfer(address(liq), colAmount);

        cdps[addr][id].exists = false;
        liqAddr = address(liq);
    }
}

