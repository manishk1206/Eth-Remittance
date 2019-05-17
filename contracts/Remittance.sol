pragma solidity ^0.5.0;

import "./Safemath.sol";
import "./Pausable.sol";

contract Remittance is Pausable {

    using Safemath for uint;

    event LogContractCreated (address indexed owner,uint indexed expireTime );
    event LogSendFunds(address indexed sender, uint indexed amount, uint expireTime);
    event LogWithdrawnFunds(address indexed beneficiary, uint indexed amount);
    event LogClaimedBackFunds(address indexed beneficiary, uint indexed amount);

    uint maxTimeLimit; //How far in the future the deadline can be, in seconds

    // A basic remittance structure
    struct remit{
        uint amount;
        address sender;
        address receiver;
        uint expiry;
        bytes32 hashedPwd;
    }

    mapping (bytes32 => remit) remitmap ; // stores all the remittances with key as 2-factor OTP hash

    // constructor
    constructor (uint _maxTime) public {
        require(_maxTime > 0, "Future deadline time > 0");
        maxTimeLimit = _maxTime;
        emit LogContractCreated(msg.sender,maxTimeLimit);
    }

    // Alice can deposit
    function sendRemit(bytes32 _hashOrig, uint _deadline, address _receiver ) public payable onlyIfRunning {

        require (msg.value > 0, "There should be some non-zero value to split" );
        require(_deadline < maxTimeLimit,"Please lower the expiry and try again" );

        // adding salt to the original hash
        bytes32 saltedHash = keccak256(abi.encodePacked(_hashOrig,address(this)));

        remit.amount = msg.value;
        remit.sender = msg.sender;
        remit.receiver = _receiver; // A hacker may know the hash, but he can't impersonate receiver
        remit.expiry = now + _deadline;
        remit.hashedPwd = saltedHash;

        remitmap[_hashOrig] = remit; // mapping to original hashed Password
        emit LogSendFunds(msg.sender,msg.value,_deadline);

     }

    // Carol can withdraw
    function withdrawRemit(bytes32 _hashOrig) public onlyIfRunning {

        // This is done to imply that ONLY this contract address is applicable for this particularRemittance
        // So, Even if the hacker knows _hashOrig, he cannot succed as his contract address will be different
        require (keccak256(abi.encodePacked(_hashOrig,address(this))) == remitmap[_hashOrig].hashedPwd,"Passwords mismatch, Withdrawal denied!");

        require (msg.sender == remitmap[_hashOrig].receiver,"Hey petty thief..You shall be punished!");
        require( now < remitmap[_hashOrig].expiry,"Sorry pal! Claiming Period Over. Call our office");

        uint balance = remitmap[_hashOrig].amount;
        require(balance > 0, "Balance zero. Either already Remitted or claimed");
        remitmap[_hashOrig].amount = 0;
        emit LogWithdrawnFunds(msg.sender,balance);
        msg.sender.transfer(balance);

    }

    // Alice can claim back after cutoff time has passed
    function claimBackRemit(bytes32 _hashOrig) public onlyIfRunning {

        require (keccak256(abi.encodePacked(_hashOrig,address(this))) == remitmap[_hashOrig].hashedPwd,"Passwords mismatch, Claimback denied!");
        require (msg.sender == remitmap[_hashOrig].sender,"You ain't the owner, Better luck next time :)");
        require( now > remitmap[_hashOrig].expiry,"Don't be too greedy, have patience!");

        uint balance = remitmap[_hashOrig].amount;
        require(balance > 0, "Balance zero. Either already Remitted or claimed");
        remitmap[_hashOrig].amount = 0;
        emit LogClaimedBackFunds(msg.sender,balance);
        msg.sender.transfer(balance);

    }

    // get the hash using Bob's sms and Carol's address, done off-chain
    function getOtpHash (bytes32 _smsOtp ,address _receiver) pure external returns(bytes32 hash){
        return keccak256(abi.encodePacked(_smsOtp, _receiver));
    }

    //fall-back function
    function() external {
        revert("Please check the function you are trying to call..");
    }
}
