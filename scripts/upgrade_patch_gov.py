from brownie import interface, accounts, StrategySolidexSolidSolidsexHelper

GOV = accounts.at("0x4c56ee3295042f8A5dfC83e770a21c707CB46f5b", force=True)
PROXY_ADMIN = interface.IProxyAdmin("0x20Dce41Acca85E8222D6861Aa6D23B6C941777bF", owner=GOV)

def main():
    strat = StrategySolidexSolidSolidsexHelper.at("0x7AfB2E386b7990507009f81B3c486c8C596501a4")

    assert strat.governance() != GOV.address
    print("Current Governance:", strat.governance())

    logic = StrategySolidexSolidSolidsexHelper.deploy({"from": accounts[0]})
    PROXY_ADMIN.upgrade(strat.address, logic.address)

    strat.patchGovernance({"from": accounts[0]})

    assert strat.governance() == GOV.address
    print("New Governance:", strat.governance())

    # Test running a harvest
    tx = strat.harvest({"from": GOV})
    assert tx.events["Harvest"][0]["harvested"] > 0