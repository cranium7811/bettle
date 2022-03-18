// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {IAggregatorV3} from "./interfaces/IAggregatorV3.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract Bettle {
    
    IAggregatorV3 internal aggregatorInterface;

    uint public betId;
    address public constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public owner;
    mapping(address => address) public assetOracles;

    // mapping(address => mapping(address => mapping(uint => int))) public speculation;
    BetDetails[] public betDetails;

    struct BetDetails {
        address betCreator;
        address speculativeAsset;
        int speculatedAssetPrice;
        uint expirationTime;
        uint betAmount;
        address betMatcher;
        uint8 betType; // 1 - matcher is speculating that the asset will increase, 2- vice versa
        uint betTotalAmount;
    }

    event BetCreated(
        address indexed from, 
        address indexed speculativeAsset, 
        int speculatedAssetPrice, 
        uint expirationTime, 
        uint betAmount
    );

    event BetMatched(address indexed by, uint id);

    constructor() {
        owner = msg.sender;
    }

    function _getLatestPrice(address assetAddress) internal returns(int) {
        address assetOracleAddress = assetOracles[assetAddress];

        require(assetOracleAddress != address(0), "UPDATE_ORACLE_ADDRESS");

        aggregatorInterface = IAggregatorV3(assetOracleAddress);
        ( ,int price , , , ) = aggregatorInterface.latestRoundData();

        return price;
    }

    function updateAssetOracle(address assetAddress, address assetOracleAddress) public {
        require(msg.sender == owner, "NOT_OWNER");
        assetOracles[assetAddress] = assetOracleAddress;
    } 

    function createBet(
        address speculativeAsset,
        int speculatedAssetPrice,
        uint expirationTime,
        uint betAmount
    ) public {

        require(betAmount <= ERC20(usdc).balanceOf(msg.sender), "INSUFFICIENT_AMOUNT");
        require(expirationTime > block.timestamp + 10 days, "MINIMUM_10_DAYS");


        betDetails[betId].betCreator = msg.sender;
        betDetails[betId].speculativeAsset = speculativeAsset;
        betDetails[betId].speculatedAssetPrice = speculatedAssetPrice;
        betDetails[betId].expirationTime = expirationTime;
        betDetails[betId].betAmount = betAmount;
        betDetails[betId].betTotalAmount += betAmount;

        ++betId;
        
        ERC20(usdc).transferFrom(msg.sender, address(this), betAmount);

        emit BetCreated(
            msg.sender, 
            speculativeAsset, 
            speculatedAssetPrice, 
            expirationTime, 
            betAmount
        );
    }

    function matchBet(uint _betId, uint betMatchAmount, uint8 _betType) public {
        require(betDetails[_betId].betMatcher == address(0), "BET_ALREADY_EXISTS");
        require(betMatchAmount <= ERC20(usdc).balanceOf(msg.sender), "INSUFFICIENT_AMOUNT");
        require(betMatchAmount >= betDetails[_betId].betAmount, "BET_NOT_MATCHED");
        require(_betType == 1 || _betType == 2);

        betDetails[_betId].betMatcher = msg.sender;
        betDetails[_betId].betType = _betType;
        betDetails[_betId].betTotalAmount += betMatchAmount;

        ERC20(usdc).transferFrom(msg.sender, address(this), betMatchAmount);

        emit BetMatched(msg.sender, _betId);
    }

    function claimWinner(uint _betId) public {
        address betMatcher = betDetails[_betId].betMatcher;
        address betCreator = betDetails[_betId].betCreator;

        require(
            msg.sender == betCreator || 
            msg.sender == betMatcher, 
            "NOT_ELIGIBLE"
        );

        require(block.timestamp > betDetails[_betId].expirationTime, "STILL_TIME_TO_GO");

        int price = _getLatestPrice(betDetails[_betId].speculativeAsset);
        int assetPrice = betDetails[_betId].speculatedAssetPrice;
        uint totalBet = betDetails[_betId].betTotalAmount;
        uint8 betType = betDetails[_betId].betType;

        if(betType == 1 && price > assetPrice) {
            ERC20(usdc).transferFrom(address(this), betMatcher, totalBet);
            delete betDetails[_betId];
        } else if(betType == 2 && price < assetPrice) {
            ERC20(usdc).transferFrom(address(this), betCreator, totalBet);
            delete betDetails[_betId];
        } else revert();
    }

}
