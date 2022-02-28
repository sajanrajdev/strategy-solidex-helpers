from helpers.StrategyCoreResolver import StrategyCoreResolver
from rich.console import Console
from brownie import interface

console = Console()

class StrategyResolver(StrategyCoreResolver):
    def get_strategy_destinations(self):
        """
        Track balances for all strategy implementations
        (Strategy Must Implement)
        """
        # E.G
        # strategy = self.manager.strategy
        # return {
        #     "gauge": strategy.gauge(),
        #     "mintr": strategy.mintr(),
        # }

        return {}

    def hook_after_confirm_withdraw(self, before, after, params):
        """
        Specifies extra check for ordinary operation on withdrawal
        Use this to verify that balances in the get_strategy_destinations are properly set
        """
        assert True

    def hook_after_confirm_deposit(self, before, after, params):
        """
        Specifies extra check for ordinary operation on deposit
        Use this to verify that balances in the get_strategy_destinations are properly set
        """
        assert True

    def hook_after_earn(self, before, after, params):
        """
        Specifies extra check for ordinary operation on earn
        Use this to verify that balances in the get_strategy_destinations are properly set
        """
        assert True

    def confirm_harvest_events(self, before, after, tx):
        key = "TreeDistribution"
        assert key in tx.events
        assert len(tx.events[key]) >= 1
        for event in tx.events[key]:
            keys = [
                "token",
                "amount",
                "blockNumber",
                "timestamp",
            ]
            for key in keys:
                assert key in event

            console.print(
                "[blue]== Solidex Strat harvest() TreeDistribution State ==[/blue]"
            )
            self.printState(event, keys)

        key = "PerformanceFeeGovernance"
        assert key in tx.events
        assert len(tx.events[key]) >= 1
        for event in tx.events[key]:
            keys = [
                "destination",
                "token",
                "amount",
                "blockNumber",
                "timestamp",
            ]
            for key in keys:
                assert key in event

            console.print(
                "[blue]== Solidex Strat harvest() PerformanceFeeGovernance State ==[/blue]"
            )
            self.printState(event, keys)

        key = "Harvest"
        assert key in tx.events
        assert len(tx.events[key]) == 1
        event = tx.events[key][0]
        keys = [
            "harvested",
        ]
        for key in keys:
            assert key in event

        console.print("[blue]== Helper Strat harvest() State ==[/blue]")
        self.printState(event, keys)

        key = "PerformanceFeeStrategist"
        assert key not in tx.events
        # Strategist performance fee is set to 0

    def confirm_harvest(self, before, after, tx):
        """
        Verfies that the Harvest produced yield and fees
        """
        console.print("=== Compare Harvest ===")
        self.confirm_harvest_events(before, after, tx)
        super().confirm_harvest(before, after, tx)

        valueGained = after.get("sett.pricePerFullShare") > before.get(
            "sett.pricePerFullShare"
        )

    def confirm_tend(self, before, after, tx):
        """
        Tend Should;
        - Increase the number of staked tended tokens in the strategy-specific mechanism
        - Reduce the number of tended tokens in the Strategy to zero

        (Strategy Must Implement)
        """
        assert True

    def add_entity_balances_for_tokens(self, calls, tokenKey, token, entities):
        entities["badgerTree"] = self.manager.strategy.badgerTree()
        entities["strategy"] = self.manager.strategy.address
        entities["lpDepositor"] = self.manager.strategy.lpDepositor()
        entities["baseV1Router01"] = self.manager.strategy.baseV1Router01()
        entities["solidSolidSexLp"] = self.manager.strategy.solidSolidSexLp()
        entities["sexWftmLp"] = self.manager.strategy.sexWftmLp()
        if self.manager.strategy.name() == "StrategySolidexSexWftmHelper":
            entities["solidHelperVault"] = self.manager.strategy.solidHelperVault()
        else:
            entities["sexHelperVault"] = self.manager.strategy.sexHelperVault()

        super().add_entity_balances_for_tokens(calls, tokenKey, token, entities)
        return calls

    def add_balances_snap(self, calls, entities):
        super().add_balances_snap(calls, entities)
        strategy = self.manager.strategy

        solid = interface.IERC20(strategy.solid())
        sex = interface.IERC20(strategy.sex())
        solidsex = interface.IERC20(strategy.sex())
        wftm = interface.IERC20(strategy.sex())
        solidSolidSexLp = interface.IERC20(strategy.sex())
        sexWftmLp = interface.IERC20(strategy.sex())
        if strategy.name() == "StrategySolidexSexWftmHelper":
            solidHelper = interface.IERC20(strategy.solidHelperVault())
            calls = self.add_entity_balances_for_tokens(calls, "solidHelper", solidHelper, entities)
        else:
            sexHelper = interface.IERC20(strategy.sexHelperVault())
            calls = self.add_entity_balances_for_tokens(calls, "sexHelper", sexHelper, entities)

        calls = self.add_entity_balances_for_tokens(calls, "solid", solid, entities)
        calls = self.add_entity_balances_for_tokens(calls, "sex", sex, entities)
        calls = self.add_entity_balances_for_tokens(calls, "solidsex", solidsex, entities)
        calls = self.add_entity_balances_for_tokens(calls, "wftm", wftm, entities)
        calls = self.add_entity_balances_for_tokens(calls, "solidSolidSexLp", solidSolidSexLp, entities)
        calls = self.add_entity_balances_for_tokens(calls, "sexWftmLp", sexWftmLp, entities)
