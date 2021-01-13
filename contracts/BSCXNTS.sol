// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import './interfaces/IERC20.sol';
import './libraries/SafeERC20.sol';
import './libraries/SafeMath.sol';
import './Ownable.sol';

contract BSCXNTS is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;            // How many LP tokens the user has provided.
        uint256 rewardDebt;        // Reward debt. See explanation below.
        uint256 rewardDebtAtBlock; // the last block user stake
        uint256 lockAmount;        // Lock amount reward token
        uint256 lastUnlockBlock;
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;            // Address of LP token contract.
        IERC20 rewardToken;        // Address of reward token contract.
        uint256 allocPoint;        // How many allocation points assigned to this pool. reward to distribute per block.
        uint256 lastRewardBlock;   // Last block number that Reward distribution occurs.
        uint256 accRewardPerShare; // Accumulated Reward per share, times 1e12. See below.
        uint256 rewardPerBlock;    // Reward per block.
        uint256 percentLockReward; // Percent lock reward.
        uint256 percentForDev;     // Percent for dev team.
        uint256 percentForBurn;    // Percent burn reward token.
        uint256 finishBonusAtBlock;
        uint256 startBlock;        // Start at block.
        uint256 totalLock;         // Total lock reward token on pool.
        uint256 lockFromBlock;     // Lock from block.
        uint256 lockToBlock;       // Lock to block.
    }

    // Dev address.
    address public devaddr;
    bool public status;             // Status handle farmer can harvest.
    uint256 public poolIdForStake;  // Pool ID for get BSCX stake check conditions referrer.

    uint256 public stakeLPLv1;    // Minimum stake LP token condition level1 for referral program.
    uint256 public stakeLPLv2;    // Minimum stake LP token condition level2 for referral program.

    uint256 public percentForReferLv1; // Percent reward level1 referral program.
    uint256 public percentForReferLv2; // Percent reward level2 referral program.

    // Info of each pool.
    PoolInfo[] public poolInfo;
    mapping(address => address) public referrers;
    mapping(address => uint256) public poolId1; // poolId1 count from 1, subtraction 1 before using with poolInfo
    // Info of each user that stakes LP tokens. pid => user address => info
    mapping(uint256 => mapping (address => UserInfo)) public userInfo;

    mapping(uint256 => uint256[]) public rewardMultipliers;
    mapping(uint256 => uint256[]) public halvingAtBlocks;
    mapping(uint256 => address) public teamAddresses; // Set address receive reward for project team IDO

    // Total allocation poitns. Must be the sum of all allocation points in all pools same reward token.
    mapping(IERC20 => uint256) public totalAllocPoints;
    // Total locks. Must be the sum of all token locks in all pools same reward token.
    mapping(IERC20 => uint256) public totalLocks;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event SendReward(address indexed user, uint256 indexed pid, uint256 amount, uint256 lockAmount);
    event Lock(address indexed to, uint256 value);

    constructor(
        address _devaddr,
        uint256 _stakeLPLv1,
        uint256 _stakeLPLv2,
        uint256 _percentForReferLv1,
        uint256 _percentForReferLv2
    ) public {
        devaddr = _devaddr;
        stakeLPLv1 = _stakeLPLv1;
        stakeLPLv2 = _stakeLPLv2;
        percentForReferLv1 = _percentForReferLv1;
        percentForReferLv2 = _percentForReferLv2;

        status = true;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(
        IERC20 _lpToken,
        IERC20 _rewardToken,
        uint256 _startBlock,
        uint256 _allocPoint,
        uint256 _rewardPerBlock,
        uint256 _percentLockReward,
        uint256 _percentForDev,
        uint256 _percentForBurn,
        uint256 _halvingAfterBlock,
        uint256[] memory _rewardMultiplier,
        uint256 _lockFromBlock,
        uint256 _lockToBlock
    ) public onlyOwner {
        require(poolId1[address(_lpToken)] == 0, "BSCXNTS::add: lp is already in pool");
        poolId1[address(_lpToken)] = poolInfo.length + 1;
        _setAllocPoints(_rewardToken, _allocPoint);
        uint256 finishBonusAtBlock = _setHalvingAtBlocks(poolInfo.length, _rewardMultiplier, _halvingAfterBlock, _startBlock);

        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            rewardToken: _rewardToken,
            lastRewardBlock: block.number > _startBlock ? block.number : _startBlock,
            allocPoint: _allocPoint,
            accRewardPerShare: 0,
            startBlock: _startBlock,
            rewardPerBlock: _rewardPerBlock,
            percentLockReward: _percentLockReward,
            percentForDev: _percentForDev,
            percentForBurn: _percentForBurn,
            finishBonusAtBlock: finishBonusAtBlock,
            totalLock: 0,
            lockFromBlock: _lockFromBlock,
            lockToBlock: _lockToBlock
        }));
    }

    function setStatus(bool _status) public onlyOwner {
        status = _status;
    }

    // Import for get reward referral program
    function setPoolIdForStake(uint256 _poolIdForStake) public onlyOwner {
        poolIdForStake = _poolIdForStake;
    }

    // Set team address receive reward
    function setTeamAddressPool(uint256 _pid, address _teamAddress) public onlyOwner {
        teamAddresses[_pid] = _teamAddress;
    }

    function _setAllocPoints(IERC20 _rewardToken, uint256 _allocPoint) internal onlyOwner {
        totalAllocPoints[_rewardToken] = totalAllocPoints[_rewardToken].add(_allocPoint);
    }

    function _setHalvingAtBlocks(uint256 _pid, uint256[] memory _rewardMultiplier, uint256 _halvingAfterBlock, uint256 _startBlock) internal onlyOwner returns(uint256) {
        rewardMultipliers[_pid] = _rewardMultiplier;
        for (uint256 i = 0; i < _rewardMultiplier.length - 1; i++) {
            uint256 halvingAtBlock = _halvingAfterBlock.mul(i + 1).add(_startBlock);
            halvingAtBlocks[_pid].push(halvingAtBlock);
        }
        uint256 finishBonusAtBlock = _halvingAfterBlock.mul(_rewardMultiplier.length - 1).add(_startBlock);
        halvingAtBlocks[_pid].push(uint256(-1));
        return finishBonusAtBlock;
    }

    function setReferStakeBSCX(uint256 _stakeLPLv1, uint256 _stakeLPLv2) public onlyOwner {
        stakeLPLv1 = _stakeLPLv1;
        stakeLPLv2 = _stakeLPLv2;
    }

    function setPercentRefer(uint256 _percentForReferLv1, uint256 _percentForReferLv2) public onlyOwner {
        percentForReferLv1 = _percentForReferLv1;
        percentForReferLv2 = _percentForReferLv2;
    }

    // Update the given pool's BSCX allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        PoolInfo storage pool = poolInfo[_pid];

        totalAllocPoints[pool.rewardToken] = totalAllocPoints[pool.rewardToken].sub(pool.allocPoint).add(_allocPoint);
        pool.allocPoint = _allocPoint;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 forBurn;
        uint256 forDev;
        uint256 forFarmer;
        (forBurn, forDev, forFarmer) = getPoolReward(_pid);

        if (forBurn > 0) {
            pool.rewardToken.burn(forBurn);
        }

        if (forDev > 0) {
            if (teamAddresses[_pid] != address(0)) {
                pool.rewardToken.transfer(teamAddresses[_pid], forDev.mul(100 - pool.percentLockReward).div(100));
                farmLock(teamAddresses[_pid], forDev.mul(pool.percentLockReward).div(100), _pid);
            } else {
                pool.rewardToken.transfer(devaddr, forDev.mul(100 - pool.percentLockReward).div(100));
                farmLock(devaddr, forDev.mul(pool.percentLockReward).div(100), _pid);
            }
        }
        pool.accRewardPerShare = pool.accRewardPerShare.add(forFarmer.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(
        uint256 _from,
        uint256 _to,
        uint256[] memory _halvingAtBlock,
        uint256[] memory _rewardMultiplier,
        uint256 _startBlock
    ) public pure returns (uint256) {
        uint256 result = 0;
        if (_from < _startBlock) return 0;

        for (uint256 i = 0; i < _halvingAtBlock.length; i++) {
            uint256 endBlock = _halvingAtBlock[i];

            if (_to <= endBlock) {
                uint256 m = _to.sub(_from).mul(_rewardMultiplier[i]);
                return result.add(m);
            }

            if (_from < endBlock) {
                uint256 m = endBlock.sub(_from).mul(_rewardMultiplier[i]);
                _from = endBlock;
                result = result.add(m);
            }
        }

        return result;
    }

    function getPoolReward(uint256 _pid) public view returns (uint256 forBurn, uint256 forDev, uint256 forFarmer) {
        PoolInfo memory pool = poolInfo[_pid];

        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number, halvingAtBlocks[_pid], rewardMultipliers[_pid], pool.startBlock);
        uint256 amount = multiplier.mul(pool.rewardPerBlock).mul(pool.allocPoint).div(totalAllocPoints[pool.rewardToken]);
        uint256 rewardCanAlloc = pool.rewardToken.balanceOf(address(this)).sub(totalLocks[pool.rewardToken]);

        if (rewardCanAlloc < amount) {
            forBurn = 0;
            forDev = 0;
            forFarmer = rewardCanAlloc;
        }
        else {
            forBurn = amount.mul(pool.percentForBurn).div(100);
            forDev = amount.sub(forBurn).mul(pool.percentForDev).div(100);
            forFarmer = amount.sub(forBurn).sub(forDev);
        }
    }

    // View function to see pending reward on frontend.
    function pendingReward(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply > 0) {
            uint256 forFarmer;
            (, , forFarmer) = getPoolReward(_pid);
            accRewardPerShare = accRewardPerShare.add(forFarmer.mul(1e12).div(lpSupply));

        }
        return user.amount.mul(accRewardPerShare).div(1e12).sub(user.rewardDebt);
    }

    function claimReward(uint256 _pid) public {
        require(status == true, "BSCXNTS::withdraw: can not claim reward");
        updatePool(_pid);
        _harvest(_pid);
    }

    function getLPTokenStaked(address _account) public view returns (uint256) {
        UserInfo memory user = userInfo[poolIdForStake][_account];
        return user.amount;
    }

    // lock 75% of reward if it come from bounus time
    function _harvest(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accRewardPerShare).div(1e12).sub(user.rewardDebt);
            uint256 masterBal = pool.rewardToken.balanceOf(address(this));

            if (pending > masterBal) {
                pending = masterBal;
            }

            if(pending > 0) {
                uint256 referAmountLv1 = pending.mul(percentForReferLv1).div(100);
                uint256 referAmountLv2 = pending.mul(percentForReferLv2).div(100);
                address referrerLv1 = referrers[address(msg.sender)];
                uint256 referAmountForDev = 0;

                if (referrerLv1 != address(0)) {
                    uint256 lpStaked = getLPTokenStaked(referrerLv1);
                    if (lpStaked >= stakeLPLv1) {
                        pool.rewardToken.transfer(referrerLv1, referAmountLv1);
                    } else {
                        referAmountForDev = referAmountLv1.add(referAmountLv2);
                    }

                    address referrerLv2 = referrers[referrerLv1];
                    uint256 lpStaked2 = getLPTokenStaked(referrerLv2);
                    if (referrerLv2 != address(0) && lpStaked2 >= stakeLPLv2) {
                        pool.rewardToken.transfer(referrerLv2, referAmountLv2);
                    } else {
                        referAmountForDev = referAmountLv2;
                    }
                } else {
                    referAmountForDev = referAmountLv1.add(referAmountLv2);
                }

                if (referAmountForDev > 0) {
                    pool.rewardToken.transfer(devaddr, referAmountForDev);
                }

                uint256 amount = pending.sub(referAmountLv1).sub(referAmountLv2);
                pool.rewardToken.transfer(msg.sender, amount.mul(100 - pool.percentLockReward).div(100));
                uint256 lockAmount = amount.mul(pool.percentLockReward).div(100);
                farmLock(msg.sender, lockAmount, _pid);

                user.rewardDebtAtBlock = block.number;

                emit SendReward(msg.sender, _pid, amount, lockAmount);
            }

            user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);
        }
    }

    // Deposit LP tokens to BSCXNTS.
    function deposit(uint256 _pid, uint256 _amount, address _referrer) public {
        require(_amount > 0, "BSCXNTS::deposit: amount must be greater than 0");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        _harvest(_pid);
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        if (user.amount == 0) {
            user.rewardDebtAtBlock = block.number;
        }
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);

        if (referrers[address(msg.sender)] == address(0) && _referrer != address(0)) {
            referrers[address(msg.sender)] = address(_referrer);
        }

        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from BSCXNTS.
    function withdraw(uint256 _pid, uint256 _amount) public {
        require(status == true, "BSCXNTS::withdraw: can not withdraw");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "BSCXNTS::withdraw: not good");

        updatePool(_pid);
        _harvest(_pid);

        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }

    function getNewRewardPerBlock(uint256 pid1) public view returns (uint256) {
        PoolInfo memory pool = poolInfo[pid1];

        uint256 multiplier = getMultiplier(block.number -1, block.number, halvingAtBlocks[pid1], rewardMultipliers[pid1], pool.startBlock);
        if (pid1 == 0) {
            return multiplier.mul(pool.rewardPerBlock);
        }
        else {
            return multiplier
                .mul(pool.rewardPerBlock)
                .mul(pool.allocPoint)
                .div(totalAllocPoints[pool.rewardToken]);
        }
    }

    function totalLockInPool(uint256 _pid) public view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        return pool.totalLock;
    }

    function totalLock(IERC20 _rewardToken) public view returns (uint256) {
        return totalLocks[_rewardToken];
    }

    function lockOf(address _holder, uint256 _pid) public view returns (uint256) {
        UserInfo memory user = userInfo[_pid][_holder];

        return user.lockAmount;
    }

    function lastUnlockBlock(address _holder, uint256 _pid) public view returns (uint256) {
        UserInfo memory user = userInfo[_pid][_holder];

        return user.lastUnlockBlock;
    }

    function farmLock(address _holder, uint256 _amount, uint256 _pid) internal {
        require(_holder != address(0), "ERC20: lock to the zero address");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(_amount <= pool.rewardToken.balanceOf(address(this)), "ERC20: lock amount over blance");
        user.lockAmount = user.lockAmount.add(_amount);
        pool.totalLock = pool.totalLock.add(_amount);
        totalLocks[pool.rewardToken] = totalLocks[pool.rewardToken].add(_amount);

        if (user.lastUnlockBlock < pool.lockFromBlock) {
            user.lastUnlockBlock = pool.lockFromBlock;
        }
        emit Lock(_holder, _amount);
    }

    function canUnlockAmount(address _holder, uint256 _pid) public view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_holder];

        if (block.number < pool.lockFromBlock) {
            return 0;
        }
        else if (block.number >= pool.lockToBlock) {
            return user.lockAmount;
        }
        else {
            uint256 releaseBlock = block.number.sub(user.lastUnlockBlock);
            uint256 numberLockBlock = pool.lockToBlock.sub(user.lastUnlockBlock);
            return user.lockAmount.mul(releaseBlock).div(numberLockBlock);
        }
    }

    function unlock(uint256 _pid) public {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.lockAmount > 0, "ERC20: cannot unlock");

        uint256 amount = canUnlockAmount(msg.sender, _pid);
        // just for sure
        if (amount > pool.rewardToken.balanceOf(address(this))) {
            amount = pool.rewardToken.balanceOf(address(this));
        }
        pool.rewardToken.transfer(msg.sender, amount);
        user.lockAmount = user.lockAmount.sub(amount);
        user.lastUnlockBlock = block.number;
        pool.totalLock = pool.totalLock.sub(amount);
        totalLocks[pool.rewardToken] = totalLocks[pool.rewardToken].sub(amount);
    }
}
