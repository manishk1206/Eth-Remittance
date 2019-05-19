const Remittance = artifacts.require("Remittance");
const truffleAssert = require('truffle-assertions');

contract("Remittance contract main test cases", accounts => {
	const [owner, account1, account2, account3] = accounts;
	let instance;

	beforeEach('Deploying fresh contract instance before each test', async function () {
        instance = await Remittance.new(1296000,true, {from:owner}); // 1296000 is  maxTimeLimit of 15 days in seconds
    })

    it("Revert invalid attempts to send funds", async () => {

        // revert when value is 0
        await truffleAssert.fails(
            instance.sendRemit("asdf123", 604800, { from: account1, value: 0 })
        );

        // revert when passed cutOffTime > maxTimeLimit set by contract creator
        await truffleAssert.fails(
        instance.sendRemit("xyz456",1296001, { from: account1, value: 10 })
        );
    });


    it("should be able to SEND funds for remittance", async () => {

        //Creating a remittance and capturing the transaction object
        const txObj = await instance.sendRemit("asdf123", 604800, { from: account1, value: 10 })        
        // Check if transaction status is true
        assert.isTrue(txObj.receipt.status, "Transaction failed..Could not send funds")     
        // check event and its values
        const event = getEventResult(txObj, "LogSendFunds");
        assert.isDefined(event, "it should emit LogSendFunds");
        assert.strictEqual(event.sender, account1, "event: sender not valid");
        assert.strictEqual(event.amount.toString(), "10", "event: amount not valid");
        assert.strictEqual(event.expireTime.toString(), "604800", "event: deadline not valid")      
        // Check for data i.e if the remittance order was created
        const Remitmap = await instance.remitmap.call("asdf123", {from: account1});
        assert.strictEqual(Remitmap.sender, account1, "sender not valid");
        assert.strictEqual(Remitmap.amount.toString(),"10", "amount not valid");
        assert.strictEqual(Remitmap.expireTime.toString(), "604800", "deadline not valid");

    });

    it("should not allow use of duplicate passwords", async () => {

        //Transaction1
        await instance.sendRemit("SamePassword123",12345, { from: account1, value: 10 });
        // Transaction2 trying to use same pwd
        await truffleAssert.fails(
        instance.sendRemit("SamePassword123",40000, { from: account3, value: 15 })
        );
    });

    it("Revert invalid or malicious attempts to withdraw funds", async () => {

        let smsOtp = "aBc123xYz";
        // Creating hash password from OTP and receiver
        let hashPwd = await instance.getOtpHash(smsOtp, account2).call();

        // Creating a remittance order(send)
        await instance.sendRemit(hashPwd,604800, { from: account1, value: 100 });

        // Revert when trying to  withdraw using wrong OTP
        await truffleAssert.fails(
        instance.withdrawRemit("1234xyz", { from: account2})
        );

        // Revert when trying to  withdraw using wrong address
        await truffleAssert.fails(
        instance.withdrawRemit("1234xyz", { from: account3})
        );
    });

    it("should be possible to WITHDRAW funds by the correct receiver", async () => {

        let smsOtp = "aBc123xYz";
        let remittance = 100;
        // Creating hash password from OTP and receiver
        let hashPwd = await instance.getOtpHash(smsOtp, account2).call();

        // Creating a remittance order(send)
        await instance.sendRemit(hashPwd,604800, { from: account1, value: remittance });

        // withdrawal of funds by the correct otp and receiver
        let preBalance = await web3.eth.getBalance(account2); // balance before withdrawal

        const txObj = await instance.withdrawRemit(smsOtp, { from: account2 });
        assert.isTrue(txObj.receipt.status, "Transaction failed..Could not withdraw funds");

        let tx = await web3.eth.getTransaction(txObj.tx);
        let gasCost = tx.gasPrice * txObj.receipt.gasUsed;
        let expectedBalance = preBalance + remittance  - gasCost ;

        let newBalance = await web3.eth.getBalance(account2); // balance after withdrawal
        assert.strictEqual(newBalance.toString(),expectedBalance.toString(), "New balance does not match expected balance");

    });

    it("should be possible to CLAIM-BACK funds by the sender", async () => {

        let smsOtp = "aBc123xYz";
        let remittance = 100;
        // Creating hash password from OTP and receiver
        let hashPwd = await instance.getOtpHash(smsOtp, account2).call();

        // Creating a remittance order(send)
        await instance.sendRemit(hashPwd,604800, { from: account1, value: remittance });

        // Get the remit mapping values for validation
        const Remitmap = await instance.remitmap.call(hashPwd, {from: account1});

        // Revert when trying to  claim using wrong address
        await truffleAssert.fails(
        instance.claimBackRemit(hashPwd, {from: account3}));

        // Claiming of funds by the correct address
        let preBalance = await web3.eth.getBalance(account1);

        const txObj = await instance.claimBackRemit(hashPwd, { from: account1 });
        assert.isTrue(txObj.receipt.status, "Transaction failed..Could not claim back funds");

        let tx = await web3.eth.getTransaction(txObj.tx);
        let gasCost = tx.gasPrice * txObj.receipt.gasUsed;
        let expectedBalance = preBalance + remittance  - gasCost ;

        let newBalance = await web3.eth.getBalance(account1);
        assert.strictEqual(newBalance.toString(),expectedBalance.toString(), "New balance does not match expected balance");

    });
});
