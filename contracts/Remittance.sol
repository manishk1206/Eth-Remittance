pragma solidity ^0.5.0;

import "./Safemath.sol";
import "./Pausable.sol";

contract Remittance is Pausable {
    
    using Safemath for uint;
    
    event LogContractCreated (address indexed owner,uint indexed expireTime );
    event LogSendFunds(address indexed sender,address indexed beneiciary, uint indexed amount);
    event LogWithdrawnFunds(address indexed beneficiary, uint indexed amount);
    event LogClaimedBackFunds(address indexed beneficiary, uint indexed amount);
    
    uint maxTimeLimit; //How far in the future the deadline can be, in seconds
    
    // A basic remittance structure
    struct remit{
        uint amount;
        address sender;
        address receiver;
        uint cutoffTime;
        bool claimed;
        uint timestamp;
    }
    
    mapping (bytes32 => remit) remitmap ; // stores all the remittances with key as 2-factor OTP hash
    
    // constructor
    constructor (uint _maxTime) public {
        require(_maxTime > 0, "Future deadline time > 0");
        maxTimeLimit = _maxTime;
        emit LogContractCreated(msg.sender,maxTimeLimit);
    }
    
    // Alice can deposit where _smsOtp and _receiver are the two OTPs
    // We can run either in "send" or "claim" mode
    function sendOrClaimBack(bool sendMode, uint _smsOtp ,address _receiver, uint _cutoffTime ) public payable onlyIfRunning {
        
        require( _receiver != address(0), "Receiver should have a valid address");
        
        bytes32 hashedPwd = getOtpHash(_smsOtp,_receiver);
        
        if (sendMode == true) {
            
        require ( msg.value > 0, "There should be some non-zero value to split" ); 
        require(_cutoffTime < maxTimeLimit,"Please lower the cutoffTime and try again" );
        remit.amount = msg.value;
        remit.sender = msg.sender;
        remit.receiver = _receiver;
        remit.cutoffTime = _cutoffTime;
        remit.claimed = false;
        remit.timestamp = now;
        
        remitmap[hashedPwd] = remit;
        emit LogSendFunds(msg.sender,_receiver,msg.value);
        }
        
        else { //meaning sendMode = false i.e claim mode on
        
            if (remitmap[hashedPwd].claimed == false   //Not claimed till now
            && ((now - remitmap[hashedPwd].timestamp) > remitmap[hashedPwd].cutoffTime)) // and Claiming period is over
            {
                uint balance = remitmap[hashedPwd].amount;
                remitmap[hashedPwd].amount = 0;
                remitmap[hashedPwd].claimed = true;
                msg.sender.transfer(balance);   //Claimed back by the owner
                emit LogClaimedBackFunds(msg.sender,balance);
            }
        }
     }
    
    // Carol can withdraw
    function withdrawRemit(uint _smsOtp) public onlyIfRunning {
        
        bytes32 hashedPwd = getOtpHash(_smsOtp,msg.sender);
        
        uint balance = remitmap[hashedPwd].amount;
        require(balance > 0, "No matching balance found. Please recheck the OTP and try again.");
        
        remitmap[hashedPwd].amount = 0;
        remitmap[hashedPwd].claimed = true;
        require((now - remitmap[hashedPwd].timestamp) < remitmap[hashedPwd].cutoffTime,"Sorry pal! Claiming Period Over.");
        
        msg.sender.transfer(balance);
        emit LogWithdrawnFunds(msg.sender,balance); // Good time to notify Alice by sending sms, say
    }
    
    // get the hash for the otp using the parameters
    function getOtpHash (uint _smsOtp ,address _receiver) public returns(bytes32 hash){
        return keccak256(abi.encodePacked(_smsOtp, _receiver));
    }

    //fall-back function
    function() external {
        revert("Please check the function you are trying to call..");
    }
}



