/** 
                                     )    )          
                                  ( /( ( /(          
 (            (         (  (      )\()))\())     (   
 )\   (    (  )(    (   )\))(    ((_)\((_)\      )\  
((_)  )\   )\(()\   )\ ((_)()\  __ ((_) ((_)  _ ((_) 
| __|((_) ((_)((_) ((_)_(()((_) \ \ / // _ \ | | | | 
| _| (_-</ _|| '_|/ _ \\ V  V /  \ V /| (_) || |_| | 
|___|/__/\__||_|  \___/ \_/\_/    |_|  \___/  \___/ 

Web: https://

TG: https://t.me/

Twitter (X): https://twitter.com/

**/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Escrows {
    IERC20 private _EYOUContract;
    address private _owner;

    struct EscrowStruct {
        address certifier;
        uint256 timestamp;
        uint256 amount;
        uint256 certifierFees;
    }

    struct HoldStruct {
        uint256 threshold;
        uint8 fee;
    }

    mapping (address => mapping (address => mapping (uint256 => EscrowStruct))) public pendingEscrows;    
    mapping (address => mapping (address => uint16)) public escrowsCounter; 
    HoldStruct public holdEYOUTier1 = HoldStruct({threshold: 0, fee: 1});
    HoldStruct public holdEYOUTier2 = HoldStruct({threshold: 100 * 10**3 * 10**9, fee: 5});
    uint32 public releaseTime = 604800;

    event Escrow(address indexed from, address indexed to, address indexed certifier, uint16 escrowIndex, uint256 amount, string message);
    event Certify(address indexed from, address indexed to, address indexed certifier, uint16 escrowIndex, bool result);

    constructor() {
        _owner = msg.sender;
        _EYOUContract = IERC20(address(0));
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function sendEscrow(address to, address certifier, uint256 certifierFees, string calldata message) external payable {
        require(msg.value > 0, "No ETH sent");
        uint256 value = msg.value;

        if(msg.sender != _owner && _EYOUContract != IERC20(address(0))){
            require(_EYOUContract.balanceOf(msg.sender) >= holdEYOUTier1.threshold, "Insufficient EYOU balance");
            
            if(_EYOUContract.balanceOf(msg.sender) < holdEYOUTier2.threshold){
                value = value - (value * holdEYOUTier1.fee / 1000);
            }
            else{
                value = value - (value * holdEYOUTier2.fee / 10000);
            }
        }

        pendingEscrows[msg.sender][to][escrowsCounter[msg.sender][to]].amount = value;
        pendingEscrows[msg.sender][to][escrowsCounter[msg.sender][to]].certifier = certifier;
        pendingEscrows[msg.sender][to][escrowsCounter[msg.sender][to]].certifierFees = certifierFees;
        pendingEscrows[msg.sender][to][escrowsCounter[msg.sender][to]].timestamp = block.timestamp;
        
        emit Escrow(msg.sender, to, certifier, escrowsCounter[msg.sender][to], value, message);

        escrowsCounter[msg.sender][to]++;
    }

    function certify(address payable from, address payable to, uint16 escrowIndex, bool result) external {
        require(pendingEscrows[from][to][escrowIndex].certifier == msg.sender, "Certifier address not valid for this escrow");
        require(pendingEscrows[from][to][escrowIndex].amount > 0, "Escrow already processed");

        uint256 certifierAmount = pendingEscrows[from][to][escrowIndex].amount * pendingEscrows[from][to][escrowIndex].certifierFees / 100;
        uint256 amount = pendingEscrows[from][to][escrowIndex].amount - certifierAmount;

        if(result){
            to.transfer(amount);
        }
        else{
            from.transfer(amount);
        }
        payable(pendingEscrows[from][to][escrowIndex].certifier).transfer(certifierAmount);

        pendingEscrows[from][to][escrowIndex].amount = 0;
        
        emit Certify(from, to, pendingEscrows[from][to][escrowIndex].certifier, escrowIndex, result);
    }

    function checkReleaseTime(address to, uint64 escrowIndex) external view returns (uint256) {
        if(block.timestamp - pendingEscrows[msg.sender][to][escrowIndex].timestamp < releaseTime){
            return releaseTime - (block.timestamp - pendingEscrows[msg.sender][to][escrowIndex].timestamp);
        }
        return 0;
    }

    function releaseFunds(address to, uint64 escrowIndex) external {
        require(block.timestamp - pendingEscrows[msg.sender][to][escrowIndex].timestamp >= releaseTime, "Release time still in progress...");
        pendingEscrows[msg.sender][to][escrowIndex].amount = 0;
        payable(msg.sender).transfer(pendingEscrows[msg.sender][to][escrowIndex].amount);
    }

    function setEYOUAddress(address addr) external onlyOwner {
        _EYOUContract = IERC20(addr);
    }

    function setEYOUHoldLayer1(uint256 threshold, uint8 fee) external onlyOwner {
        holdEYOUTier1.threshold = threshold;
        holdEYOUTier1.fee = fee;
    }

    function setEYOUHoldLayer2(uint256 threshold, uint8 fee) external onlyOwner {
        holdEYOUTier2.threshold = threshold;
        holdEYOUTier2.fee = fee;
    }

    function withdraw() external onlyOwner {
        payable(_owner).transfer(address(this).balance);
    }

    function setReleaseTime(uint32 timeInSec) external onlyOwner {
        releaseTime = timeInSec;
    }
}