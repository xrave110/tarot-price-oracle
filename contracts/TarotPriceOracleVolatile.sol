pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./libraries/UQ112x112.sol";
import "./interfaces/IVeloPair.sol";
import "./interfaces/ITarotPriceOracle.sol";

contract TarotPriceOracleVolatile is ITarotPriceOracle {
    using UQ112x112 for uint224;

    uint32 public constant MIN_T = 1200;

    struct Pair {
        uint256 priceCumulativeSlotA;
        uint256 priceCumulativeSlotB;
        uint32 lastUpdateSlotA;
        uint32 lastUpdateSlotB;
        bool latestIsSlotA;
        bool initialized;
    }
    mapping(address => Pair) public getPair;

    function toUint224(uint256 input) internal pure returns (uint224) {
        require(
            input <= type(uint224).max,
            "TarotPriceOracle: UINT224_OVERFLOW"
        );
        return uint224(input);
    }

    function initialize(address veloPair) external {
        Pair storage pairStorage = getPair[veloPair];
        require(
            !pairStorage.initialized,
            "TarotPriceOracle: ALREADY_INITIALIZED"
        );
        uint256[] memory tmp = IVeloPair(veloPair).prices(
            IVeloPair(veloPair).token0(),
            1,
            2
        );
        uint256 priceCumulativeCurrent = tmp[0];
        uint32 blockTimestamp = getBlockTimestamp();
        pairStorage.priceCumulativeSlotA = priceCumulativeCurrent;
        pairStorage.priceCumulativeSlotB = priceCumulativeCurrent;
        pairStorage.lastUpdateSlotA = blockTimestamp;
        pairStorage.lastUpdateSlotB = blockTimestamp;
        pairStorage.latestIsSlotA = true;
        pairStorage.initialized = true;
        emit PriceUpdate(
            veloPair,
            priceCumulativeCurrent,
            blockTimestamp,
            true
        );
    }

    function getResult(
        address veloPair
    ) external returns (uint224 price, uint32 T) {
        Pair memory pair = getPair[veloPair];
        require(pair.initialized, "TarotPriceOracle: NOT_INITIALIZED");
        Pair storage pairStorage = getPair[veloPair];

        uint32 blockTimestamp = getBlockTimestamp();
        uint32 lastUpdateTimestamp = pair.latestIsSlotA
            ? pair.lastUpdateSlotA
            : pair.lastUpdateSlotB;

        uint256[] memory tmp = IVeloPair(veloPair).prices(
            IVeloPair(veloPair).token0(),
            1e18,
            1
        );
        uint256 priceCumulativeCurrent = tmp[0];
        uint256 priceCumulativeLast;

        if (blockTimestamp - lastUpdateTimestamp >= MIN_T) {
            // update price
            priceCumulativeLast = pair.latestIsSlotA
                ? pair.priceCumulativeSlotA
                : pair.priceCumulativeSlotB;
            if (pair.latestIsSlotA) {
                pairStorage.priceCumulativeSlotB = priceCumulativeCurrent;
                pairStorage.lastUpdateSlotB = blockTimestamp;
            } else {
                pairStorage.priceCumulativeSlotA = priceCumulativeCurrent;
                pairStorage.lastUpdateSlotA = blockTimestamp;
            }
            pairStorage.latestIsSlotA = !pair.latestIsSlotA;
            emit PriceUpdate(
                veloPair,
                priceCumulativeCurrent,
                blockTimestamp,
                !pair.latestIsSlotA
            );
        } else {
            // don't update; return price using previous priceCumulative
            lastUpdateTimestamp = pair.latestIsSlotA
                ? pair.lastUpdateSlotB
                : pair.lastUpdateSlotA;
            priceCumulativeLast = pair.latestIsSlotA
                ? pair.priceCumulativeSlotB
                : pair.priceCumulativeSlotA;
        }
        console2.log("Current price:", priceCumulativeCurrent);
        console2.log("Last price:", priceCumulativeLast);
        T = blockTimestamp - lastUpdateTimestamp; // overflow is desired
        console2.log("Delta time:", T);
        require(T >= MIN_T, "TarotPriceOracle: NOT_READY"); //reverts only if the pair has just been initialized
        // / is safe, and - overflow is desired
        price = toUint224((priceCumulativeCurrent - priceCumulativeLast) / T);
    }

    /*** Utilities ***/

    function getBlockTimestamp() public view returns (uint32) {
        return uint32(block.timestamp % 2 ** 32);
    }
}
