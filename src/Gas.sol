// SPDX-License-Identifier: UNLICENSED
// 2659266
// 2601344
// 2588141
// 2588129
// 2518121
// 2512930
// 2443511
// 2438164
// 2432216
// 2432204
// 2432216
// 2432204
// 2401239
// 2284755
// 2261627
// 2055244
// 2005190
// 1975618
// 1975606
// 1960268
// 1935220

pragma solidity ^0.8.28;

error ErrorinGas();
error ContractHacked();
error NotSender();
error ErrorGetPayments();
error InsufficientBalance();
error CheckIfWhitelisted();


contract GasContract {
    bool public constant flag = true;
    uint256 public totalSupply = 0; // cannot be updated
    uint256 public paymentCounter = 0;
    mapping(address => uint256) public balances;
    uint256 private constant tradePercent = 12;
    address public contractOwner;
    uint256 public tradeMode = 0;
    mapping(address => Payment[]) public payments;
    mapping(address => uint256) public whitelist;
    address[5] public administrators;
    bool public isReady = false;
    enum PaymentType { Unknown, BasicPayment, Refund, Dividend, GroupPayment}

    PaymentType constant private defaultPayment = PaymentType.Unknown;

    History[] public paymentHistory; // when a payment was updated

    struct Payment {
        PaymentType paymentType;
        uint256 paymentID;
        bool adminUpdated;
        string recipientName; // max 8 characters
        address recipient;
        address admin; // administrators address
        uint256 amount;
    }

    struct History {
        uint256 lastUpdate;
        address updatedBy;
        uint256 blockNumber;
    }
    uint256 wasLastOdd = 1;
    mapping(address => uint256) public isOddWhitelistUser;

    struct ImportantStruct {
        uint256 amount;
        uint256 valueA; // max 3 digits
        uint256 bigValue;
        uint256 valueB; // max 3 digits
        bool paymentStatus;
        address sender;
    }
    mapping(address => ImportantStruct) public whiteListStruct;

    event AddedToWhitelist(address userAddress, uint256 tier);
    // "Gas Contract Only Admin Check-  Caller not admin"
    modifier onlyAdminOrOwner() {
        address senderOfTx = msg.sender;
        if (checkForAdmin(senderOfTx)) {
            require(
                checkForAdmin(senderOfTx),
                ErrorinGas()
            );
            _;
        } else if (senderOfTx == contractOwner) {
            _;
        } else {
            revert ErrorinGas();
        }
    }
    // require message 1 == "Gas Contract CheckIfWhiteListed modifier : revert happened because the originator of the transaction was not the sender"
    // require message 2 == "Gas Contract CheckIfWhiteListed modifier : revert happened because the user is not whitelisted"
    // require message 3 == "Gas Contract CheckIfWhiteListed modifier : revert happened because the user's tier is incorrect, it cannot be over 4 as the only tier we have are: 1, 2, 3; therfore 4 is an invalid tier for the whitlist of this contract. make sure whitlist tiers were set correctly"
    modifier checkIfWhiteListed(address sender) {
        address senderOfTx = msg.sender;
        require(
            senderOfTx == sender,
            ErrorinGas()
        );
        uint256 usersTier = whitelist[senderOfTx];
        require(
            usersTier > 0,
            ErrorinGas()
        );
        require(
            usersTier < 4,
            ErrorinGas()
        );
        _;
    }

    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event PaymentUpdated(
        address admin,
        uint256 ID,
        uint256 amount,
        string recipient
    );
    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        totalSupply = _totalSupply;

        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (_admins[ii] != address(0)) {
                administrators[ii] = _admins[ii];
                if (_admins[ii] == contractOwner) {
                    balances[contractOwner] = totalSupply;
                } else {
                    balances[_admins[ii]] = 0;
                }
                if (_admins[ii] == contractOwner) {
                    emit supplyChanged(_admins[ii], totalSupply);
                } else if (_admins[ii] != contractOwner) {
                    emit supplyChanged(_admins[ii], 0);
                }
            }
        }
    }

    function getPaymentHistory()
        public
        payable
        returns (History[] memory paymentHistory_)
    {
        return paymentHistory;
    }

    function checkForAdmin(address _user) public view returns (bool admin_) {
        bool admin = false;
        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (administrators[ii] == _user) {
                admin = true;
            }
        }
        return admin;
    }

    function balanceOf(address _user) public view returns (uint256 balance_) {
        uint256 balance = balances[_user];
        return balance;
    }

    function getTradingMode() public pure returns (bool) {
        return flag;
    }


    function addHistory(address _updateAddress, bool _tradeMode)
        public
        returns (bool status_, bool tradeMode_)
    {
        History memory history;
        history.blockNumber = block.number;
        history.lastUpdate = block.timestamp;
        history.updatedBy = _updateAddress;
        paymentHistory.push(history);
        bool[] memory status = new bool[](tradePercent);
        for (uint256 i = 0; i < tradePercent; i++) {
            status[i] = true;
        }
        return ((status[0] == true), _tradeMode);
    }

    function getPayments(address _user)
        public
        view
        returns (Payment[] memory payments_)
    {
        require(
            _user != address(0),
            ErrorGetPayments()
        );
        return payments[_user];
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public returns (bool status_) {
        address senderOfTx = msg.sender;

        // Cache balances in memory to minimize storage access
        uint256 senderBalance = balances[senderOfTx];
        uint256 recipientBalance = balances[_recipient];

        // Ensure the sender has enough balance and the recipient's name length is within the limit
        require(senderBalance >= _amount, ErrorinGas());
        require(bytes(_name).length < 9, ErrorinGas());

        // Update balances in memory first, then write back to storage
        unchecked {
            senderBalance -= _amount;
            recipientBalance += _amount;
        }

        balances[senderOfTx] = senderBalance;
        balances[_recipient] = recipientBalance;

        // Emit the transfer event
        emit Transfer(_recipient, _amount);

        // Create a payment object
        Payment memory payment = Payment({
            admin: address(0),
            adminUpdated: false,
            paymentType: PaymentType.BasicPayment,
            recipient: _recipient,
            amount: _amount,
            recipientName: _name,
            paymentID: ++paymentCounter
        });

        // Store the payment in the sender's payment array
        payments[senderOfTx].push(payment);

        // Return true since status is no longer an array
        return true;
    }


    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        PaymentType _type
    ) public onlyAdminOrOwner {
        require(
            _ID > 0,
            ErrorinGas()
        );
        require(
            _amount > 0,
            ErrorinGas()
        );
        require(
            _user != address(0),
            ErrorinGas()
        );

        address senderOfTx = msg.sender;

        for (uint256 ii = 0; ii < payments[_user].length; ii++) {
            if (payments[_user][ii].paymentID == _ID) {
                payments[_user][ii].adminUpdated = true;
                payments[_user][ii].admin = _user;
                payments[_user][ii].paymentType = _type;
                payments[_user][ii].amount = _amount;
                bool tradingMode = getTradingMode();
                addHistory(_user, tradingMode);
                emit PaymentUpdated(
                    senderOfTx,
                    _ID,
                    _amount,
                    payments[_user][ii].recipientName
                );
            }
        }
    }

    function addToWhitelist(address _userAddrs, uint256 _tier)
        public
        onlyAdminOrOwner
    {
        require(
            _tier < 255,
            ErrorinGas()
        );
        whitelist[_userAddrs] = _tier;
        if (_tier > 3) {
            whitelist[_userAddrs] -= _tier;
            whitelist[_userAddrs] = 3;
        } else if (_tier == 1) {
            whitelist[_userAddrs] -= _tier;
            whitelist[_userAddrs] = 1;
        } else if (_tier > 0 && _tier < 3) {
            whitelist[_userAddrs] -= _tier;
            whitelist[_userAddrs] = 2;
        }
        uint256 wasLastAddedOdd = wasLastOdd;
        if (wasLastAddedOdd == 1) {
            wasLastOdd = 0;
            isOddWhitelistUser[_userAddrs] = wasLastAddedOdd;
        } else if (wasLastAddedOdd == 0) {
            wasLastOdd = 1;
            isOddWhitelistUser[_userAddrs] = wasLastAddedOdd;
        } else {
            revert ContractHacked();
        }
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount
    ) public checkIfWhiteListed(msg.sender) {
        address senderOfTx = msg.sender;
        whiteListStruct[senderOfTx] = ImportantStruct(_amount, 0, 0, 0, true, msg.sender);

        require(
            balances[senderOfTx] >= _amount,
            ErrorinGas()
        );
        require(
            _amount > 3,
            ErrorinGas()
        );
        unchecked{
            balances[senderOfTx] -= _amount;
            balances[_recipient] += _amount;
            balances[senderOfTx] += whitelist[senderOfTx];
            balances[_recipient] -= whitelist[senderOfTx];
        }

        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(address sender) public view returns (bool, uint256) {
        return (whiteListStruct[sender].paymentStatus, whiteListStruct[sender].amount);
    }

    receive() external payable {
        payable(msg.sender).transfer(msg.value);
    }


    fallback() external payable {
         payable(msg.sender).transfer(msg.value);
    }
}