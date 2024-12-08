// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import './IPermit2.sol';

interface IUnusPayRouter {
    struct FromToken {
        address tokenAddress;
        uint256 amount;
        address swapTokenAddress;
        uint256 swapAmount;
        address exchangeAddress;
        bytes exchangeCallData;
        uint8 exchangeType;
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




    function pay(
        Payment calldata payment
    ) external payable returns (bool);

    function convert(IUnusPayRouter.FromToken[] calldata payment) external payable returns (bool);

    event Enabled(
        address indexed exchange
    );

    event Disabled(
        address indexed exchange
    );

    function enable(address exchange, bool enabled) external returns (bool);

    function withdraw(address token, uint amount) external returns (bool);

}
