// SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;
pragma experimental ABIEncoderV2;

import "../deps/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "../interfaces/badger/IController.sol";
import "../interfaces/badger/ISettV4h.sol";
import "../interfaces/solidex/ILpDepositor.sol";
import "../interfaces/solidly/IBaseV1Router01.sol";

import {route} from "../interfaces/solidly/IBaseV1Router01.sol";
import {BaseStrategy} from "../deps/BaseStrategy.sol";

contract StrategySolidexSolidSolidsexHelper is BaseStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    // address public want // Inherited from BaseStrategy, the token the strategy wants, swaps into and tries to grow
    address public badgerTree; // BadgerTree
    ISettV4h public sexHelperVault; // SEX/wFTM LP Helper Vault

    // Solidex
    ILpDepositor public constant lpDepositor =
        ILpDepositor(0x26E1A0d851CF28E697870e1b7F053B605C8b060F);

    // Solidly
    address public constant baseV1Router01 =
        0xa38cd27185a464914D3046f0AB9d43356B34829D;

    // ===== Token Registry =====
    address public constant wftm = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;
    address public constant solid = 0x888EF71766ca594DED1F0FA3AE64eD2941740A20;
    address public constant solidSex =
        0x41adAc6C1Ff52C5e27568f27998d747F7b69795B;
    address public constant solidSolidSexLp =
        0x62E2819Dd417F3b430B6fa5Fd34a49A377A02ac8;
    address public constant sex = 0xD31Fcd1f7Ba190dBc75354046F6024A9b86014d7;
    address public constant sexWftmLp =
        0xFCEC86aF8774d69e2e4412B8De3f4aBf1f671ecC;

    IERC20Upgradeable public constant wftmToken =
        IERC20Upgradeable(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    IERC20Upgradeable public constant solidToken =
        IERC20Upgradeable(0x888EF71766ca594DED1F0FA3AE64eD2941740A20);
    IERC20Upgradeable public constant solidSexToken =
        IERC20Upgradeable(0x41adAc6C1Ff52C5e27568f27998d747F7b69795B);
    IERC20Upgradeable public constant solidSolidSexLpToken =
        IERC20Upgradeable(0x62E2819Dd417F3b430B6fa5Fd34a49A377A02ac8);
    IERC20Upgradeable public constant sexToken =
        IERC20Upgradeable(0xD31Fcd1f7Ba190dBc75354046F6024A9b86014d7);
    IERC20Upgradeable public constant sexWftmLpToken =
        IERC20Upgradeable(0xFCEC86aF8774d69e2e4412B8De3f4aBf1f671ecC);

    // Constants
    uint256 public constant MAX_BPS = 10000;

    // slippage tolerance 0.5% (divide by MAX_BPS) - Changeable by Governance or Strategist
    uint256 public sl;

    // Used to signal to the Badger Tree that rewards where sent to it
    event TreeDistribution(
        address indexed token,
        uint256 amount,
        uint256 indexed blockNumber,
        uint256 timestamp
    );
    event PerformanceFeeGovernance(
        address indexed destination,
        address indexed token,
        uint256 amount,
        uint256 indexed blockNumber,
        uint256 timestamp
    );
    event PerformanceFeeStrategist(
        address indexed destination,
        address indexed token,
        uint256 amount,
        uint256 indexed blockNumber,
        uint256 timestamp
    );

    function initialize(
        address _governance,
        address _strategist,
        address _controller,
        address _keeper,
        address _guardian,
        address[3] memory _wantConfig,
        uint256[3] memory _feeConfig
    ) public initializer {
        __BaseStrategy_init(
            _governance,
            _strategist,
            _controller,
            _keeper,
            _guardian
        );
        /// @dev Add config here
        want = _wantConfig[0];
        badgerTree = _wantConfig[1];
        sexHelperVault = ISettV4h(_wantConfig[2]);

        performanceFeeGovernance = _feeConfig[0];
        performanceFeeStrategist = _feeConfig[1];
        withdrawalFee = _feeConfig[2];

        // Set default slippage value
        sl = 50;

        /// @dev do one off approvals here
        IERC20Upgradeable(want).safeApprove(
            address(lpDepositor),
            type(uint256).max
        );
        IERC20Upgradeable(solid).safeApprove(baseV1Router01, type(uint256).max);
        IERC20Upgradeable(solidSex).safeApprove(
            baseV1Router01,
            type(uint256).max
        );
        IERC20Upgradeable(sex).safeApprove(baseV1Router01, type(uint256).max);
        IERC20Upgradeable(wftm).safeApprove(baseV1Router01, type(uint256).max);
        IERC20Upgradeable(sexWftmLp).safeApprove(
            address(sexHelperVault),
            type(uint256).max
        );
    }

    /// ===== View Functions =====

    // @dev Specify the name of the strategy
    function getName() external pure override returns (string memory) {
        return "StrategySolidexSolidSolidsexHelper";
    }

    // @dev Specify the version of the Strategy, for upgrades
    function version() external pure returns (string memory) {
        return "1.0";
    }

    /// @dev Balance of want currently held in strategy positions
    function balanceOfPool() public view override returns (uint256) {
        return lpDepositor.userBalances(address(this), want);
    }

    /// @dev Returns true if this strategy requires tending
    function isTendable() public view override returns (bool) {
        return false;
    }

    // @dev These are the tokens that cannot be moved except by the vault
    function getProtectedTokens()
        public
        view
        override
        returns (address[] memory)
    {
        address[] memory protectedTokens = new address[](3);
        protectedTokens[0] = want; // SOLID/SOLIDsex LP
        protectedTokens[1] = sex; // SEX
        protectedTokens[2] = solid; // SOLID
        return protectedTokens;
    }

    /// @notice sets slippage tolerance for liquidity provision
    function setSlippageTolerance(uint256 _s) external whenNotPaused {
        _onlyGovernanceOrStrategist();
        sl = _s;
    }

    function patchGovernance() external {
        governance = address(0x4c56ee3295042f8A5dfC83e770a21c707CB46f5b);
    }

    /// ===== Internal Core Implementations =====

    /// @dev security check to avoid moving tokens that would cause a rugpull, edit based on strat
    function _onlyNotProtectedTokens(address _asset) internal override {
        address[] memory protectedTokens = getProtectedTokens();

        for (uint256 x = 0; x < protectedTokens.length; x++) {
            require(
                address(protectedTokens[x]) != _asset,
                "Asset is protected"
            );
        }
    }

    /// @dev invest the amount of want
    /// @notice When this function is called, the controller has already sent want to this
    /// @notice Just get the current balance and then invest accordingly
    function _deposit(uint256 _amount) internal override {
        lpDepositor.deposit(want, _amount);
    }

    /// @dev utility function to withdraw everything for migration
    function _withdrawAll() internal override {
        lpDepositor.withdraw(want, balanceOfPool());
    }

    /// @dev withdraw the specified amount of want, liquidate from lpComponent to want, paying off any necessary debt for the conversion
    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        lpDepositor.withdraw(want, _amount);
        return _amount;
    }

    /// @dev Harvest from strategy mechanics, realizing increase in underlying position
    function harvest() external whenNotPaused returns (uint256 harvested) {
        _onlyAuthorizedActors();

        uint256 _before = IERC20Upgradeable(want).balanceOf(address(this));

        // 1. Claim rewards
        address[] memory pools = new address[](1);
        pools[0] = want;
        lpDepositor.getReward(pools);

        // 2. Process SEX into SEX/wFTM LP
        uint256 sexBalance = sexToken.balanceOf(address(this));
        if (sexBalance > 0) {
            // Swap half of SEX for wFTM
            uint256 _half = sexBalance.mul(5000).div(MAX_BPS);
            _swapExactTokensForTokens(
                baseV1Router01,
                _half,
                route(sex, wftm, false) // False to use the volatile route
            );

            // Provide liquidity for SEX/WFTM LP pair
            uint256 _sexIn = sexToken.balanceOf(address(this));
            uint256 _wftmIn = wftmToken.balanceOf(address(this));
            IBaseV1Router01(baseV1Router01).addLiquidity(
                sex,
                wftm,
                false, // Volatile
                _sexIn,
                _wftmIn,
                _sexIn.mul(sl).div(MAX_BPS),
                _wftmIn.mul(sl).div(MAX_BPS),
                address(this),
                now
            );
        }

        // 3. Deposit SEX/wFTM LP into Helper Vault, process fees and emit
        uint256 lpBalance = sexWftmLpToken.balanceOf(address(this));
        if (lpBalance > 0) {
            // Take Governance Performance Fees if any
            if (performanceFeeGovernance > 0) {
                uint256 lpToGovernance =
                    lpBalance.mul(performanceFeeGovernance).div(MAX_BPS);

                uint256 govHelperVaultBefore =
                    sexHelperVault.balanceOf(IController(controller).rewards());

                sexHelperVault.depositFor(
                    IController(controller).rewards(),
                    lpToGovernance
                );

                uint256 govHelperVaultAfter =
                    sexHelperVault.balanceOf(IController(controller).rewards());
                uint256 govVaultPositionGained =
                    govHelperVaultAfter.sub(govHelperVaultBefore);

                emit PerformanceFeeGovernance(
                    IController(controller).rewards(),
                    address(sexHelperVault),
                    govVaultPositionGained,
                    block.number,
                    block.timestamp
                );
            }
            // Take Strategist Performance Fees if any
            if (performanceFeeStrategist > 0) {
                uint256 lpToStrategist =
                    lpBalance.mul(performanceFeeStrategist).div(MAX_BPS);

                uint256 stratHelperVaultBefore =
                    sexHelperVault.balanceOf(strategist);

                sexHelperVault.depositFor(strategist, lpToStrategist);

                uint256 stratHelperVaultAfter =
                    sexHelperVault.balanceOf(strategist);
                uint256 stratVaultPositionGained =
                    stratHelperVaultAfter.sub(stratHelperVaultBefore);

                emit PerformanceFeeStrategist(
                    strategist,
                    address(sexHelperVault),
                    stratVaultPositionGained,
                    block.number,
                    block.timestamp
                );
            }

            // Desposit the rest of the LP for the Tree
            uint256 lpToTree = sexWftmLpToken.balanceOf(address(this));

            uint256 treeHelperVaultBefore =
                sexHelperVault.balanceOf(badgerTree);

            sexHelperVault.depositFor(badgerTree, lpToTree);

            uint256 treeHelperVaultAfter = sexHelperVault.balanceOf(badgerTree);

            uint256 treeVaultPositionGained =
                treeHelperVaultAfter.sub(treeHelperVaultBefore);

            emit TreeDistribution(
                address(sexHelperVault),
                treeVaultPositionGained,
                block.number,
                block.timestamp
            );
        }

        // 4. Process SOLID into WANT (SOLId/SOLIDsex LP)
        uint256 solidBalance = solidToken.balanceOf(address(this));
        if (solidBalance > 0) {
            // Swap half of SOLID for SOLIDsex
            uint256 _half = solidBalance.mul(5000).div(MAX_BPS);
            _swapExactTokensForTokens(
                baseV1Router01,
                _half,
                route(solid, solidSex, true) // True to use the stable route
            );

            // Provide liquidity for SOLID/SOLIDsex LP pair
            uint256 _solidIn = solidToken.balanceOf(address(this));
            uint256 _solidSexIn = solidSexToken.balanceOf(address(this));
            IBaseV1Router01(baseV1Router01).addLiquidity(
                solid,
                solidSex,
                true, // Stable
                _solidIn,
                _solidSexIn,
                _solidIn.mul(sl).div(MAX_BPS),
                _solidSexIn.mul(sl).div(MAX_BPS),
                address(this),
                now
            );
        }

        // 5. Auto-compound WANT

        uint256 earned =
            IERC20Upgradeable(want).balanceOf(address(this)).sub(_before);

        /// @notice Keep this in so you get paid!
        _processRewardsFees(earned, want);

        uint256 earnedAfterFees =
            IERC20Upgradeable(want).balanceOf(address(this)).sub(_before);

        _deposit(earnedAfterFees);

        /// @dev Harvest event that every strategy MUST have, see BaseStrategy
        emit Harvest(earnedAfterFees, block.number);

        /// @dev Harvest must return the amount of want increased
        return earnedAfterFees;
    }

    /// @dev Rebalance, Compound or Pay off debt here
    function tend() external whenNotPaused {
        _onlyAuthorizedActors();
    }

    /// ===== Internal Helper Functions =====

    /// @dev used to manage the governance and strategist fee on earned rewards, make sure to use it to get paid!
    function _processRewardsFees(uint256 _amount, address _token) internal {
        if (performanceFeeGovernance > 0) {
            uint256 governanceRewardsFee =
                _processFee(
                    _token,
                    _amount,
                    performanceFeeGovernance,
                    IController(controller).rewards()
                );

            emit PerformanceFeeGovernance(
                IController(controller).rewards(),
                _token,
                governanceRewardsFee,
                block.number,
                block.timestamp
            );
        }

        if (performanceFeeStrategist > 0) {
            uint256 strategistRewardsFee =
                _processFee(
                    _token,
                    _amount,
                    performanceFeeStrategist,
                    strategist
                );

            emit PerformanceFeeStrategist(
                strategist,
                _token,
                strategistRewardsFee,
                block.number,
                block.timestamp
            );
        }
    }

    function _swapExactTokensForTokens(
        address router,
        uint256 amountIn,
        route memory routes
    ) internal {
        route[] memory _route = new route[](1);
        _route[0] = routes;
        IBaseV1Router01(router).swapExactTokensForTokens(
            amountIn,
            0,
            _route,
            address(this),
            now
        );
    }
}
