# HKRTGS
A solidity project implementing the RTGS bank system in Hong Kong

We assume that the 3 ethers that bank register with RTGS come from the initial funding of 5 (or more) ether from the bank owner. For normal banks, the bank has an owner and only the bank owner could see the bank ledger and close the bank. For RTGS bank, we assume there’s no need to have an owner or 5 ethers initial funding to complicate the scenario. 

We also assume that banks wouldn't make deposits in the RTGS bank when their clients make deposits. Therefore, any inter-bank transfer with amount greater than 3 ethers wouldn't be allowed since each bank only has 3 ethers in their accounts in the RTGS bank.
