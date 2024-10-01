// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/UniswapV3NFTPrice.sol";

contract TeraFarming is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    UniswapV3NFTPrice public NTokenPrice;

    IERC721 public nftContract;
    IERC20 public rewardToken;

    uint256 public rewardRate;
    uint256 public rewardDuration = 1 minutes;

    uint256[] public totalStakedTokenList;
    mapping(address => uint256) public totalStakedToken;
    mapping(address => uint256) public totalRewardEarned;
    mapping(address => mapping(uint256 => uint256)) public lastRewardTimestamp;
    mapping(address => mapping(uint256 => uint256)) public stakedTimestamp;
    mapping(address => mapping(uint256 => uint256)) public nftRewardClaimed;
    mapping(address => mapping(uint256 => bool)) public isValidNFTOwnerOf;
    mapping(address => uint256[]) public stakedNFTs;

    event Staked(address indexed user, uint256 indexed nftId, uint256 timestamp);
    event Unstaked(address indexed user, uint256 indexed nftId, uint256 timestamp);
    event RewardsClaimed(address indexed user, uint256 indexed nftId, uint256 rewardAmount);
    event AllRewardsClaimed(address indexed user, uint256 count, uint256 timestamp);

    constructor(
        address initialOwner, 
        IERC721 _nftContract, 
        IERC20 _rewardToken, 
        uint256 _rewardRate
    ) Ownable(initialOwner) {
        nftContract = _nftContract;
        rewardToken = _rewardToken;
        rewardRate = _rewardRate;
        NTokenPrice =  new UniswapV3NFTPrice(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    }

    modifier onlyOwnerOf(address _user, uint256 _nftId) {
        require(nftContract.ownerOf(_nftId) == _user, "Not the NFT owner");
        require(isValidNFTOwnerOf[_user][_nftId], "NFT not staked");
        _;
    }

    modifier isValidTokens() {
        require(nftContract.supportsInterface(type(IERC721).interfaceId), "Not a valid ERC721 contract");
        require(rewardToken.totalSupply() > 0, "Not a valid ERC20 token");
        _;
    }

    function setStakeToken(IERC721 _nftContract) external onlyOwner {
        nftContract = _nftContract;
    }

    function setRewardToken(IERC20 _rewardToken) external onlyOwner {
        rewardToken = _rewardToken;
    }

    function setRewardFactors(uint256 _newRate, uint256 _newDuration) external onlyOwner {
        rewardRate = _newRate;
        rewardDuration = _newDuration;
    }

    function setPriceFeed(address token, address feed) external onlyOwner {
        NTokenPrice.setPriceFeed(token, feed);
    }

    function stake(uint256 _nftId) external nonReentrant {
        require(nftContract.ownerOf(_nftId) == msg.sender, "Not the NFT owner");
        require(!isValidNFTOwnerOf[msg.sender][_nftId], "NFT already staked");

        nftContract.safeTransferFrom(msg.sender, address(this), _nftId);
        totalStakedToken[msg.sender] += 1;
        lastRewardTimestamp[msg.sender][_nftId] = block.timestamp;
        isValidNFTOwnerOf[msg.sender][_nftId] = true;
        stakedNFTs[msg.sender].push(_nftId);
        totalStakedTokenList.push(_nftId);

        stakedTimestamp[msg.sender][_nftId] = block.timestamp;
        emit Staked(msg.sender, _nftId, block.timestamp);
    }

    function calculateRewards(address _user, uint256 _nftId) public view returns (uint256) {
        uint256 stakedTime = block.timestamp - lastRewardTimestamp[_user][_nftId];
        uint256 price = NTokenPrice.getLPTokenValue(_nftId);
        return (stakedTime * rewardRate * price) / rewardDuration;
    }

    function claimRewards(uint256 _nftId) public nonReentrant onlyOwnerOf(msg.sender, _nftId) {
        uint256 rewardsToClaim = calculateRewards(msg.sender, _nftId);
        require(rewardsToClaim > 0, "No rewards to claim");

        rewardToken.safeTransfer(msg.sender, rewardsToClaim);

        totalRewardEarned[msg.sender] += rewardsToClaim;
        nftRewardClaimed[msg.sender][_nftId] += rewardsToClaim;
        lastRewardTimestamp[msg.sender][_nftId] = block.timestamp;

        emit RewardsClaimed(msg.sender, _nftId, rewardsToClaim);
    }

    function claimAllRewards() external nonReentrant {
        require(totalStakedToken[msg.sender] > 0, "No staked NFTs");
        uint256 nftCount = stakedNFTs[msg.sender].length;

        for (uint256 i = 0; i < nftCount; i++) {
            uint256 nftId = stakedNFTs[msg.sender][i];
            claimRewards(nftId);
        }

        emit AllRewardsClaimed(msg.sender, nftCount, block.timestamp);
    }

    function unstake(uint256 _nftId) external nonReentrant onlyOwnerOf(msg.sender, _nftId) {
        claimRewards(_nftId);
        nftContract.safeTransferFrom(address(this), msg.sender, _nftId);

        totalStakedToken[msg.sender] -= 1;
        _removeFromArray(stakedNFTs[msg.sender], _nftId);
        _removeFromArray(totalStakedTokenList, _nftId);
        delete isValidNFTOwnerOf[msg.sender][_nftId];

        emit Unstaked(msg.sender, _nftId, block.timestamp);
    }

    function _removeFromArray(uint256[] storage array, uint256 _nftId) internal {
        uint256 length = array.length;
        for (uint256 i = 0; i < length; i++) {
            if (array[i] == _nftId) {
                array[i] = array[length - 1];
                array.pop();
                break;
            }
        }
    }

    function stakedTokens()
        external
        view
        returns (
            uint256 totalStakedTokens,
            uint256 totalReward,
            uint256[] memory stakedTimestamps,
            uint256[] memory nftRewardsClaimed,
            uint256[] memory stakedTokenList
        )
    {
        uint256 length = stakedNFTs[msg.sender].length;
        stakedTimestamps = new uint256[](length);
        nftRewardsClaimed = new uint256[](length);
        stakedTokenList = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 nftId = stakedNFTs[msg.sender][i];
            stakedTimestamps[i] = stakedTimestamp[msg.sender][nftId];
            nftRewardsClaimed[i] = nftRewardClaimed[msg.sender][nftId];
            stakedTokenList[i] = nftId;
        }

        return (
            totalStakedToken[msg.sender],
            totalRewardEarned[msg.sender],
            stakedTimestamps,
            nftRewardsClaimed,
            stakedTokenList
        );
    }

    function getTotalAssets()
        external
        view
        onlyOwner
        returns (
            uint256 totalLockedAmount,
            uint256[] memory totalStakedTokenLists
        )
    {
        totalLockedAmount = totalStakedTokenList.length;
        
        // Use unchecked to avoid overflow checks
        // unchecked {
        //     for (uint256 index = 0; index < length; index++) {
        //         totalLockedAmount += nftContract.balanceOf(totalStakedTokenList[index]);
        //     }
        // }

        return (totalLockedAmount, totalStakedTokenList);
    }
}
