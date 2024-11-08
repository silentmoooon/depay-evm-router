// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import '@openzeppelin/contracts/access/Ownable2Step.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './interfaces/IPermit2.sol';
import './interfaces/IUnusPayRouterV2.sol';
import './interfaces/IUnusPayForwarderV2.sol';

/// @title UnusPayRouterV2
/// @notice This contract handles payments and token conversions.
/// @dev Inherit from Ownable2Step for ownership functionalities.
contract UnusPayRouterV2 is Ownable2Step {
  using SafeERC20 for IERC20;

  // Custom errors
  error PaymentDeadlineReached();
  error WrongAmountPaidIn();
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
  address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /// @notice Address of PERMIT2
  address public immutable PERMIT2;

  /// @notice Address of the payment FORWARDER contract
  address public immutable FORWARDER;

  /// @notice List of approved exchanges for conversion.
  mapping(address => bool) public exchanges;

  /// @dev Initializes the contract with PERMIT2 and FORWARDER addresses.
  /// @param _PERMIT2 The address of the PERMIT2 contract.
  /// @param _FORWARDER The address of the FORWARDER contract.
  constructor(address _PERMIT2, address _FORWARDER) {
    PERMIT2 = _PERMIT2;
    FORWARDER = _FORWARDER;
  }

  /// @notice Accepts NATIVE payments, which is required in order to swap from and to NATIVE, especially unwrapping as part of conversions.
  receive() external payable {}

  /// @dev Transfer polyfil event for internal transfers.
  event InternalTransfer(address indexed from, address indexed to, uint256 value);

  /// @dev Handles the payment process (tokenIn approval has been granted prior).
  /// @param payment The payment data.
  /// @return Returns true if successful.
  function _pay(IUnusPayRouterV2.Payment calldata payment) internal returns (bool) {
    uint256[] balanceInBefore;
    uint256[] balanceOutBefore;

    balanceInBefore = _validatePreConditionsTokenIn(payment);
    balanceOutBefore = _validatePreConditionsTokenOut(payment);
    _payIn(payment);
    _performPayment(payment);
    _validatePostConditions(payment, balanceInBefore, balanceOutBefore);

    return true;
  }

  /// @notice Handles the payment process for external callers.
  /// @param payment The payment data.
  /// @return Returns true if successful.
  function pay(IUnusPayRouterV2.Payment calldata payment) external payable returns (bool) {
    return _pay(payment);
  }

  /// @dev Handles the payment process with permit2 SignatureTransfer.
  /// @param payment The payment data.
  /// @param permitTransferFromAndSignature The PermitTransferFrom and signature.
  /// @return Returns true if successful.
  function _pay(
    IUnusPayRouterV2.Payment calldata payment,
    IUnusPayRouterV2.PermitTransferFromAndSignature calldata permitTransferFromAndSignature
  ) internal returns (bool) {
    if (payment.deadline < block.timestamp) {
      revert PaymentDeadlineReached();
    }

    uint256[] balanceInBefore;
    uint256[] balanceOutBefore;

    balanceInBefore = _validatePreConditionsTokenIn(payment);
    balanceOutBefore = _validatePreConditionsTokenOut(payment);

    _payIn(payment, permitTransferFromAndSignature);
    // Perform conversion if required
    if (payment.exchangeAddress != address(0)) {
      _convert(payment);
    }
    // Perform payment to paymentReceiver
    _payReceiver(payment);

    // Perform payment to feeReceiver
    if (payment.feeReceiverAddress != address(0)) {
      _payFee(payment);
    }
    _validatePostConditions(payment, balanceInBefore, balanceOutBefore);

    return true;
  }

  /// @notice Handles the payment process with permit2 SignatureTransfer for external callers.
  /// @param payment The payment data.
  /// @param permitTransferFromAndSignature The PermitTransferFrom and signature.
  /// @return Returns true if successful.
  function pay(
    IUnusPayRouterV2.Payment calldata payment,
    IUnusPayRouterV2.PermitTransferFromAndSignature calldata permitTransferFromAndSignature
  ) external payable returns (bool) {
    return _pay(payment, permitTransferFromAndSignature);
  }

  /// @dev Handles the payment process with permit2 AllowanceTransfer.
  /// @param payment The payment data.
  /// @param permitSingle The permit single data.
  /// @param signature The permit signature.
  /// @return Returns true if successful.
  function _pay(
    IUnusPayRouterV2.Payment calldata payment,
    IPermit2.PermitSingle calldata permitSingle,
    bytes calldata signature
  ) internal returns (bool) {
    uint256 balanceInBefore;
    uint256 balanceOutBefore;

    (balanceInBefore, balanceOutBefore) = _validatePreConditions(payment);
    _permit(permitSingle, signature);
    _payIn(payment);
    _performPayment(payment);
    _validatePostConditions(payment, balanceInBefore, balanceOutBefore);

    return true;
  }

  /// @notice Handles the payment process with permit2 AllowanceTransfer for external callers.
  /// @param payment The payment data.
  /// @param permitSingle The permit single data.
  /// @param signature The permit signature.
  /// @return Returns true if successful.
  function pay(
    IUnusPayRouterV2.Payment calldata payment,
    IPermit2.PermitSingle calldata permitSingle,
    bytes calldata signature
  ) external payable returns (bool) {
    return _pay(payment, permitSingle, signature);
  }

  /// @dev Validates the pre-conditions for a payment.
  /// @param payment The payment data.
  /// @return balanceInBefore The balance in before the payment.
  /// @return balanceOutBefore The balance out before the payment.
  function _validatePreConditionsTokenIn(
    IUnusPayRouterV2.Payment calldata payment
  ) internal returns (uint256[] balanceInBefore) {
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
  /// @return balanceInBefore The balance in before the payment.
  /// @return balanceOutBefore The balance out before the payment.
  function _validatePreConditionsTokenOut(
    IUnusPayRouterV2.Payment calldata payment
  ) internal returns (uint256 balanceOutBefore) {
    // Store tokenOut balance prior to payment
    for (uint i = 0; i < payment.toTokens.length; i++) {
      // Store tokenIn balance prior to payment
      if (payment.toTokens[i].tokenAddress == NATIVE) {
        balanceOutBefore[i] = address(this).balance - msg.value;
      } else {
        balanceOutBefore[i] = IERC20(payment.toTokens[i].tokenAddress).balanceOf(address(this));
      }
    }
  }

  /// @dev Handles permit2 operations.
  /// @param permitSingle The permit single data.
  /// @param signature The permit signature.
  function _permit(IPermit2.PermitSingle calldata permitSingle, bytes calldata signature) internal {
    IPermit2(PERMIT2).permit(
      msg.sender, // owner
      permitSingle,
      signature
    );
  }

  /// @dev Processes the payIn operations.
  /// @param payment The payment data.
  function _payIn(IUnusPayRouterV2.Payment calldata payment) internal {
    for (uint i = 0; i < payment.fromTokens.length; i++) {
      if (payment.fromTokens[i].tokenInAddress == NATIVE) {
        // Make sure that the sender has paid in the correct token & amount
        if (msg.value != payment.amountIn) {
          revert WrongAmountPaidIn();
        }
      } else if (payment.permit2) {
        IPermit2(PERMIT2).transferFrom(
          msg.sender,
          address(this),
          uint160(payment.fromTokens[i].amount),
          payment.fromTokens[i].tokenInAddress
        );
      } else {
        IERC20(payment.fromTokens[i].tokenInAddress).safeTransferFrom(
          msg.sender,
          address(this),
          payment.fromTokens[i].amount
        );
      }
    }
  }

  /// @dev Processes the payIn operations (exlusively for permit2 SignatureTransfer).
  /// @param payment The payment data.
  /// @param permitTransferFromAndSignature permitTransferFromAndSignature for permit2 permitTransferFrom.
  function _payIn(
    IUnusPayRouterV2.Payment calldata payment,
    IUnusPayRouterV2.PermitTransferFromAndSignature calldata permitTransferFromAndSignature
  ) internal {
    IPermit2(PERMIT2).permitTransferFrom(
      permitTransferFromAndSignature.permitTransferFrom,
      IPermit2.SignatureTransferDetails({to: address(this), requestedAmount: payment.amountIn}),
      msg.sender,
      permitTransferFromAndSignature.signature
    );
  }

  function _staging(IUnusPayRouterV2.Payment calldata payment) internal {
    
  }

  /// @dev Processes the payment.
  /// @param payment The payment data.
  function _performPayment(IUnusPayRouterV2.Payment calldata payment) internal {
    // Perform conversion if required
    if (payment.exchangeAddress != address(0)) {
      _convert(payment);
    }
    if (payment.staging) {
      // Perform staging if required
      _staging(payment);
      return;
    }
    // Perform payment to paymentReceiver
    _payReceiver(payment);

    // Perform payment to feeReceiver
    if (payment.feeReceiverAddress != address(0)) {
      _payFee(payment);
    }
  }

  /// @dev Validates the post-conditions for a payment.
  /// @param payment The payment data.
  /// @param balanceInBefore The balance in before the payment.
  /// @param balanceOutBefore The balance out before the payment.
  function _validatePostConditions(
    IUnusPayRouterV2.Payment calldata payment,
    uint256[] balanceInBefore,
    uint256[] balanceOutBefore
  ) internal view {
    // Ensure balances of tokenIn remained
    for (uint i = 0; i < payment.fromTokens.length; i++) {
      if (payment.fromTokens[i].tokenAddress == NATIVE) {
        if (address(this).balance < balanceInBefore[i]) {
          revert InsufficientBalanceInAfterPayment();
        }
      } else {
        if (IERC20(payment.fromTokens[i].tokenAddress).balanceOf(address(this)) < balanceInBefore[i]) {
          revert InsufficientBalanceInAfterPayment();
        }
      }
    }
    for (uint i = 0; i < payment.fromTokens.length; i++) {
      // Ensure balances of tokenOut remained
      if (payment.toTokens[i].tokenAddress == NATIVE) {
        if (address(this).balance < balanceOutBefore) {
          revert InsufficientBalanceOutAfterPayment();
        }
      } else {
        if (IERC20(payment.toTokens[i].tokenAddress).balanceOf(address(this)) < balanceOutBefore) {
          revert InsufficientBalanceOutAfterPayment();
        }
      }
    }
  }

  /// @dev Handles token conversions.
  /// @param payment The payment data.
  function _convert(IUnusPayRouterV2.Payment calldata payment) internal {
    if (!exchanges[payment.exchangeAddress]) {
      revert ExchangeNotApproved();
    }
    for (uint i = 0; i < payment.fromTokens.length; i++) {
      bool success;
      if (payment.fromTokens[i].tokenAddress == NATIVE) {
        if (payment.fromTokens[i].exchangeCallData.length == 0) {
          revert ExchangeCallMissing();
        }
        (success, ) = payment.exchangeAddress.call{value: msg.value}(payment.fromTokens[i].exchangeCallData);
      } else {
        if (payment.exchangeType == 1) {
          // pull
          IERC20(payment.fromTokens[i].tokenAddress).safeApprove(payment.exchangeAddress, payment.fromTokens[i].amount);
        } else if (payment.exchangeType == 2) {
          // push
          IERC20(payment.fromTokens[i].tokenAddress).safeTransfer(
            payment.exchangeAddress,
            payment.fromTokens[i].amount
          );
        }
        (success, ) = payment.exchangeAddress.call(payment.exchangeCallData);
        if (payment.exchangeType == 1) {
          // pull
          IERC20(payment.fromTokens[i].tokenAddress).safeApprove(payment.exchangeAddress, 0);
        }
      }
      if (!success) {
        revert ExchangeCallFailed();
      }
    }
  }

  /// @dev Processes payment to receiver.
  /// @param payment The payment data.
  function _payReceiver(IUnusPayRouterV2.Payment calldata payment) internal {
    if (payment.receiverType != 0) {
      // call receiver contract

      {
        for (uint i = 0; i < payment.toTokens.length; i++) {
          bool success;
          if (payment.toTokens[i].tokenAddress == NATIVE) {
            success = IUnusPayForwarderV2(FORWARDER).forward{value: payment.toTokens[i].amount}(payment);
            emit InternalTransfer(msg.sender, payment.paymentReceiverAddress, payment.toTokens[i].amount);
          } else {
            IERC20(payment.toTokens[i].tokenAddress).safeTransfer(FORWARDER, payment.toTokens[i].amount);
            success = IUnusPayForwarderV2(FORWARDER).forward(payment);
          }
          if (!success) {
            revert ForwardingPaymentFailed();
          }
        }
      }
    } else {
      // just send payment to address
      for (uint i = 0; i < payment.toTokens.length; i++) {
        if (payment.toTokens[i].tokenAddress == NATIVE) {
          if (payment.paymentReceiverAddress == address(0)) {
            revert PaymentToZeroAddressNotAllowed();
          }
          (bool success, ) = payment.paymentReceiverAddress.call{value: payment.toTokens[i].amount}(new bytes(0));
          if (!success) {
            revert NativePaymentFailed();
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
  }

  /// @dev Processes fee payments.
  /// @param payment The payment data.
  function _payFee(IUnusPayRouterV2.Payment calldata payment) internal {
    for (uint i = 0; i < payment.toTokens.length; i++) {
      if (payment.toTokens[i].tokenAddress == NATIVE) {
        (bool success, ) = payment.feeReceiverAddress.call{value: payment.toTokens[i].feeAmount}(new bytes(0));
        if (!success) {
          revert NativeFeePaymentFailed();
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
      (bool success, ) = address(msg.sender).call{value: amount}(new bytes(0));
      require(success, 'UnusPay: withdraw failed!');
    } else {
      IERC20(token).safeTransfer(msg.sender, amount);
    }
    return true;
  }
}
