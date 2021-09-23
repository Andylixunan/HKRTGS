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
    // accountInfo[] ledgerInfo;

    event AuditLog(address clientAddress, uint amount);
    event LedgerLog(accountInfo[]);

    modifier accountNumLimit{
        require(accounts.length < 10, "only a maximum of 10 accounts is allowed");
        _;
    }

    modifier initialFunding{
        require(msg.value == 5 ether, "5 ether initial funding required");
        _;
    }

    modifier accountExists{
        bool flag = false;
        for (uint i = 0; i < accounts.length; i++){
            if(msg.sender == accounts[i]){
                flag = true;
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

        /*
        for (uint i = 0; i < accounts.length; i++){
            ledgerInfo.push(accountInfo(accounts[i], accountBalances[accounts[i]]));
        }
        emit LedgerLog(ledgerInfo);
        */
    }


    function closeBank() public isOwner{
        for (uint i = 0; i < accounts.length; i++){
            payable(accounts[i]).transfer(accountBalances[accounts[i]]);
        }
        uint ownerRefund = address(this).balance;
        payable(owner).transfer(ownerRefund);
    }

    // TODO: parameter checking
    function transfer(address receiver, address receiverBank, uint amount) public accountExists{
        // require(accountBalances[msg.sender] >= amount, "account balance not enough");
        accountBalances[msg.sender] -= amount;
        RTGS.transfer(receiverBank, amount);
        Bank recvBank = Bank(receiverBank);
        recvBank.addBalance(receiver, amount);
    }

    // maybe check with RTGS?
    function addBalance(address receiver, uint amount) external{
        accountBalances[receiver] += amount;
    }

    function registerRTGS(address centralBank) public{
        RTGS = CentralBank(centralBank);
        RTGS.openAccountAndDeposit();
    }
}



contract CentralBank{
    address[] private accounts;
    mapping (address=>uint) private accountBalances;

    struct accountInfo{
        address account;
        uint balance;
    }
    event LedgerLog(accountInfo[]);

    function openAccountAndDeposit() payable public {
        require(msg.value == 3 ether, "3 ether initial funding required");
        accounts.push(msg.sender);
        accountBalances[msg.sender] += msg.value;
    }

    function withdrawAllFunds() public returns (uint){
        uint amount = accountBalances[msg.sender];
        payable(msg.sender).transfer(amount);
        accountBalances[msg.sender] -= amount;
        return amount;
    }

    function transfer(address toBank, uint amount) public {
        address fromBank = msg.sender;
        accountBalances[fromBank] -= amount;
        accountBalances[toBank] += amount;
    }

    function ledgerRTGS() public {
        uint len = accounts.length;
        accountInfo[] memory arr = new accountInfo[](len);
        for (uint i = 0; i < len; i++){
            arr[i] = accountInfo(accounts[i], accountBalances[accounts[i]]);
        }
        emit LedgerLog(arr);
    }
    
}