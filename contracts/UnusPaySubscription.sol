
pragma solidity 0.8.18;

import '@openzeppelin/contracts/access/Ownable2Step.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './interfaces/IUnusPaySubscription.sol';
import './interfaces/IUnusPayRouter.sol';

/// @title UnusPaySubscription
/// @notice This contract handles payments and token conversions.
/// @dev Inherit from Ownable2Step for ownership functionalities.
contract UnusPaySubscription is Ownable2Step {
    using SafeERC20 for IERC20;

    // Custom errors
    error PaymentDeadlineReached();
    error WrongAmountPaidIn();
    error WrongTokens();
    error InvalidPlan();
    error NotSubscribed();
    error NotTimeYet();
    error WrongNextPayTime();
    error ExchangeNotApproved();
    error ExchangeCallMissing();
    error ExchangeCallFailed();
    error ForwardingPaymentFailed();
    error NativePaymentFailed();
    error NativeFeePaymentFailed();
    error PaymentToZeroAddressNotAllowed();
    error InsufficientBalanceInAfterPayment();
    error InsufficientBalanceOutAfterPayment();

    /// @notice Address representing the NATIVE token (e.g. ETH, BNB, MATIC, etc.)
    address private  constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;


    mapping(bytes => IUnusPaySubscription.SubscriptionInfo) public subscriptions;
    address public immutable CONVERTER;
    /// @dev Initializes the contract
    constructor(address _converter) {
        CONVERTER = _converter;
    }

    /// @notice Accepts NATIVE payments, which is required in order to swap from and to NATIVE, especially unwrapping as part of conversions.
    receive() external payable {}

    /// @dev Transfer polyfil event for internal transfers.
    event InternalTransfer(address indexed from, address indexed to, uint256 value);
    event SubscriptionCreated(address indexed from, string orderNo, uint32 plan, uint32 instalments);
    event Step(uint32 step);

    function subAndPay(IUnusPaySubscription.SubPayment calldata payment) external payable returns (bool) {
        return _subAndPay(payment);
    }

    function subPay(IUnusPaySubscription.SubPayment calldata payment) external payable returns (bool) {
        return _subPay(payment);
    }

    function subInfo(string calldata orderNo) external returns (IUnusPaySubscription.SubscriptionInfo memory) {
        bytes memory addressAndOrder = abi.encodePacked(msg.sender, orderNo);
        return subscriptions[addressAndOrder];
    }


    function _subAndPay(IUnusPaySubscription.SubPayment calldata payment) internal returns (bool) {

        if (payment.deadline < block.timestamp) {
            revert PaymentDeadlineReached();
        }

        uint256 balanceInBefore;
        uint256 balanceOutBefore;
        (balanceInBefore, balanceOutBefore) = _validatePreConditions(payment.fromToken);

        emit Step(2);
        emit Step(3);
        _payIn(payment.fromToken);
        emit Step(4);
        _performPayment(payment);
        emit Step(8);
        _validatePostConditions(payment.fromToken, balanceInBefore, balanceOutBefore);

        emit Step(9);
        _saveSubInfo(payment);
        return true;
    }

    function _subPay(IUnusPaySubscription.SubPayment calldata payment) internal returns (bool) {
        if (payment.deadline < block.timestamp) {
            revert PaymentDeadlineReached();
        }
        bytes memory addressAndOrder = abi.encodePacked(msg.sender, payment.orderNo);
        IUnusPaySubscription.SubscriptionInfo memory subInfo = subscriptions[addressAndOrder];
        if (subInfo.plan == 0) {
            revert NotSubscribed();
        }
        if (subInfo.plan == 2) {
            //小时级订阅,支付时间最少要在上次支付的50分钟之后
            if (block.timestamp - subInfo.lastPayTime < 60 * 50) {
                revert NotTimeYet();
            }

        } else if (subInfo.plan == 3) {
            //天级订阅,支付时间最少要在上次支付的20小时之后
            if (block.timestamp - subInfo.lastPayTime < 3600 * 20) {
                revert NotTimeYet();
            }


        } else if (subInfo.plan == 4) {
            //周级订阅,支付时间最少要在上次支付的5天之后
            if (block.timestamp - subInfo.lastPayTime < 3600 * 24 * 5) {
                revert NotTimeYet();
            }


        } else if (subInfo.plan == 5) {
            //月级订阅,支付时间最少要在上次支付的25天之后
            if (block.timestamp - subInfo.lastPayTime < 3600 * 24 * 25) {
                revert NotTimeYet();
            }

        } else if (subInfo.plan == 6) {
            //月级订阅,支付时间最少要在上次支付的335天之后
            if (block.timestamp - subInfo.lastPayTime < 3600 * 24 * 335) {
                revert NotTimeYet();
            }

        }
        uint256 balanceInBefore;
        uint256 balanceOutBefore;
        (balanceInBefore, balanceOutBefore) = _validatePreConditions(payment.fromToken);

        emit Step(2);
        emit Step(3);
        _payIn(payment.fromToken);
        emit Step(4);
        _performPayment(payment);
        emit Step(8);
        _validatePostConditions(payment.fromToken, balanceInBefore, balanceOutBefore);

        emit Step(9);


        if (subInfo.remaining == 1) {
            delete subscriptions[addressAndOrder];
        } else {
            if (subInfo.instalments != 0) {
                subInfo.remaining--;
            }
            subInfo.lastPayTime = block.timestamp;
            subscriptions[addressAndOrder] = subInfo;
        }

        return true;
    }


    function _validatePreConditions(IUnusPayRouter.FromToken calldata fromToken) internal returns (uint256 balanceInBefore, uint256 balanceOutBefore) {
        // Make sure payment deadline has not been passed, yet

        // Store tokenIn balance prior to payment
        if (fromToken.tokenAddress == NATIVE) {
            balanceInBefore = address(this).balance - msg.value;
        } else {
            balanceInBefore = IERC20(fromToken.tokenAddress).balanceOf(address(this));
        }

        // Store tokenOut balance prior to payment
        if (fromToken.swapTokenAddress == NATIVE) {
            balanceOutBefore = address(this).balance - msg.value;
        } else {
            balanceOutBefore = IERC20(fromToken.swapTokenAddress).balanceOf(address(this));
        }
    }


    function _validatePostConditions(IUnusPayRouter.FromToken calldata fromToken, uint256 balanceInBefore, uint256 balanceOutBefore) internal view {
        // Ensure balances of tokenIn remained
        if (fromToken.tokenAddress == NATIVE) {
            if (address(this).balance < balanceInBefore) {
                revert InsufficientBalanceInAfterPayment();
            }
        } else {
            if (IERC20(fromToken.tokenAddress).balanceOf(address(this)) < balanceInBefore) {
                revert InsufficientBalanceInAfterPayment();
            }
        }
        if (fromToken.exchangeAddress != address(0)) {
            // Ensure balances of tokenOut remained
            if (fromToken.swapTokenAddress == NATIVE) {
                if (address(this).balance < balanceOutBefore) {
                    revert InsufficientBalanceOutAfterPayment();
                }
            } else {
                if (IERC20(fromToken.swapTokenAddress).balanceOf(address(this)) < balanceOutBefore) {
                    revert InsufficientBalanceOutAfterPayment();
                }
            }
        }
    }

    function _saveSubInfo(IUnusPaySubscription.SubPayment calldata payment) internal {
        // Ensure balances of tokenIn remained
        bytes memory addressAndOrder = abi.encodePacked(msg.sender, payment.orderNo);
        uint32 remaining = 0;
        if (payment.instalments > 0) {
            remaining = payment.instalments - 1;
        }

        IUnusPaySubscription.SubscriptionInfo memory subInfo = IUnusPaySubscription.SubscriptionInfo({plan: payment.plan, instalments: payment.instalments, remaining: remaining, lastPayTime: block.timestamp});
        subscriptions[addressAndOrder] = subInfo;
        emit SubscriptionCreated(msg.sender, payment.orderNo, payment.plan, payment.instalments);

    }

    function _validatePreTokenBalance(
        address token
    ) internal returns (uint256) {

        // Store tokenIn balance prior to payment
        if (token == NATIVE) {
            return address(this).balance - msg.value;
        } else {
            return IERC20(token).balanceOf(address(this));
        }

    }

    /// @dev Processes the payIn operations.
    /// @param fromToken The payment data.
    function _payIn(IUnusPayRouter.FromToken calldata fromToken) internal {
        if (fromToken.tokenAddress == NATIVE) {
            // Make sure that the sender has paid in the correct token & amount
            if (msg.value != fromToken.amount) {
                revert WrongAmountPaidIn();
            }
        } else {
            IERC20(fromToken.tokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                fromToken.amount
            );
        }
    }

    /// @dev Processes the payment.
    /// @param payment The payment data.
    function _performPayment(IUnusPaySubscription.SubPayment calldata payment) internal {
        // Perform conversion if required
        if (payment.fromToken.exchangeAddress != address(0)) {
            IUnusPayRouter.FromToken[] memory fromTokens;
            fromTokens[0] = payment.fromToken;
            IUnusPayRouter(CONVERTER).convert(fromTokens);
        }

        // Perform payment to paymentReceiver
        emit Step(6);
        _payReceiver(payment);

        // Perform payment to feeReceiver
        if (payment.feeReceiverAddress != address(0)) {
            emit Step(7);
            _payFee(payment);
        }
    }

    /// @dev Processes payment to receiver.
    /// @param payment The payment data.
    function _payReceiver(IUnusPaySubscription.SubPayment calldata payment) internal {

        // just send payment to address
        if (payment.fromToken.swapTokenAddress == NATIVE) {
            if (payment.paymentReceiverAddress == address(0)) {
                revert PaymentToZeroAddressNotAllowed();
            }
            (bool success,) = payment.paymentReceiverAddress.call{value: payment.payAmount}(new bytes(0));
            if (!success) {
                revert NativePaymentFailed();
            }
            emit InternalTransfer(msg.sender, payment.paymentReceiverAddress, payment.payAmount);
        } else {
            IERC20(payment.fromToken.swapTokenAddress).safeTransfer(
                payment.paymentReceiverAddress,
                payment.payAmount
            );
        }

    }

    /// @dev Processes fee payments.
    /// @param payment The payment data.
    function _payFee(IUnusPaySubscription.SubPayment calldata payment) internal {
        if (payment.fromToken.swapTokenAddress == NATIVE) {
            (bool success,) = payment.feeReceiverAddress.call{value: payment.feeAmount}(new bytes(0));
            if (!success) {
                revert NativeFeePaymentFailed();
            }
            emit InternalTransfer(msg.sender, payment.feeReceiverAddress, payment.feeAmount);
        } else {
            IERC20(payment.fromToken.swapTokenAddress).safeTransfer(
                payment.feeReceiverAddress,
                payment.feeAmount
            );
        }
    }

    /// @notice Allows the owner to withdraw accidentally sent tokens.
    /// @param token The token address.
    /// @param amount The amount to withdraw.
    function withdraw(address token, uint amount) external onlyOwner returns (bool) {
        if (token == NATIVE) {
            (bool success,) = address(msg.sender).call{value: amount}(new bytes(0));
            require(success, 'UnusPay: withdraw failed!');
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }
        return true;
    }
}
