pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./Pausable.sol";

contract Remittance is Pausable {

    using SafeMath for uint;

    event LogContractCreated (address indexed owner,uint indexed expireTime );
    event LogSendFunds(address indexed sender, uint indexed amount, uint expireTime);
    event LogWithdrawnFunds(address indexed beneficiary, uint indexed amount);
    event LogClaimedBackFunds(address indexed beneficiary, uint indexed amount);

    uint maxTimeLimit; //How far in the future the deadline can be, in seconds

    // A basic remittance structure
    struct Remit{
        uint amount;
        address sender;
        uint expiry;
    }

    mapping (bytes32 => Remit) remitmap ; // stores all the remittances with key as 2-factor OTP hash

    // constructor
    constructor (uint _maxTime, bool _initialState) Pausable(_initialState) public {
        require(_maxTime > 0, "Future deadline time > 0");
        maxTimeLimit = _maxTime;
        emit LogContractCreated(msg.sender, maxTimeLimit);
    }

    // Alice can deposit
    function sendRemit(bytes32 _hashedPwd, uint _deadline) public payable onlyIfAllowed onlyIfRunning {

        //Restricting use of duplicate passwords
        require (remitmap[_hashedPwd].sender == address(0), "Password already in use.");

        require (msg.value > 0, "There should be some non-zero value to split" );
        require(_deadline <= maxTimeLimit, "Please lower the expiry time and try again" );

        Remit.amount = msg.value;
        Remit.sender = msg.sender;
        Remit.expiry = now.add(_deadline);

        remitmap[_hashedPwd] = Remit; // mapping to original hashed Password
        emit LogSendFunds(msg.sender, msg.value, _deadline);

     }

    // Carol can withdraw
    function withdrawRemit(bytes32 _smsOtp) public onlyIfRunning {

       bytes32 hashedPwd =  this.getOtpHash (_smsOtp , msg.sender);
     //   require( now < remitmap[hashedPwd].expiry, "Sorry pal! Claiming Period Over. Call our office");

        uint balance = remitmap[hashedPwd].amount;
        require(balance > 0, "Balance zero. Either already Remitted or claimed");
        remitmap[hashedPwd].amount = 0;
        remitmap[_hashedPwd].expiry = 0;
        emit LogWithdrawnFunds(msg.sender, balance);
        msg.sender.transfer(balance);

    }

    // Alice can claim back after cutoff time has passed
    function claimBackRemit(bytes32 _hashedPwd) public onlyIfRunning {

        require (msg.sender == remitmap[_hashedPwd].sender, "You ain't the owner, Better luck next time :)");
        require( now > remitmap[_hashedPwd].expiry, "Don't be too greedy, the cutoff time is not reached!");

        uint balance = remitmap[_hashedPwd].amount;
        require(balance > 0, "Balance zero. Either already Remitted or claimed");
        remitmap[_hashedPwd].amount = 0;
        remitmap[_hashedPwd].expiry = 0;
        emit LogClaimedBackFunds(msg.sender, balance);
        msg.sender.transfer(balance);

    }

    // get the hash using Bob's sms and Carol's address, done off-chain
    function getOtpHash (bytes32 _smsOtp , address _receiver) pure external returns(bytes32 hash){
        return keccak256(abi.encodePacked(_smsOtp, _receiver, address(this)));
    }

    //fall-back function
    function() external {
        revert("Please check the function you are trying to call..");
    }
}
