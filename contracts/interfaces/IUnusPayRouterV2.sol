// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import './IPermit2.sol';

interface IUnusPayRouterV2 {
struct FromToken{
    address tokenAddress;
    uint256 amount;
    address swapTokenAddress;
    uint256 swapAmount;

}
struct ToToken{
    address tokenAddress;
    uint256 amount;
}

  struct Payment {
    uint256[] amountIn;
    bool permit2;
    bool staging;
    uint256 paymentAmount;
    uint256 feeAmount;
    FromToken[] FromTokens;
    address exchangeAddress;
    ToToken[] toTokens;
    address feeReceiverAddress;
    uint8 exchangeType;
    uint8 receiverType;
    bytes exchangeCallData;
    bytes receiverCallData;
    uint256 deadline;
  }

  struct PermitTransferFromAndSignature {
    IPermit2.PermitTransferFrom permitTransferFrom;
    bytes signature;
  }

  function pay(
    Payment calldata payment
  ) external payable returns(bool);

  function pay(
    IUnusPayRouterV2.Payment calldata payment,
    PermitTransferFromAndSignature calldata permitTransferFromAndSignature
  ) external payable returns(bool);

  function pay(
    IUnusPayRouterV2.Payment calldata payment,
    IPermit2.PermitSingle calldata permitSingle,
    bytes calldata signature
  ) external payable returns(bool);

  event Enabled(
    address indexed exchange
  );

  event Disabled(
    address indexed exchange
  );

  function enable(address exchange, bool enabled) external returns(bool);

  function withdraw(address token, uint amount) external returns(bool);

}
