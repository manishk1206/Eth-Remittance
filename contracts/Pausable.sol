pragma solidity ^0.5.0;

import "./Ownable.sol";

contract Pausable is Ownable{
    bool private isRunning;
    
    event LogPausedContract(address sender);
    event LogResumedContract(address sender);
    
    modifier onlyIfRunning {
        require(isRunning);
        _;
    }
    
    modifier onlyIfPaused {
        require(!isRunning);
        _;
    }
    
    constructor(bool _state) public{
        isRunning = _state;
    }

    function getisRunning() public view returns(bool){
        return isRunning;
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
    
    function kill() external onlyOwner onlyIfPaused {
        selfdestruct(msg.sender); 
    }
}
