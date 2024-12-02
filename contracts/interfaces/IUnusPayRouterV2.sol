// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import './IPermit2.sol';

interface IUnusPayRouterV2 {
    struct FromToken {
        address tokenAddress;
        uint256 amount;
        address swapTokenAddress;
        uint256 swapAmount;
        address exchangeAddress;
        bytes exchangeCallData;
        uint8 exchangeType;
    }

    struct SubToken {
        address tokenAddress;
        uint256 approveAmount;
    }

    struct ToToken {
        address tokenAddress;
        uint256 amount;
        uint256 feeAmount;
    }

    struct Payment {
        FromToken[] fromTokens;
        ToToken[] toTokens;
        address paymentReceiverAddress;
        address feeReceiverAddress;
        uint256 deadline;
    }

    struct SubAndPayment {
        address[] tokens;
        //第一个token支付的金额
        uint256 amount;
        address paymentReceiverAddress;
        address feeReceiverAddress;
        uint256 deadline;
    }


    function pay(
        Payment calldata payment
    ) external payable returns (bool);
    //订阅并支付
    function subAndPay(
        SubAndPayment calldata payment
    ) external payable returns (bool);

    //订阅后支付
    function subPay(
        SubAndPayment calldata payment
    ) external payable returns (bool);

    event Enabled(
        address indexed exchange
    );

    event Disabled(
        address indexed exchange
    );

    function enable(address exchange, bool enabled) external returns (bool);

    function withdraw(address token, uint amount) external returns (bool);

}
