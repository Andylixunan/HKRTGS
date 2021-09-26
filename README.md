# HKRTGS
A solidity project implementing the RTGS bank system in Hong Kong

We assume that the 3 ether that bank register with RTGS come from the initial funding of 5 (or more) ether from the bank owner. For normal banks, only the bank owner could see the ledger of the bank.

We also assume that banks wouldn't make deposits in the RTGS bank when their clients make deposits. Therefore, any inter-bank transfer with amount greater than 3 ether wouldn't be allowed since each bank only has 3 ether in their accounts in the RTGS bank.