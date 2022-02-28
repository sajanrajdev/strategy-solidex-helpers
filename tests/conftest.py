from brownie import (
    accounts,
    interface,
    Controller,
    SettV4,
    StrategySolidexSexWftmHelper,
    StrategySolidexSolidSolidsexHelper,
    Wei,
)
from config import (
    BADGER_DEV_MULTISIG,
    BADGER_TREE,
    FEES,
    SEX_WFTM_LP,
    SOLID_SOLIDSEX_LP
)
from dotmap import DotMap
import pytest
from rich.console import Console
import time
from helpers.time import days

console = Console()


@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass


def deploy(sett_config):
    """
    Deploys, vault, controller and strats and wires them up for you to test
    """
    deployer = accounts[0]

    strategist = deployer
    keeper = deployer
    guardian = deployer

    governance = accounts.at(BADGER_DEV_MULTISIG, force=True)

    controller = Controller.deploy({"from": deployer})
    controller.initialize(BADGER_DEV_MULTISIG, strategist, keeper, BADGER_DEV_MULTISIG)

    # Deploy both helper vaults
    sexHelperSett = SettV4.deploy({"from": deployer})
    solidHelperSett = SettV4.deploy({"from": deployer})

    sexSettArgs = [
        SEX_WFTM_LP,
        controller,
        BADGER_DEV_MULTISIG,
        keeper,
        guardian,
        False,
        "prefix",
        "PREFIX",
    ]

    solidSettArgs = [
        SOLID_SOLIDSEX_LP,
        controller,
        BADGER_DEV_MULTISIG,
        keeper,
        guardian,
        False,
        "prefix",
        "PREFIX",
    ]

    # Initialize both vaults
    sexHelperSett.initialize(*sexSettArgs)
    solidHelperSett.initialize(*solidSettArgs)

    sexHelperSett.unpause({"from": governance})
    solidHelperSett.unpause({"from": governance})

    # Add both vaults to controller
    controller.setVault(sexHelperSett.token(), sexHelperSett)
    controller.setVault(solidHelperSett.token(), solidHelperSett)

    # Deploy both Helper strats
    sexHelperStrategy = StrategySolidexSexWftmHelper.deploy({"from": deployer})
    solidHelperStrategy = StrategySolidexSolidSolidsexHelper.deploy({"from": deployer})

    sexStratArgs = [
        BADGER_DEV_MULTISIG,
        strategist,
        controller,
        keeper,
        guardian,
        [
            SEX_WFTM_LP,
            BADGER_TREE,
            solidHelperStrategy,
        ],
        FEES,
    ]

    solidStratArgs = [
        BADGER_DEV_MULTISIG,
        strategist,
        controller,
        keeper,
        guardian,
        [
            SOLID_SOLIDSEX_LP,
            BADGER_TREE,
            sexHelperStrategy,
        ],
        FEES,
    ]

    # Initialize both helper strats
    sexHelperStrategy.initialize(*sexStratArgs)
    solidHelperStrategy.initialize(*solidStratArgs)


    ## Start up Strategy
    if sett_config.WANT == "0xFCEC86aF8774d69e2e4412B8De3f4aBf1f671ecC":
        strategy = sexHelperStrategy
        sett = sexHelperSett

        ## Grant contract access on other helper vault
        solidHelperSett.approveContractAccess(strategy, {"from": governance})

    elif sett_config.WANT == "0x62E2819Dd417F3b430B6fa5Fd34a49A377A02ac8":
        strategy = solidHelperStrategy
        sett = solidHelperSett

        ## Grant contract access on other helper vault
        sexHelperSett.approveContractAccess(strategy, {"from": governance})

    # Get whale
    whale = accounts.at(sett_config.WHALE, force=True)

    ## Set up tokens
    want = interface.IERC20(strategy.want())

    ## Wire up Controller to Strart
    ## Only doing for strat under test
    controller.approveStrategy(want, strategy, {"from": governance})
    controller.setStrategy(want, strategy, {"from": deployer})

    # Transfer want from whale
    want.transfer(deployer.address, want.balanceOf(whale.address), {"from": whale})

    assert want.balanceOf(deployer.address) > 0

    return DotMap(
        governance=governance,
        deployer=deployer,
        controller=controller,
        sett=sett,
        strategy=strategy,
        want=want,
    )
