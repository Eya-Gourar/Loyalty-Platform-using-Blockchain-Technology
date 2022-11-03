// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import ".deps/npm/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "contracts/Date.sol";

//!!!!! change the path of this directory to your own local path please !!!!

contract StoreBucks is ERC20 {
    // a constructor is a function that runs when the contract is first deployed
    constructor() ERC20("StoreBucks", "SBuck") {
        _mint(msg.sender, 4000);
    }

    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    address admin = msg.sender;

    struct member {
        address memberAddress;
        uint256 memberID;
        uint256 totalPoints;
        uint256 lastPurchaseTime; // used to determine whether the member is still Active.
        string status;
        mapping(bytes32 => voucher) voucherListMember;
    }

    struct transaction {
        uint256 transactionID;
        uint256 memberID;
        uint256 point;
        uint256 transactionTime;
    } //The information contained in a transaction is the member ID, sum of points earned and unique ID.

    struct document {
        string docID;
        uint256 price;
        uint256 memberID;
    }

    struct voucher {
        uint256 memberID;
        bytes32 hashVoucherCode;
        uint256 issueTime;
        uint256 voucherValue;
        string status;
    }

    //members on the network mapped with their address
    mapping(uint256 => member) public memberList;
    mapping(address => member) public memberAddressList;

    //Transactions are stored in a mapping using the unique transaction ID as the key.
    mapping(uint256 => transaction) public transactionList;

    //The following list is kept as array because there is no strict key which can be used for mapping
    voucher[] public voucherList;
    document[] public docList;

    uint256 startPoint = 500; // members obtain a start points while joining the program, current value = 500

    uint256 voucherValue = 500; // Every voucher has a certain value, the default value is 4000 points for 20% discount (the minimum).
    // next is 12 000 points for 50% discount then 20 000 points for 70% discount

    uint256 lengthTransactionList = 0; // This variable is used to document the length of the mapping "TransactionList"

    uint256 lengthmemberList = 0; // This variable is used to document the length of the mapping "memberList"

    uint256 VoucherValidityPeriod = 2; // As default, a voucher has a validity of 2 years.

    // =================================
    // Events
    // =================================

    event Rewardedmember(address indexed _memberAddress, uint256 points);
    event RedeemedPoints(address indexed _memberAddress, uint256 points);
    event GenerateVoucherCode(uint256 _memberID);
    event useVoucher(address indexed _memberAddress, bytes32 _hashVoucherCode);

    // =================================
    // Modifiers
    // =================================

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    // =================================
    // Public functions
    // =================================

    //======== only admin ========//

    function setStartPoint(uint256 startpoint) public onlyAdmin {
        startPoint = startpoint;
    }

    function setVoucherValue(uint256 _voucherValue) public onlyAdmin {
        voucherValue = _voucherValue;
    }

    function addNewMember(uint256 _memberID, address _memberAddress)
        public
        payable
        onlyAdmin
    {
        memberList[_memberID].memberAddress = _memberAddress;
        memberList[_memberID].memberID = _memberID;
        memberList[_memberID].totalPoints = startPoint;
        memberList[_memberID].lastPurchaseTime = block.timestamp;
        memberList[_memberID].status = "Member";
        lengthmemberList++;
        _mint(_memberAddress, startPoint);
    }

    function addDoc(
        uint256 _memberID,
        string memory _docID,
        uint256 _price
    ) public onlyAdmin {
        document memory doc = document({
            docID: _docID,
            memberID: _memberID,
            price: _price
        });
        docList.push(doc);
    }

    //====== User's ======//

    function addTransaction(
        uint256 _memberID,
        string memory _docID,
        uint256 _transactionID
    ) public payable {
        uint256 _point = calcPoints(_docID, _memberID);

        transaction memory trans = transactionList[_transactionID];
        trans.memberID = _memberID;
        trans.point = _point;
        trans.transactionTime = block.timestamp;
        trans.transactionID = _transactionID;
        lengthTransactionList++;
        transactionList[_transactionID] = trans;

        memberList[_memberID].totalPoints += _point;
        memberList[_memberID].lastPurchaseTime = block.timestamp;
        // check whether the member is still within the same ranking range, if they haven made a purchase
        //and their points record allow them to change status then it will be updated
        UpdateStatus(memberList[_memberID].memberID);
        _mint(memberList[_memberID].memberAddress, _point);
    }

    //there are other ways to earn points other than recieving them from purchases

    function EarnPoints(uint256 _memberID, string memory actionValue)
        public
        payable
    {
        uint256 _point = 0;
        if (compareStrings(actionValue, "share")) {
            _point += 20;
            memberList[_memberID].totalPoints += _point;
        } else if (compareStrings(actionValue, "comment")) {
            _point += 20;
            memberList[_memberID].totalPoints += _point;
            _mint(memberList[_memberID].memberAddress, _point);
        }
    }

    function redeemPoints(
        uint256 _memberID,
        uint256 _VoucherCode,
        uint256 _voucherValue
    ) public payable {
        // verify enough points for member

        int256 Salt = 11;
        //if the member has more than _voucherValue (required points), voucher is issued
        bytes32 _hashVoucherCode = keccak256(
            abi.encodePacked(_VoucherCode, Salt)
        );

        uint256 _points = _voucherValue;
        issueVoucher(_memberID, _voucherValue, _hashVoucherCode);

        // deduct points from member´s point statement
        usePoints(_memberID, _points);
        _burn(memberList[_memberID].memberAddress, _points);
        emit RedeemedPoints(memberList[_memberID].memberAddress, _points);
    }

    function redeemVoucher(uint256 _memberID, bytes32 _hashVoucherCode)
        public
        returns (bool validVoucher)
    {
        validVoucher = false;
        expireVoucher(_memberID);

        for (uint256 i = 0; i < voucherList.length; i++) {
            if (
                voucherList[i].hashVoucherCode == _hashVoucherCode &&
                voucherList[i].memberID == _memberID
            ) {
                if (compareStrings(voucherList[i].status, "Expired")) {
                    validVoucher = true;
                    changeVoucherStatus(
                        voucherList[i].hashVoucherCode,
                        "Used",
                        _memberID
                    );
                    emit useVoucher(
                        memberList[_memberID].memberAddress,
                        _hashVoucherCode
                    );
                    break;
                }
            }
        }
    }

    // =================================
    // internal
    // =================================

    function UpdateStatus(uint256 _memberID) internal {
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

    function changeVoucherStatus(
        bytes32 _hashVoucherCode,
        string memory _newStatus,
        uint256 _memberID
    ) internal {
        for (uint256 i = 0; i < voucherList.length; i++) {
            if (_hashVoucherCode == voucherList[i].hashVoucherCode) {
                voucherList[i].status = _newStatus;
                memberList[_memberID]
                    .voucherListMember[_hashVoucherCode]
                    .status = _newStatus;
                break;
            }
        }
    }

    function issueVoucher(
        uint256 _memberID,
        uint256 _voucherValue,
        bytes32 _hashVoucherCode
    ) internal {
        //The voucher Code is generated off-chain. The off-Chain program gives a hashVoucherCode back.
        //An Event is used to trigger the process off-chain to generate a voucher Code.
        //Only the member ID is given in the log file to guarantee a higher security.
        emit GenerateVoucherCode(memberList[_memberID].memberID);

        //get the list of vouchers of the member as a one single voucher instance to facilitate the process
        voucher memory thisVoucher = voucher({
            memberID: _memberID,
            hashVoucherCode: _hashVoucherCode,
            issueTime: block.timestamp,
            voucherValue: _voucherValue,
            status: "Active"
        });

        //append to the voucher list of all members
        voucherList.push(thisVoucher);
        mapping(bytes32 => voucher) storage vouchers = memberList[_memberID]
            .voucherListMember;

        //now add to the voucher list of the member
        vouchers[_hashVoucherCode] = thisVoucher;
    }

    // When Voucher is expired, the voucher status is set to "Expired"
    function expireVoucher(uint256 _memberID) internal {
        for (uint256 i = 0; i < voucherList.length; i++) {
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

    function usePoints(uint256 _memberID, uint256 _point) internal {
        memberList[_memberID].totalPoints =
            memberList[_memberID].totalPoints -
            _point;
    }

    function calcPoints(string memory _docID, uint256 _memberID)
        internal
        view
        returns (uint256 _point)
    {
        uint256 multiple = 1; // set the initial value for multiple equal to 1

        if ((compareStrings(memberList[_memberID].status, "Member"))) {
            multiple = multiple * 100;
        } else if ((compareStrings(memberList[_memberID].status, "Insider"))) {
            multiple = multiple * 150;
        } else if ((compareStrings(memberList[_memberID].status, "VIP"))) {
            multiple = multiple * 200;
        }
        for (uint256 i = 0; i < docList.length; i++) {
            if (compareStrings(docList[i].docID, _docID)) {
                _point += docList[i].price * multiple;
            }
        }
        return _point;
    }

    function compareStrings(string memory s1, string memory s2)
        internal
        pure
        returns (bool)
    {
        return
            keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2));
    }
}
