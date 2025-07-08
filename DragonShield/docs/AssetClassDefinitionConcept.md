DragonShield - Asset Class Definition Concept

Document ID:AssetClassConcept.md
Version:2.1
Date:2025-07-08
Author:DragonShield Maintainers
Status:Draft

⸻

Document History

VersionDateAuthorChanges
1.02025-06-30SystemInitial creation of the asset class conceptual document.
1.12025-06-30SystemAdded brief introductory description at the top.
2.02025-07-08DragonShield MaintainersMerged hierarchical and unified model; added crypto subclass; consolidated benefits.
2.12025-07-08DragonShield MaintainersAdded ZKB Mapping section.

⸻

1. Introduction & Purpose

This document defines the hierarchical asset classification methodology adopted by the DragonShield application. It replaces the legacy flat InstrumentGroups structure with a robust two-level taxonomy—AssetClass and AssetSubClass—to ensure clarity, consistency, and extensibility across all asset types, including cash, securities, derivatives, commodities, and alternative investments.

⸻

2. AssetClass Table

AssetClass CodeDescription
LIQLiquid assets (cash, money market)
EQTEquity securities
FIXFixed income instruments (bonds, notes)
COMCommodities
DERDerivative contracts
ALTAlternative investments (real estate, hedge funds, crypto)

⸻

3. AssetSubClass Table

AssetClassSubClass CodeDescription
LIQCASHCash instruments (e.g. USD_CASH, CHF_CASH)
LIQMMKTMoney market funds
EQTAGMAmerican equity
EQTEGMEuropean equity
FIXGOVGovernment bonds
FIXCORPCorporate bonds
COMENREnergy commodities
COMMETMetal commodities
DEROPTOptions
DERFUTFutures
ALTREReal estate investments
ALTHFHedge funds
ALTCRYCryptocurrencies (e.g. Bitcoin, Ethereum)

⸻

4. Instruments

All assets are represented as entries in the INSTRUMENT table:
•Cash instruments: USD_CASH, CHF_CASH, etc., under SubClass = CASH, AssetClass = LIQ.
•Securities: equities (AAPL_US, NESN_SW), fixed income (US9128285M81), etc.
•Commodities & Derivatives: futures, options, commodity codes.
•Alt & Crypto: real estate funds, hedge funds, cryptocurrencies (BTC, ETH).

Each instrument record includes:
•instrument_id
•name / ticker / ISIN
•assetclass_id (FK to AssetClass)
•assetsubclass_id (FK to AssetSubClass)

⸻

5. Unified Accounts, Transactions & Positions Model
•Accounts table: single table for all account types (BANK, CUSTODY, CASH, etc.), distinguished by account_type_id.
•Cash as an instrument: cash accounts are simply accounts whose primary positions are cash instruments.
•Transactions table: every movement—buys, sells, deposits, withdrawals, transfers—references an instrument_id, account_id, and quantity/amount.
•Positions view: aggregates by account_id + instrument_id, yielding all asset positions side by side.

Benefits:

CategoryDetails
ClarityTwo-level taxonomy eliminates ambiguity in asset classification.
UniformitySingle schema for all asset types—no special cases for cash vs securities.
SimplicityParsers and reports handle any asset identically.
ExtensibilityNew instruments (e.g., FX forwards, crypto) plug in without model changes.
ReportingFlexible reporting at class, subclass, or instrument level.
Industry AlignmentAligns with best practices in portfolio management and risk analysis.

⸻

6. Examples

Instrument NameSubClass CodeAssetClass CodeDescription
Bitcoin (BTC)CRYALTA digital currency classified under cryptocurrencies.
Swiss Franc CashCASHLIQFiat currency cash instrument in Swiss Franc.
Apple Inc SharesAGMEQTAmerican equity representing AAPL common stock.
US Treasury T-BillGOVFIXShort-term US government debt instrument.

⸻

7. ZKB Mapping

ZKB GroupAssetClass CodeAssetSubClass CodeNotes
CashLIQCASHBank deposit cash balances.
Money Market FundsLIQMMKTMoney market instruments.
Equities (US)EQTAGMAmerican equities.
Equities (EU)EQTEGMEuropean equities.
Government BondsFIXGOVSovereign debt.
Corporate BondsFIXCORPCorporate debt.
Energy CommoditiesCOMENROil, gas, etc.
Metal CommoditiesCOMMETGold, silver, etc.
OptionsDEROPTExchange-traded options.
FuturesDERFUTExchange-traded futures.
Real Estate InvestmentsALTRERE funds, REITs.
Hedge FundsALTHFVarious strategies.
CryptocurrenciesALTCRYBTC, ETH, etc.
