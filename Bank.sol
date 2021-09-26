// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract Bank {
    address private owner;
    address[] private accounts;
    mapping (address=>uint) private accountBalances;
    CentralBank RTGS;

    // this struct is for logging purpose only
    struct accountInfo{
        address account;
        uint balance;
    }

    event AuditLog(address clientAddress, uint amount);
    event LedgerLog(accountInfo[]);

    modifier accountNumLimit{
        require(accounts.length < 10, "only a maximum of 10 accounts is allowed");
        _;
    }

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

    constructor() payable initialFunding{
        owner = msg.sender;
    }

    function openAccount() public accountNumLimit accountNotExist{
        accounts.push(msg.sender);
    }

    function deposit() public payable accountExists{
        accountBalances[msg.sender] += msg.value;
        emit AuditLog(msg.sender, msg.value);
    }

    function withdraw(uint amount) public accountExists{
        require(accountBalances[msg.sender] >= amount, "account balance not enough");
        payable(msg.sender).transfer(amount);
        accountBalances[msg.sender] -= amount;
        emit AuditLog(msg.sender, amount);
    }

    function balance() public view accountExists returns (uint) {
        return accountBalances[msg.sender];
    }

    // logging the info
    function ledger() public isOwner{
        uint len = accounts.length;
        accountInfo[] memory arr = new accountInfo[](len);
        for (uint i = 0; i < len; i++){
            arr[i] = accountInfo(accounts[i], accountBalances[accounts[i]]);
        }
        emit LedgerLog(arr);
    }


    function closeBank() public payable isOwner{
        RTGS.withdrawAllFundsAndDeleteAccount();
        for (uint i = 0; i < accounts.length; i++){
            payable(accounts[i]).transfer(accountBalances[accounts[i]]);
        }
        selfdestruct(payable(owner));
    }

    function transfer(address receiver, address receiverBank, uint amount) public accountExists{
        require(accountBalances[msg.sender] >= amount, "account balance not enough");
        uint balanceAtRTGS = RTGS.balance();
        require(balanceAtRTGS >= amount, "RTGS balance not enough");
        accountBalances[msg.sender] -= amount;
        RTGS.transfer(receiverBank, amount);
        Bank recvBank = Bank(payable(receiverBank));
        recvBank.addBalance(receiver, amount);
    }

    function addBalance(address receiver, uint amount) external{
        accountBalances[receiver] += amount;
    }

    function registerRTGS(address centralBank) public{
        RTGS = CentralBank(centralBank);
        RTGS.openAccountAndDeposit{value: 3 ether}();
    }

    receive() external payable{}
}



contract CentralBank{
    address[] private accounts;
    mapping (address=>uint) private accountBalances;
    /* 
        here we store the number of accounts instead of using accounts.length
        directly, since "delete" in solidity would only nullify the content instead 
        of deleting it in the storage. For instance, "delete address" would make an
        address become "0x000000...".
    */
    uint private accountNum;

    struct accountInfo{
        address account;
        uint balance;
    }
    event LedgerLog(accountInfo[]);

    function openAccountAndDeposit() payable public {
        require(msg.value == 3 ether, "3 ether initial funding required");
        accounts.push(msg.sender);
        accountBalances[msg.sender] += msg.value;
        accountNum++;
    }

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

    function removeAccount(address accountToBeDel) private {
        uint index;
        for (uint i = 0; i < accounts.length; i++){
            if(accounts[i] == accountToBeDel){
                index = i;
                break;
            }
        }
        for (uint i = index; i < accounts.length-1; i++){
            accounts[i] = accounts[i+1];
        }
        delete accounts[accounts.length-1];
        accountNum--;
    }

    function transfer(address toBank, uint amount) public {
        address fromBank = msg.sender;
        accountBalances[fromBank] -= amount;
        accountBalances[toBank] += amount;
    }

    function balance() public view returns (uint){
        return accountBalances[msg.sender];
    }

    function ledgerRTGS() public {
        uint len = accountNum;
        accountInfo[] memory arr = new accountInfo[](len);
        for (uint i = 0; i < len; i++){
            arr[i] = accountInfo(accounts[i], accountBalances[accounts[i]]);
        }
        emit LedgerLog(arr);
    }
    
}