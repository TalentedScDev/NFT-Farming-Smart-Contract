// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/UniswapV3NFTPrice.sol";

contract TeraStaking is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    
    UniswapV3NFTPrice private uniswapV3NFTPrice;

    IERC20 public StakingToken;
    IERC20 public RewardToken;

    // Reward rate per second per NFT staked
    uint256 public rewardRate;
    uint256 public rewardDuration = 1 hours;

    struct Staker {
        uint256 userStakedTokens;       // all tokens staked per user
        uint256 lastRewardTimestamp;    // the datetime last rewarded
        uint256 totalRewardEarned;      // all amount rewarded
    }

    mapping (address => Staker) public users;
    mapping (address => uint256[]) public stakedTimestamps;

    uint256 totalSupplyAmount = 0;

    // Events
    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event Unstaked(address indexed user, uint256 amount, uint256 timestamp);
    event RewardsClaimed(address indexed user, uint256 amount, uint256 timestamp);

    constructor(
        address initialOwner,
        IERC20 _stakingToken,
        IERC20 _RewardToken,
        uint256 _rewardRate
    ) Ownable(initialOwner) {
        StakingToken = _stakingToken;
        RewardToken = _RewardToken;
        rewardRate = _rewardRate;
        uniswapV3NFTPrice = new UniswapV3NFTPrice(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    }

    function setReceiveToken(IERC20 _stakingToken) external onlyOwner {
        StakingToken = _stakingToken;
    }

    function setRewardToken(IERC20 _rewardToken) external onlyOwner {
        RewardToken = _rewardToken;
    }

    function setRewardRate(uint256 _newRewardRate, uint256 _newRewardDuration) external onlyOwner {
        rewardRate = _newRewardRate;
        rewardDuration = _newRewardDuration;
    }

    function setPriceFeed(address token, address feed) external onlyOwner {
        uniswapV3NFTPrice.setPriceFeed(token, feed);
    }

    function stake(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than zero");
        require(StakingToken.balanceOf(msg.sender) >= _amount, "Insufficient balance");
        
        StakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        Staker storage user = users[msg.sender];
        // If user has already staked before, calculate and distribute previous rewards 
        if (user.userStakedTokens > 0) {
            uint256 pendingReward = calculateRewards(msg.sender);
            if (pendingReward > 0) {
                claimReward();
            }
        }
        user.userStakedTokens += _amount;
        user.lastRewardTimestamp = block.timestamp;
        stakedTimestamps[msg.sender].push(block.timestamp);

        emit Staked(msg.sender, _amount, block.timestamp);
    }

    function unstake(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than zero");
        require(users[msg.sender].userStakedTokens >= _amount, "Insufficient staked tokens");
        
        uint256 ownedBalanceOf = StakingToken.balanceOf(address(this));
        require(ownedBalanceOf >= _amount, "Insufficient balance of this contract. Please contact the contract owner.");
        
        uint256 reward = calculateRewards(msg.sender);
        
        require(StakingToken.transfer(msg.sender, _amount), "Token transfer failed");
        
        if (reward > 0) {
            claimReward();
        }

        Staker storage user = users[msg.sender];
        user.userStakedTokens -= _amount;
        
        emit Unstaked(msg.sender, _amount, block.timestamp);
    }

    function calculateRewards(address _user) internal view returns (uint256) {
        Staker memory user = users[_user];
        uint256 stakedTime = block.timestamp - user.lastRewardTimestamp;
        uint256 tokenPrice = uniswapV3NFTPrice.getTokenPriceInUSD(address(StakingToken));
        uint256 reward = (user.userStakedTokens * tokenPrice * rewardRate * stakedTime) / rewardDuration;
        // return (user.userStakedTokens * rewardRate * stakedTime) / (1000 * 365 * 24 * 60 * 60); // Yearly rate?
        return reward;
    }

    function claimReward() public nonReentrant {
        uint256 reward = calculateRewards(msg.sender);
        require(reward > 0, "No rewards to claim");

        uint256 balancesof = RewardToken.balanceOf(address(this));
        require(balancesof >= reward, "Insufficient balance of this contract. Please contact the contract owner.");

        require(RewardToken.transfer(msg.sender, reward), "Reward transfer failed");
        totalSupplyAmount += reward;

        Staker storage user = users[msg.sender];
        user.totalRewardEarned += reward;
        if (user.userStakedTokens == 0) { // If user has unstaked, remove the user from the mapping
            user.lastRewardTimestamp = 0;
        } else {
            user.lastRewardTimestamp = block.timestamp;
        }

        emit RewardsClaimed(msg.sender, reward, block.timestamp);
    }

    function withdrawLeftoverRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        require(RewardToken.balanceOf(address(this)) >= amount, "Insufficient balance of this contract. Please contact the contract owner.");
        RewardToken.transfer(msg.sender, amount);
    }
    
    function getTotalRewardUser() external view returns (
        uint256 totalRewardEarned,
        uint256 pendingReward,
        uint256 userStakedTokens,
        uint256[] memory stakedTimestampsUser,
        uint256 rewardDurationValue,
        uint256 rewardRateValue
    ) {
        return (
            users[msg.sender].totalRewardEarned,
            calculateRewards(msg.sender),
            users[msg.sender].userStakedTokens,
            stakedTimestamps[msg.sender],
            rewardDuration,
            rewardRate
        );
    }

    function getTotalBalancesOf() external view returns (
        uint256 receiveTokenBalance,
        uint256 totalSupplyAmounts,
        uint256 totalUsers
    ) {
        return (
            StakingToken.balanceOf(address(this)),
            totalSupplyAmount,
            10
        );
    }
}