

pragma solidity 0.8.18;

import '@openzeppelin/contracts/access/Ownable2Step.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './interfaces/IUnusPayRouter.sol';

/// @title UnusPayRouter
/// @notice This contract handles payments and token conversions.
/// @dev Inherit from Ownable2Step for ownership functionalities.
contract UnusPayRouter is Ownable2Step {
    using SafeERC20 for IERC20;

    // Custom errors
    error PaymentDeadlineReached(string msg);
    error WrongAmountPaidIn(string msg);
    error WrongTokens();
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
    address private constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice List of approved exchanges for conversion.
    mapping(address => bool) public exchanges;

    /// @dev Initializes the contract
    constructor() {

    }

    /// @notice Accepts NATIVE payments, which is required in order to swap from and to NATIVE, especially unwrapping as part of conversions.
    receive() external payable {}

    /// @dev Transfer polyfil event for internal transfers.
    event InternalTransfer(address indexed from, address indexed to, uint256 value);
    event Step(uint32 step);



    /// @notice Handles the payment process for external callers.
    /// @param payment The payment data.
    /// @return Returns true if successful.
    function pay(IUnusPayRouter.Payment calldata payment) external payable returns (bool) {
        return _pay(payment);
    }
    function convert(IUnusPayRouter.FromToken[] calldata payment) external payable  {
          _convert(payment);
    }

    /// @dev Handles the payment process (tokenIn approval has been granted prior).
    /// @param payment The payment data.
    /// @return Returns true if successful.
    function _pay(IUnusPayRouter.Payment calldata payment) internal returns (bool) {
        uint256[] memory balanceInBefore = new uint256[](payment.fromTokens.length);
        uint256[] memory balanceOutBefore = new uint256[](payment.toTokens.length);
        emit Step(1);
        _validatePreConditionsTokenIn(payment, balanceInBefore);
        emit Step(2);
        _validatePreConditionsTokenOut(payment, balanceOutBefore);
        emit Step(3);
        _payIn(payment);
        emit Step(4);
        _performPayment(payment);
        emit Step(8);
        _validatePostConditions(payment, balanceInBefore, balanceOutBefore);
        emit Step(9);
        return true;
    }


    /// @dev Validates the pre-conditions for a payment.
    /// @param payment The payment data.
    function _validatePreConditionsTokenIn(
        IUnusPayRouter.Payment calldata payment, uint256[] memory balanceInBefore
    ) internal {

        for (uint i = 0; i < payment.fromTokens.length; i++) {
            // Store tokenIn balance prior to payment
            if (payment.fromTokens[i].tokenAddress == NATIVE) {
                balanceInBefore[i] = address(this).balance - msg.value;
            } else {
                balanceInBefore[i] = IERC20(payment.fromTokens[i].tokenAddress).balanceOf(address(this));
            }
        }

    }

    /// @dev Validates the pre-conditions for a payment.
    /// @param payment The payment data.
    function _validatePreConditionsTokenOut(
        IUnusPayRouter.Payment calldata payment, uint256[] memory balanceOutBefore
    ) internal {

        for (uint i = 0; i < payment.toTokens.length; i++) {
            // Store tokenIn balance prior to payment
            if (payment.toTokens[i].tokenAddress == NATIVE) {
                balanceOutBefore[i] = address(this).balance - msg.value;
            } else {
                balanceOutBefore[i] = IERC20(payment.toTokens[i].tokenAddress).balanceOf(address(this));
            }
        }

    }



    /// @dev Processes the payIn operations.
    /// @param payment The payment data.
    function _payIn(IUnusPayRouter.Payment calldata payment) internal {
        for (uint i = 0; i < payment.fromTokens.length; i++) {
            if (payment.fromTokens[i].tokenAddress == NATIVE) {
                // Make sure that the sender has paid in the correct token & amount
                if (msg.value != payment.fromTokens[i].amount) {
                    revert WrongAmountPaidIn("11111");
                }
            } else {
                IERC20(payment.fromTokens[i].tokenAddress).safeTransferFrom(
                    msg.sender,
                    address(this),
                    payment.fromTokens[i].amount
                );
            }
        }
    }


    /// @dev Processes the payment.
    /// @param payment The payment data.
    function _performPayment(IUnusPayRouter.Payment calldata payment) internal {
        // Perform conversion if required
        _convert(payment.fromTokens);
        // Perform payment to paymentReceiver
        emit Step(6);
        _payReceiver(payment);

        // Perform payment to feeReceiver
        if (payment.feeReceiverAddress != address(0)) {
            emit Step(7);
            _payFee(payment);
        }
    }

    /// @dev Validates the post-conditions for a payment.
    /// @param payment The payment data.
    /// @param balanceInBefore The balance in before the payment.
    /// @param balanceOutBefore The balance out before the payment.
    function _validatePostConditions(
        IUnusPayRouter.Payment calldata payment,
        uint256[] memory balanceInBefore,
        uint256[] memory balanceOutBefore
    ) internal view {
        // Ensure balances of tokenIn remained
        for (uint i = 0; i < payment.fromTokens.length; i++) {
            if (payment.fromTokens[i].tokenAddress == NATIVE) {
                if (address(this).balance < balanceInBefore[i]) {
                    revert InsufficientBalanceInAfterPayment("22222");
                }
            } else {
                if (IERC20(payment.fromTokens[i].tokenAddress).balanceOf(address(this)) < balanceInBefore[i]) {
                    revert InsufficientBalanceInAfterPayment("33333");
                }
            }
        }
        for (uint i = 0; i < payment.toTokens.length; i++) {
            // Ensure balances of tokenOut remained
            if (payment.toTokens[i].tokenAddress == NATIVE) {
                if (address(this).balance < balanceOutBefore[i]) {
                    revert InsufficientBalanceOutAfterPayment("44444");
                }
            } else {
                if (IERC20(payment.toTokens[i].tokenAddress).balanceOf(address(this)) < balanceOutBefore[i]) {
                    revert InsufficientBalanceOutAfterPayment("55555");
                }
            }
        }
    }



    function _convert(IUnusPayRouter.FromToken[] calldata  fromTokens) internal {

        for (uint i = 0; i < fromTokens.length; i++) {

            if (!exchanges[fromTokens[i].exchangeAddress]) {
                revert ExchangeNotApproved("66666");
            }
            bool success;
            if (fromTokens[i].tokenAddress == NATIVE) {
                if (fromTokens[i].exchangeCallData.length == 0) {
                    revert ExchangeCallMissing("77777");
                }
                (success,) = fromTokens[i].exchangeAddress.call{value: msg.value}(fromTokens[i].exchangeCallData);
            } else {
                if (fromTokens[i].exchangeType == 1) {
                    // pull
                    IERC20(fromTokens[i].tokenAddress).safeApprove(fromTokens[i].exchangeAddress, fromTokens[i].amount);
                } else if (fromTokens[i].exchangeType == 2) {
                    // push
                    IERC20(fromTokens[i].tokenAddress).safeTransfer(
                        fromTokens[i].exchangeAddress,
                        fromTokens[i].amount
                    );
                }
                (success,) = fromTokens[i].exchangeAddress.call(fromTokens[i].exchangeCallData);
                if (fromTokens[i].exchangeType == 1) {
                    // pull
                    IERC20(fromTokens[i].tokenAddress).safeApprove(fromTokens[i].exchangeAddress, 0);
                }
            }
            if (!success) {
                revert ExchangeCallFailed("88888");
            }
        }
    }

    /// @dev Processes payment to receiver.
    /// @param payment The payment data.
    function _payReceiver(IUnusPayRouter.Payment calldata payment) internal {

        // just send payment to address
        for (uint i = 0; i < payment.toTokens.length; i++) {
            if (payment.toTokens[i].tokenAddress == NATIVE) {
                if (payment.paymentReceiverAddress == address(0)) {
                    revert PaymentToZeroAddressNotAllowed("10101010");
                }
                (bool success,) = payment.paymentReceiverAddress.call{value: payment.toTokens[i].amount}(new bytes(0));
                if (!success) {
                    revert NativePaymentFailed("1212121212");
                }
                emit InternalTransfer(msg.sender, payment.paymentReceiverAddress, payment.toTokens[i].amount);
            } else {
                IERC20(payment.toTokens[i].tokenAddress).safeTransfer(
                    payment.paymentReceiverAddress,
                    payment.toTokens[i].amount
                );
            }
        }

    }

    /// @dev Processes fee payments.
    /// @param payment The payment data.
    function _payFee(IUnusPayRouter.Payment calldata payment) internal {
        for (uint i = 0; i < payment.toTokens.length; i++) {
            if (payment.toTokens[i].tokenAddress == NATIVE) {
                (bool success,) = payment.feeReceiverAddress.call{value: payment.toTokens[i].feeAmount}(new bytes(0));
                if (!success) {
                    revert NativeFeePaymentFailed("13131313");
                }
                emit InternalTransfer(msg.sender, payment.feeReceiverAddress, payment.toTokens[i].feeAmount);
            } else {
                IERC20(payment.toTokens[i].tokenAddress).safeTransfer(
                    payment.feeReceiverAddress,
                    payment.toTokens[i].feeAmount
                );
            }
        }
    }

    /// @dev Event emitted if new exchange has been enabled.
    event Enabled(address indexed exchange);

    /// @dev Event emitted if an exchange has been disabled.
    event Disabled(address indexed exchange);

    /// @notice Enables or disables an exchange.
    /// @param exchange The address of the exchange.
    /// @param enabled A boolean value to enable or disable the exchange.
    /// @return Returns true if successful.
    function enable(address exchange, bool enabled) external onlyOwner returns (bool) {
        exchanges[exchange] = enabled;
        if (enabled) {
            emit Enabled(exchange);
        } else {
            emit Disabled(exchange);
        }
        return true;
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
