// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

// unless directly specified the unit to be ether, 
// all amounts are recorded in the unit of Wei

contract Bank {
    address private owner; // the owner of the bank
    address[] private accounts; // an array of addresses of bank clients
    mapping (address=>uint) private accountBalances; // a mapping from client's address to his remaining balance
    CentralBank RTGS; // storing the instance of RTGS central bank

    // this struct is for logging purpose only, 
    // since we couldn't return or emit a mapping in solidity
    struct accountInfo{
        address account;
        uint balance;
    }

    event AuditLog(address clientAddress, uint amount); // log event for auditing
    event LedgerLog(accountInfo[]); // log event for showing the ledger

    modifier accountNumLimit{
        require(accounts.length < 10, "only a maximum of 10 accounts is allowed");
        _;
    }

    // we require an initial funding of  >= 5 ether for normal banks
    modifier initialFunding{
        require(msg.value >= 5 ether, "initial funding no less than 5 ether is required");
        _;
    }

    modifier accountExists{
        bool flag = false;
        for (uint i = 0; i < accounts.length; i++){
            if(msg.sender == accounts[i]){
                flag = true;
                break;
            }
        }
        require(flag == true, "account doesn't exist");
        _;
    }

    modifier accountNotExist{
        bool flag = true;
        for (uint i = 0; i < accounts.length; i++){
            if(msg.sender == accounts[i]){
                flag = false;
                break;
            }
        }
        require(flag == true, "account already exists");
        _;
    }
    

    modifier isOwner{
        require(msg.sender == owner, "not the owner of the bank");
        _;
    }

    // constructor of the bank, receive the msg.value as initial funding,
    // set the msg.sender to be the owner of the bank
    constructor() payable initialFunding{
        owner = msg.sender;
    }

    // for clients to open an account in the bank
    function openAccount() public accountNumLimit accountNotExist{
        accounts.push(msg.sender);
    }

    // for clients to make deposits in the bank
    function deposit() public payable accountExists{
        accountBalances[msg.sender] += msg.value;
        emit AuditLog(msg.sender, msg.value);
    }

    // for clients to specify an amount and make withdrawal in the bank
    function withdraw(uint amount) public accountExists{
        require(accountBalances[msg.sender] >= amount, "account balance not enough");
        payable(msg.sender).transfer(amount);
        accountBalances[msg.sender] -= amount;
        emit AuditLog(msg.sender, amount);
    }

    // display(return) the balance of client(msg.sender) who called the function
    function balance() public view accountExists returns (uint) {
        return accountBalances[msg.sender];
    }

    // logging the ledger as an array,
    // whose elements are in the form of {address: balance}
    function ledger() public isOwner{
        uint len = accounts.length;
        accountInfo[] memory arr = new accountInfo[](len);
        for (uint i = 0; i < len; i++){
            arr[i] = accountInfo(accounts[i], accountBalances[accounts[i]]);
        }
        emit LedgerLog(arr);
    }

    // the owner can close the bank
    function closeBank() public payable isOwner{
        // withdraw the fundings stored in RTGS bank and delete the account in it
        RTGS.withdrawAllFundsAndDeleteAccount(); 
        // first return the balances stored in the bank to respective bank clients
        for (uint i = 0; i < accounts.length; i++){
            payable(accounts[i]).transfer(accountBalances[accounts[i]]);
        }
        // then return the initial funding to the bank owner and delete the bank
        selfdestruct(payable(owner));
    }

    // clients could conduct inter-bank transfer by specifying: 
    // 1. the address of receiver
    // 2. the address of the bank where the receiver has the account
    // 3. the amount to be transfered
    function transfer(address receiver, address receiverBank, uint amount) public accountExists{
        require(accountBalances[msg.sender] >= amount, "account balance not enough");
        uint balanceAtRTGS = RTGS.balance();
        require(balanceAtRTGS >= amount, "RTGS balance not enough");
        // decrement the account balance for sender
        accountBalances[msg.sender] -= amount;
        // ask RTGS central bank to update its balance(ledger) accordingly
        RTGS.transfer(receiverBank, amount);
        Bank recvBank = Bank(payable(receiverBank));
        // ask the receiving bank to increment the balance for receiver
        recvBank.addBalance(receiver, amount);
    }

    // a helper function to add balance for a specified client
    // intended to be used by the function transfer() only
    function addBalance(address receiver, uint amount) external{
        accountBalances[receiver] += amount;
    }

    // register account in the central bank by specifying its address
    // make initial deposit of 3 ether
    function registerRTGS(address centralBank) public{
        RTGS = CentralBank(centralBank);
        RTGS.openAccountAndDeposit{value: 3 ether}();
    }

    // built-in function, adding this would allow the contract to receive money(ether) from other contracts
    receive() external payable{}
}



contract CentralBank{
    address[] private accounts; // an array of addresses of RTGS bank clients, which are normal banks
    mapping (address=>uint) private accountBalances; // a mapping from normal bank address to its balance in RTGS
    /* 
        here we store the number of accounts instead of using accounts.length
        directly, since "delete" in solidity would only nullify the content instead 
        of deleting it in the storage. For instance, "delete address" would make an
        address become "0x000000..."
    */
    uint private accountNum;

    // for logging purpose only, same as the one in the contract "Bank" above 
    struct accountInfo{
        address account;
        uint balance;
    }
    event LedgerLog(accountInfo[]);

    // to be used by normal bank only,
    // open an account for normal bank and make initial deposit of 3 ether
    function openAccountAndDeposit() payable public {
        require(msg.value == 3 ether, "3 ether initial funding required");
        accounts.push(msg.sender);
        accountBalances[msg.sender] += msg.value;
        accountNum++;
    }

    // to be used by normal bank only,
    // withdraw all funds for the normal bank and delete its account
    function withdrawAllFundsAndDeleteAccount() public {
        uint amount = accountBalances[msg.sender];
        /* 
            address.transfer() set default gas limit for inter-contract transfer to be 2300 
            but we clearly need more gas, so use address.call to transfer ether without pre-defined gas limit
        */
        (bool success, ) = payable(msg.sender).call{value:amount}("");
        require(success, "withdrawAllFunds failed");
        accountBalances[msg.sender] -= amount;
        removeAccount(msg.sender);
    }

    // a helper function to be used by function withdrawAllFundsAndDeleteAccount() only,
    // remove the account in RTGS bank for a specified normal bank
    function removeAccount(address accountToBeDel) private {
        uint index;
        uint len = accountNum;
        // find the account by its address
        for (uint i = 0; i < len; i++){
            if(accounts[i] == accountToBeDel){
                index = i;
                break;
            }
        }
        // move elements after it one step forward
        for (uint i = index; i < len-1; i++){
            accounts[i] = accounts[i+1];
        }
        // delete the last element and update the number of accounts
        delete accounts[len-1];
        accountNum--;
    }

    // to be used by normal bank only,
    // update the RTGS account balance(ledger) for a transfer action
    function transfer(address toBank, uint amount) public {
        address fromBank = msg.sender;
        accountBalances[fromBank] -= amount;
        accountBalances[toBank] += amount;
    }

    // to be used by normal bank only,
    // return the balance of the bank who calls this function
    function balance() public view returns (uint){
        return accountBalances[msg.sender];
    }

    // show the ledger of RTGS bank,
    // format is the same as above in the contract "Bank"
    function ledgerRTGS() public {
        uint len = accountNum;
        accountInfo[] memory arr = new accountInfo[](len);
        for (uint i = 0; i < len; i++){
            arr[i] = accountInfo(accounts[i], accountBalances[accounts[i]]);
        }
        emit LedgerLog(arr);
    }
    
}