pragma solidity ^0.5.0;

import "./Ownable.sol";

contract Pausable is Ownable{
    bool private isRunning;
    bool private depositAllowed = true;
    
    event LogPausedContract(address sender);
    event LogResumedContract(address sender);
    event LogPausedDeposit(address sender);
    
    modifier onlyIfRunning {
        require(isRunning);
        _;
    }
    
    modifier onlyIfPaused {
        require(!isRunning);
        _;
    }
    
    modifier onlyIfAllowed {
        require(depositAllowed);
        _;
    }
    
    constructor(bool _initialState) public{
        isRunning = _initialState;
    }

    function getIsRunning() public view returns(bool){
        return isRunning;
    }
    
    function getDepositAllowed() public view returns(bool){
        return depositAllowed;
    }
    
    function pauseContract() public onlyOwner onlyIfRunning returns (bool success){
        isRunning = false;
        emit LogPausedContract(msg.sender);
        return true;
    }
    
    function resumeContract() public onlyOwner onlyIfPaused returns (bool success){
        isRunning = true;
        emit LogResumedContract(msg.sender);
        return true;
    }
    
    function pauseDeposit() public onlyOwner returns (bool success){
        depositAllowed = false;
        emit LogPausedDeposit(msg.sender);
        return true;
    }
    
    function kill() external onlyOwner onlyIfPaused {
        selfdestruct(msg.sender); 
    }
}
