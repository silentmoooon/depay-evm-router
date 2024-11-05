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
    uint256 feeAmount;
 }
  struct Payment {
    bool permit2;
    //是否暂存,暂存的不实时转给收款人
    bool staging;
    FromToken[] FromTokens;
    address exchangeAddress;
    ToToken[] ToTokens;
    address paymentReceiverAddress;
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
