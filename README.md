Welcome to MyStoreBucks©
=============================

- [Introduction](#Introduction)
- [Project Description](#Project-Description)
- [ERC20 Definition](#ERC20-Definition)
- [Main Functions](#Main-Functions)
	- [addTransaction](#addTransaction)
    - [earnPoints](#earnPoints)
	- [redeemPoints](#redeemPoints)
	- [issueVoucher](#issueVoucher)
	- [expireVoucher](#expireVoucher)
	- [redeemVoucher](#redeemVoucher)
- [Other Functions](#Other-Functions)
	- [calcPoints](#calcPoints)
	- [usePoints](#usePoints)
    - [UpdateStatus](#UpdateStatus)
	- [setVoucherValidityPeriod](#setVoucherValidityPeriod)
	- [changeVoucherStatus](#changeVoucherStatus)
    - [setVoucherValue](#setVoucherValue)
	- [compareStrings](#compareStrings)
    - [UpdateStatus](#UpdateStatus)
    - [setStartPoint](#setStartPoint)

- [Table](#table)
	- [Struct Table](#Struct-Table)
	- [List Table](#List-Table)


# Introduction

Welcome to *MyStoreBucks©*!

🗃️ An ERC20 smart contract as an alternative to traditional loyalty programs.

*MyStoreBucks©* is a blockchain-based customer loyalty platform where transactions of non-monetized loyalty points are securely processed and immutably recorded in a permissioned ledger environment. The result is a **decentral**, **fully transparent**, and **fraud-protected** real-time accounting system. Moreover, it includes a cryptographically secured redemption process of loyalty points, mitigating risks of counterfeited occurrence of financial liabilities.


# Project Description

This software component is a loyalty program  with rewards based on ERC-20 token.

This loyalty program allows to perform these tasks:

 - Reward users with points for subscribing to the platform;
 - Reward users with points for any purchase;
 - Reward users with points for sharing links in Facebook, LinkedIn, and other ..;
 - Reward users with points for approved feedback;
 - Redeem points for vouchers that entitles the holder to a discount;
 - Flexible reward with points for users' purchases with ranking;
 - expire unused vouchers after a while.


# ERC20 Definition

An ERC20 token is a standard used for creating and issuing smart contracts on the Ethereum blockchain. Smart contracts can then be used to create smart property or tokenized assets that people can invest in. ERC stands for "Ethereum request for comment," and the ERC20 standard was implemented in 2015.


## Main Functions

The main functions include [addTransaction](#addTransaction), [earnPoints](#earnPoints), [redeemPoints](#redeemPoints), [issueVoucher](#issueVoucher), [expireVoucher](#expireVoucher), [redeemVoucher](#redeemVoucher) 6 functions. These functions contain the substantial part of the codes to document transactions, earn points and  verify vouchers.


### addTransaction
Everything starts with a purchase in the loyalty network. This function documents transactions on the blockchain, therefore denoting the first step in a loyalty point’s journey. 

The information contained in a transaction is the member ID, points eraned to the purchase and a transaction time. 
```solidity
    struct transaction {
        uint memberID;
        uint point;
        uint transactionTime;
    }
```
Transactions are stored in a mapping <transactionList> using the unique transaction ID as the key. 
```solidity
    mapping(uint => transaction) public transactionList;
```   
addTransaction further calls the [calcPoints](#calcPoints) function to calculate the points related to the transaction and to store this information as part of a transaction in transactionList. After calculating the number of points, the addTransaction function updates the member’s point account. An event will be triggered to create a voucher code in an off-chain application when member demands redemption but only when they has reached a point balance of 4000 as minimum.  
	
```solidity
    function addTransaction(
        uint256 _memberID,
        uint256 _product,
        uint256 _transactionID
    ) public {
        uint256 _point = calcPoints(_product, _memberID);

        transaction memory transaction;
        transaction.memberID = _memberID;
        transaction.point = _point;
        transaction.transactionTime = block.timestamp;
        transaction.transactionID = _transactionID;
        lengthTransactionList++;
        transactionList[_transactionID] = transaction;

        memberList[_memberID].totalPoints += _point;
        memberList[_memberID].lastPurchaseTime = block.timestamp;
        // check whether the member is still within the same ranking range, if they haven made a purchase
        //and their points record allow them to change status then it will be updated
        UpdateStatus(memberList[_memberID].memberID);
    }
```

### earnPoints
there are other ways to earn points other than recieving them from purchases

```solidity
    function EarnPoints(uint256 _memberID, string memory actionValue) public {
        uint256 _point = 0;
        if (compareStrings(actionValue, "share")) {
            _point += 20;
            memberList[_memberID].totalPoints += _point;
        } else if (compareStrings(actionValue, "comment")) {
            _point += 20;
            memberList[_memberID].totalPoints += _point;
        }
    }
```

### redeemPoints
As the main reason to redeem collected points is to recieve discount vouchers, this function calls for [issueVoucher](#issueVoucher). During the redemption process, the voucher clean code and its corresponding salt are received by the redeemPoints function as input to re-calculate the hash voucher code.
The amount of points used to issue the respective voucher is deducted from the client’s point account in the usePoints function [usePoints](#usePoints), the amount of points needed to be converted is decided by the input value 'voucherValue' which defines the demanded percentage of discount.

```solidity
    function redeemPoints(
        uint _memberID,
        uint _VoucherCode,
        uint _voucherValue,
        uint _Salt
    ) public {
        bytes32 _hashVoucherCode = keccak256(abi.encodePacked(_VoucherCode, _Salt));
        uint _points = _voucherValue * 1000;
        issueVoucher(_memberID, _voucherValue, _hashVoucherCode);
        // deduct points from member´s point statement
        usePoints(_memberID, _points);
        emit RedeemedPoints(memberList[_memberID].memberAddress, _points);
    }
```

### issueVoucher
In case the member's point account reaches a minimum of 4000 points, a voucher is to be issued on demand as soon as the balance is met. The issueVoucher function is called by the off-chain application after generating the voucher code. As previously mentioned, the off-chain application genrates a voucher code. Important to note here is that it also subsequently hashes it. The hash voucher code (and not the clean voucher code of course) is then stored into VoucherList, together with the member ID and voucher issuance time. Moreover, the voucher status is set to “Active”. This is important since only vouchers with a valid hash voucher code and status “Active” can be redeemed later on.

```solidity
    struct voucher {
        uint memberID;
        bytes32 hashVoucherCode;
        string status;
        uint issueTime;
        uint voucherValue;
    }
```
```solidity

    function issueVoucher(
        uint _memberID,
        uint _voucherValue,
        bytes32 _hashVoucherCode
    ) internal {
        // verify enough points for member
        require(
            memberList[_memberID].totalPoints >= _voucherValue * 1000,
            "Insufficient points"
        );
        //if the member has more than 4000 points, voucher is issued
        //The voucher Code is generated off-chain. The off-Chain program gives a hashVoucherCode back.
        //An Event is used to trigger the process off-chain to generate a voucher Code.
        //Only the member ID is given in the log file to guarantee a higher security.
        emit GenerateVoucherCode(memberList[_memberID].memberID);

        //get the voucher list of the member as a voucher instance
        voucher storage thisVoucher = voucherList[voucherList.length];
        mapping(bytes32 => voucher) storage vouchers = memberList[_memberID]
            .voucherListMember;

        //append to the voucher list of all members
        thisVoucher.memberID = _memberID;
        thisVoucher.hashVoucherCode = _hashVoucherCode;
        thisVoucher.voucherValue = _voucherValue;
        thisVoucher.status = "Active";
        thisVoucher.issueTime = block.timestamp;

        //now add to the voucher list of the member
        vouchers[_hashVoucherCode].memberID = _memberID;
        vouchers[_hashVoucherCode].voucherValue = _voucherValue;
        vouchers[_hashVoucherCode].status = "Active";
        vouchers[_hashVoucherCode].issueTime = block.timestamp;
    }
```

### expireVoucher
In this loyalty program, vouchers can expire. The expireVoucher function is called by [redeemVoucher](#redeemVoucher). This means that, before redeeming a voucher, it needs to be ensured that it has not yet expired. The expireVoucher function makes sure that unused vouchers expire after a certain period (2 years in our case).
```solidity
    function expireVoucher(uint _memberID) internal {
        for (uint i = 0; i < voucherList.length; i++) {
            if (voucherList[i].memberID == _memberID) {
                if (
                    voucherList[i].issueTime +
                        VoucherValidityPeriod *
                        365 days <
                    block.timestamp &&
                    compareStrings(voucherList[i].status, "Active")
                ) {
                    voucherList[i].status = "Expired";
                }
                break;
            }
        }
    }
``` 

### redeemVoucher
members receive vouchers in the form of a QR code which consists of the member ID, the clean voucher code, and the salt which has been appended to the latter before it has been hashed. (Note: The hashing process takes place in an off-chain environment to avoid that not the clean but hashed voucher codes are stored on-chain.) The redeemVoucher function verifies the voucher validity. Subsequently, the calculated hash voucher code is compared with the hash voucher codes previously stored in VoucherList. If the hash voucher code is valid and the corresponding voucher has a status equal to “Active”, the voucher is valid and it thus can be redeemed.

```solidity
    function redeemVoucher(uint _memberID, bytes32 _hashVoucherCode)
        public
        returns (bool validVoucher)
    {
        validVoucher = false;
        expireVoucher(_memberID);

        for (uint i = 0; i < voucherList.length; i++) {
            if (
                voucherList[i].hashVoucherCode == _hashVoucherCode &&
                voucherList[i].memberID == _memberID
            ) {
                validVoucher = true;
                changeVoucherStatus(voucherList[i].hashVoucherCode, "Used");
                emit useVoucher(
                    memberList[_memberID].memberAddress,
                    _hashVoucherCode
                );
                break;
            }
        }
    }
``` 

## Other Functions
The functions described in this section play a supporting role in the Smart Contract and are necessary to realize the main *MyStoreBucks©* functions outlined above. 

### calcPoints
The calcPoints function is called by [addTransaction](#addTransaction) to calculate the total points that a member can obtain for the purchase. Additionally, this function calls [queryPromotionMultiple](#queryPromotionMultiple) to see whether there is an active multi-point promotion. If the case, it takes the respective multiple into account when calculating the effective point transaction amount. 
```solidity
   function calcPoints(product memory _product) internal returns(uint _point){
        uint _point = 0;
        uint promotionMultiple = 1; // set the initial value for promotion equal to 1
        promotionMultiple = queryPromotionMultiple(_product.productID);
        _point = _point + _product.unitPrice*_product.quantity*promotionMultiple;
        return _point;
    }
``` 

### usePoints
This function is called to adjust the member's point account in case of voucher issuance.
```solidity
    function usePoints(uint _memberID, uint _point) internal {
        memberList[_memberID].totalPoints =
            memberList[_memberID].totalPoints -
            _point;
    }
```

### UpdateStatus
This function is called to update the member's ranking/status which is decided by the highest number of points once reached by them.
if member reaches un upper rank they keep that status until they attend a higher record of points. that means even if they finish up all their points the ranking won't go down.

```solidity
    function UpdateStatus(uint _memberID) public onlyAdmin {
        if (
            memberList[_memberID].totalPoints >= 10000 &&
            memberList[_memberID].totalPoints < 20000
        ) {
            if (compareStrings(memberList[_memberID].status, "Member")) {
                memberList[_memberID].status = "Insider";
            }
        } else if (memberList[_memberID].totalPoints >= 20000) {
            if (
                compareStrings(memberList[_memberID].status, "Member") ||
                compareStrings(memberList[_memberID].status, "Insider")
            ) {
                memberList[_memberID].status = "VIP";
            }
        }
    }
```

### setVoucherValidityPeriod
The voucher validity period can be changed through this function. The default value is 2 years.
```solidity
   function setVoucherValidityPeriod(uint _voucherValidity) public onlyOwner {
        VoucherValidityPeriod = _voucherValidity * 365 days;
    }
```

### setStartPoint
As soon as a member subscribes to the plateform he is given an initial number of points wich is set by this function
```solidity    
    function setStartPoint(uint startpoint) public onlyAdmin {
        startPoint = startpoint;
    }
```

### setVoucherValue
The minimum voucher value (minimum discount value) can be changed through this function.
```solidity 
    function setVoucherValue(uint _voucherValue) public onlyAdmin {
        voucherValue = _voucherValue;
    }
```

### changeVoucherStatus
The voucher status can be changed through this function.
```solidity 
    function changeVoucherStatus(
        bytes32 _hashVoucherCode,
        string memory _newStatus
    ) internal {
        for (uint i = 0; i < voucherList.length; i++) {
            if (_hashVoucherCode == voucherList[i].hashVoucherCode) {
                voucherList[i].status = _newStatus;
                break;
            }
        }
    }
```

### compareStrings
compareStrings function is used to compare strings in Solidity, i.e. whether they are identical through its hash value.
```solidity
   function compareStrings(string memory s1, string memory s2) public view returns(bool){
    return keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2));
   }
```

# Table
## Struct Table
|Struct|Attributes|
|:---:|:---|
|member| address memberAddress <br /> uint memberID <br /> uint totalPoints <br /> uint lastPurchaseTime <br /> string status  <br /> mapping (bytes32 => voucher) voucherListMember| 
|voucher | uint memberID <br /> bytes32 hashVoucherCode <br /> string status <br /> uint issueTime <br /> uint voucherValue|
|transaction | uint TransactionID <br /> uint memberID <br /> uint point <br /> uint transactionTime|
|document | uint docID <br /> uint price <br /> uint memberID|
## List Table
|Name|Type|Definition|
|:---:|:---:|:---|
|memberAddressList| Mapping | mapping (address => uint) memberAddressList | 
|transactionList| Mapping | mapping (uint => transaction) transactionList|
|memberList | Mapping |  mapping (uint => member) memberList|
|voucherList | Array | voucher[] voucherList|
|voucherListMember | Mapping | mapping (bytes32 => voucher)|
|docList | Array | document[] docList|
