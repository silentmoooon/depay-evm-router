// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import './IPermit2.sol';

interface IUnusPayRouterV2 {
 struct FromToken{
    address tokenAddress;
    uint256 amount;
    bytes exchangeCallData;
    address swapTokenAddress;
    uint256 swapAmount;
 }
 struct ToToken{
    address tokenAddress;
    uint256 amount;
    uint256 feeAmount;
 }
  struct Payment {
    bool permit2;
    FromToken[] fromTokens;
    address exchangeAddress;
    ToToken[] toTokens;
    address paymentReceiverAddress;
    address feeReceiverAddress;
    uint8 exchangeType;
    uint8 receiverType;
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
