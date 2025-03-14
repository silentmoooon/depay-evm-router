

pragma solidity 0.8.18;

import './IUnusPayRouter.sol';

interface IUnusPaySubscription {


    struct SubToken {
        address tokenAddress;
        uint256 approveAmount;
    }

    struct ToToken {
        address tokenAddress;
        uint256 amount;
        uint256 feeAmount;
    }

    struct SubPayment {
        //用户订阅时不填,商户自动扣款时填
        address fromAddress;
        //订阅订单号
        string orderNo;
        //周期类型  2:小时 3:天 4:周 5:月 6:年
        uint32 plan;
        //订阅期数,0为永久
        uint32 instalments;
        IUnusPayRouter.FromToken fromToken;
        uint256 payAmount;
        uint256 feeAmount;
        address paymentReceiverAddress;
        address feeReceiverAddress;
        uint256 deadline;
    }

    struct SubscriptionInfo {
        //周期类型  2:小时 3:天 4:周 5:月 6:年
        uint32 plan;
        //订阅期数,0为永久
        uint32 instalments;
        //剩余订阅期数
        uint32 remaining;
        //上次支付时间
        uint256 lastPayTime;

    }

    //订阅并支付
    function subAndPay(
        SubPayment calldata payment
    ) external payable returns (bool);

    //订阅后支付
    function subPay(
        SubPayment calldata payment
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
