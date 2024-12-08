// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import '@openzeppelin/contracts/access/Ownable2Step.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './interfaces/IPermit2.sol';
import './interfaces/IUnusPaySubscription.sol';
import './interfaces/IUnusPayRouter.sol';

/// @title UnusPaySubscription
/// @notice This contract handles payments and token conversions.
/// @dev Inherit from Ownable2Step for ownership functionalities.
contract UnusPaySubscription is Ownable2Step {
    using SafeERC20 for IERC20;

    // Custom errors
    error PaymentDeadlineReached(string msg);
    error WrongAmountPaidIn(string msg);
    error WrongTokens();
    error InvalidPlan();
    error NotSubscribed();
    error NotTimeYet();
    error WrongNextPayTime();
    error ExchangeNotApproved(string msg);
    error ExchangeCallMissing(string msg);
    error ExchangeCallFailed(string msg);
    error ForwardingPaymentFailed(string msg);
    error NativePaymentFailed(string msg);
    error NativeFeePaymentFailed(string msg);
    error PaymentToZeroAddressNotAllowed(string msg);
    error InsufficientBalanceInAfterPayment(string msg);
    error InsufficientBalanceOutAfterPayment(string msg);

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
    event SubscriptionCreated(address indexed from, string orderNo, uint32 plan, uint32 instalments, uint32 remaining, uint256 nextPayTime);
    event Step(uint32 step);

    function subAndPay(IUnusPaySubscription.SubAndPayment calldata payment) external payable returns (bool) {
        return _subAndPay(payment);
    }

    function subPay(IUnusPaySubscription.SubPayment calldata payment) external payable returns (bool) {
        return _subPay(payment);
    }

    function subInfo(string calldata orderNo) external payable returns (IUnusPaySubscription.SubscriptionInfo) {
        bytes memory addressAndOrder = abi.encodePacked(msg.sender, orderNo);
        return subscriptions[addressAndOrder];
    }


    function _subAndPay(IUnusPaySubscription.SubAndPayment calldata payment) internal returns (bool) {

        uint256 balanceInBefore;
        uint256 balanceOutBefore;
        (balanceInBefore, balanceOutBefore) = _validatePreConditions(payment);

        emit Step(2);
        emit Step(3);
        _payIn(payment);
        emit Step(4);
        _performPayment(payment);
        emit Step(8);
        _validatePostConditions(payment, balanceInBefore, balanceOutBefore);

        emit Step(9);
        _saveSubInfo(payment);
        return true;
    }

    function _subPay(IUnusPaySubscription.SubPayment calldata payment) internal returns (bool) {
        bytes memory addressAndOrder = abi.encodePacked(msg.sender, payment.orderNo);
        IUnusPaySubscription.SubscriptionInfo memory subInfo = subscriptions[addressAndOrder];
        if (subInfo == address(0)) {
            revert NotSubscribed();
        }
        if (subInfo.plan == 2) {
            if (subInfo.nextPayTime - block.timestamp > 60 * 10) {
                revert NotTimeYet();
            }
            if (subInfo.remaining != 1 && payment.nextPayTime - subInfo.nextPayTime < 3600 * 1) {
                revert WrongNextPayTime();
            }
        } else if (subInfo.plan == 3) {
            if (subInfo.nextPayTime - block.timestamp > 3600 * 2) {
                revert NotTimeYet();
            }
            if (subInfo.remaining != 1 && payment.nextPayTime - subInfo.nextPayTime < 3600 * 24) {
                revert WrongNextPayTime();
            }

        } else if (subInfo.plan == 4) {
            if (subInfo.nextPayTime - block.timestamp > 3600 * 24 * 2) {
                revert NotTimeYet();
            }
            if (subInfo.remaining != 1 && payment.nextPayTime - subInfo.nextPayTime < 3600 * 24 * 7) {
                revert WrongNextPayTime();
            }

        } else if (subInfo.plan == 5) {
            if (subInfo.nextPayTime - block.timestamp > 3600 * 24 * 10) {
                revert NotTimeYet();
            }
            if (subInfo.remaining != 1 && payment.nextPayTime - subInfo.nextPayTime < 3600 * 24 * 28) {
                revert WrongNextPayTime();
            }
        } else if (subInfo.plan == 6) {
            if (subInfo.nextPayTime - block.timestamp > 3600 * 24 * 30) {
                revert NotTimeYet();
            }
            if (subInfo.remaining != 1 && payment.nextPayTime - subInfo.nextPayTime < 3600 * 24 * 365) {
                revert WrongNextPayTime();
            }
        }
        uint256 balanceInBefore;
        uint256 balanceOutBefore;
        (balanceInBefore, balanceOutBefore) = _validatePreConditions(payment);

        emit Step(2);
        emit Step(3);
        _payIn(payment);
        emit Step(4);
        _performPayment(payment);
        emit Step(8);
        _validatePostConditions(payment, balanceInBefore, balanceOutBefore);

        emit Step(9);


        if (subInfo.instalments != 0 && subInfo.remaining == 1) {
            subscriptions[addressAndOrder] = address(0);
        } else {
            subInfo.remaining--;
            subInfo.nextPayTime = payment.nextPayTime;
        }
        subscriptions[addressAndOrder] = subInfo;
        return true;
    }


    function _validatePreConditions(IUnusPaySubscription.SubAndPayment calldata payment) internal returns (uint256 balanceInBefore, uint256 balanceOutBefore) {
        // Make sure payment deadline has not been passed, yet
        if (payment.deadline < block.timestamp) {
            revert PaymentDeadlineReached();
        }

        // Store tokenIn balance prior to payment
        if (payment.fromToken.tokenAddress == NATIVE) {
            balanceInBefore = address(this).balance - msg.value;
        } else {
            balanceInBefore = IERC20(payment.fromToken.tokenAddress).balanceOf(address(this));
        }

        // Store tokenOut balance prior to payment
        if (payment.fromToken.swapTokenAddress == NATIVE) {
            balanceOutBefore = address(this).balance - msg.value;
        } else {
            balanceOutBefore = IERC20(payment.fromToken.swapTokenAddress).balanceOf(address(this));
        }
    }

    function _validatePostConditions(IUnusPaySubscription.SubAndPayment calldata payment, uint256 balanceInBefore, uint256 balanceOutBefore) internal view {
        // Ensure balances of tokenIn remained
        if (payment.fromToken.tokenAddress == NATIVE) {
            if (address(this).balance < balanceInBefore) {
                revert InsufficientBalanceInAfterPayment();
            }
        } else {
            if (IERC20(payment.fromToken.tokenAddress).balanceOf(address(this)) < balanceInBefore) {
                revert InsufficientBalanceInAfterPayment();
            }
        }
        if (payment.fromToken.exchangeAddress != address(0)) {
            // Ensure balances of tokenOut remained
            if (payment.fromToken.swapTokenAddress == NATIVE) {
                if (address(this).balance < balanceOutBefore) {
                    revert InsufficientBalanceOutAfterPayment();
                }
            } else {
                if (IERC20(payment.fromToken.swapTokenAddress).balanceOf(address(this)) < balanceOutBefore) {
                    revert InsufficientBalanceOutAfterPayment();
                }
            }
        }
    }

    function _saveSubInfo(IUnusPaySubscription.SubAndPayment calldata payment) internal {
        // Ensure balances of tokenIn remained
        bytes memory addressAndOrder = abi.encodePacked(msg.sender, payment.orderNo);
        subscriptions[addressAndOrder] = payment.subInfo;
        emit SubscriptionCreated(msg.sender, payment.orderNo, payment.subInfo.plan, payment.subInfo.instalments, payment.subInfo.remaining, payment.subInfo.nextPayTime);

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
    /// @param payment The payment data.
    function _payIn(IUnusPaySubscription.SubAndPayment calldata payment) internal {
        if (payment.fromToken.tokenAddress == NATIVE) {
            // Make sure that the sender has paid in the correct token & amount
            if (msg.value != payment.fromToken.amount) {
                revert WrongAmountPaidIn("11111");
            }
        } else {
            IERC20(payment.fromToken.tokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                payment.fromToken.amount
            );
        }
    }

    function _payIn(address token, uint256 amount) internal {
        if (token == NATIVE) {
            // Make sure that the sender has paid in the correct token & amount
            if (msg.value != amount) {
                revert WrongAmountPaidIn("11111");
            }
        } else {
            IERC20(token).safeTransferFrom(
                msg.sender,
                address(this),
                amount
            );
        }
    }

    /// @dev Processes the payment.
    /// @param payment The payment data.
    function _performPayment(IUnusPaySubscription.SubAndPayment calldata payment) internal {
        // Perform conversion if required
        if (payment.fromToken.exchangeAddress != address(0)) {
            IUnusPayRouter(CONVERTER).convert([payment.fromToken]);
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
    function _payReceiver(IUnusPaySubscription.SubAndPayment calldata payment) internal {

        // just send payment to address
        if (payment.fromToken.swapTokenAddress == NATIVE) {
            if (payment.paymentReceiverAddress == address(0)) {
                revert PaymentToZeroAddressNotAllowed("10101010");
            }
            (bool success,) = payment.paymentReceiverAddress.call{value: payment.payAmount}(new bytes(0));
            if (!success) {
                revert NativePaymentFailed("1212121212");
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
    function _payFee(IUnusPaySubscription.SubAndPayment calldata payment) internal {
        if (payment.fromToken.swapTokenAddress == NATIVE) {
            (bool success,) = payment.feeReceiverAddress.call{value: payment.feeAmount}(new bytes(0));
            if (!success) {
                revert NativeFeePaymentFailed("13131313");
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
