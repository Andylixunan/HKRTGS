# HKRTGS
A solidity project implementing the RTGS bank system in Hong Kong

We assume that the 3 ether that bank register with RTGS come from the initial funding of 5 ether from the bank owner. And since doing inter-bank transfer requires the contract of bank to call functions that belong to another contract, namely that of RTGS, we would consume some Weis as transaction costs, which means we could only refund what's left in the initial funding instead of 5 ether to the bank owner.


We also assume that banks wouldn't make deposits in the RTGS bank when their clients make deposits. Therefore, any inter-bank transfer with amount greater than 3 ether wouldn't be allowed since each bank only has 3 ether in their accounts in the RTGS bank.