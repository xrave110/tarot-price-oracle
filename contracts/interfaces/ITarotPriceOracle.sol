pragma solidity ^0.8.0;

interface ITarotPriceOracle {
    event PriceUpdate(
        address indexed pair,
        uint256 priceCumulative,
        uint32 blockTimestamp,
        bool latestIsSlotA
    );

    function MIN_T() external pure returns (uint32);

    function getPair(
        address veloPair
    )
        external
        view
        returns (
            uint256 priceCumulativeSlotA,
            uint256 priceCumulativeSlotB,
            uint32 lastUpdateSlotA,
            uint32 lastUpdateSlotB,
            bool latestIsSlotA,
            bool initialized
        );

    function initialize(address veloPair) external;

    function getResult(
        address veloPair
    ) external returns (uint224 price, uint32 T);

    function getBlockTimestamp() external view returns (uint32);
}
