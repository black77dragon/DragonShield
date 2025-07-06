# Dragon Shield Database Schema Documentation

## Table of Contents
1. [Overview](#overview)
2. [Requirements Analysis](#requirements-analysis)
3. [Schema Architecture](#schema-architecture)
4. [Table Specifications](#table-specifications)
5. [Relationships & Constraints](#relationships--constraints)
6. [Views & Calculations](#views--calculations)
7. [Implementation Guidelines](#implementation-guidelines)
8. [Usage Examples](#usage-examples)

## Overview

The Dragon Shield database schema is designed to support comprehensive personal asset management with a focus on:
- **Privacy-first design** with local SQLite storage
- **Multi-currency support** with automatic CHF conversion
- **Flexible portfolio management** with sub-portfolio capabilities
- **Comprehensive transaction tracking** across multiple asset classes
- **FX rate management** with API integration support
- **Data integrity** through constraints and validation

### Database Technology
- **Engine**: SQLite 3.x
- **Storage**: Local encrypted file
- **Backup**: File-based with optional cloud sync
- **Performance**: Optimized for 100K+ transactions

## Requirements Analysis

### Functional Requirements Met

#### 1. Configuration Management ✅
**Requirement**: Centralized system settings including base currency (CHF) and "as of date"
**Implementation**: 
- `Configuration` table with key-value pairs
- Type-safe configuration with data validation
- Default settings for Swiss investor profile

#### 2. Multi-Currency Support ✅
**Requirement**: Support multiple currencies with historical FX rates against CHF
**Implementation**:
- `Currencies` table with comprehensive currency list
- `ExchangeRates` table with historical rates to CHF
- Automatic CHF conversion via database triggers
- API integration support for automated rate updates

#### 3. Sub-Portfolio Management ✅
**Requirement**: Create sub-portfolios and assign instruments flexibly
**Implementation**:
- `Portfolios` table for portfolio definitions
- `PortfolioInstruments` many-to-many relationship
- Default assignment to "Main Portfolio"
- Support for multiple portfolio assignments per instrument

#### 4. Asset Classification ✅
**Requirement**: Organize assets by type with inclusion/exclusion flags
**Implementation**:
- `InstrumentGroups` for asset classification
- `Instruments` table with detailed metadata
- Portfolio inclusion flags at both group and instrument level
- Support for ISIN, ticker symbols, and exchanges

#### 5. Account Management ✅
**Requirement**: Track multiple accounts (banks, custody, crypto, pension)
**Implementation**:
- `Accounts` table with comprehensive account types
- Institution metadata and BIC codes
- Account-level inclusion flags
- Currency assignment per account

#### 6. Transaction Management ✅
**Requirement**: Complete transaction tracking with fees, taxes, and references
**Implementation**:
- `Transactions` table with full financial details
- `TransactionTypes` for flexible categorization
- Automatic CHF conversion and exchange rate tracking
- Import source tracking and external references

#### 7. Data Import Support ✅
**Requirement**: Support for CSV, XLSX, PDF imports with duplicate detection
**Implementation**:
- `ImportSessions` table for import tracking
- File hash-based duplicate detection
- Import status and error logging
- Transaction-level import source tracking

### Non-Functional Requirements Met

#### Performance ✅
- Optimized indexes on high-query columns
- Efficient views for portfolio calculations
- WAL mode for concurrent access
- Designed for 100K+ transaction scale

#### Data Integrity ✅
- Foreign key constraints throughout
- Check constraints for data validation
- Automatic timestamp triggers
- Data validation views

#### Extensibility ✅
- Modular table design
- Configurable transaction types
- Flexible portfolio assignment
- API integration ready

## Schema Architecture

### Logical Data Model

```
Configuration Layer
├── Configuration (system settings)
├── Currencies (supported currencies)
└── ExchangeRates (historical FX rates)

Asset Management Layer
├── InstrumentGroups (asset classification)
├── Instruments (individual securities)
├── Portfolios (sub-portfolio definitions)
└── PortfolioInstruments (portfolio assignments)

Account & Transaction Layer
├── Accounts (bank/custody accounts)
├── TransactionTypes (transaction categories)
├── Transactions (core transaction data)
├── PositionReports (uploaded positions)
└── ImportSessions (import tracking)

Analysis Layer
├── Positions (view)
├── PortfolioSummary (view)
├── AccountSummary (view)
└── InstrumentPerformance (view)
```

### Data Flow Architecture

```
1. Configuration Setup → System Parameters
2. Currency & FX Rates → Multi-Currency Support
3. Asset Definition → Instrument Catalog
4. Portfolio Creation → Investment Organization
5. Account Setup → Financial Institution Links
6. Transaction Recording → Financial Activity
7. Portfolio Calculation → Investment Analysis
```

## Table Specifications

### Core Configuration Tables

#### Configuration
**Purpose**: System-wide settings and parameters
```sql
- config_id: Primary key
- key: Setting identifier (unique)
- value: Setting value
- data_type: Value type validation
- description: Human-readable description
```

**Key Settings**:
- `base_currency`: Base reporting currency (CHF)
- `as_of_date`: Portfolio calculation cutoff date
- `decimal_precision`: Financial calculation precision
- `auto_fx_update`: Enable automatic FX updates
- `fx_api_provider`: FX rate data source

#### Currencies
**Purpose**: Supported currency definitions
```sql
- currency_code: ISO currency code (primary key)
- currency_name: Full currency name
- currency_symbol: Display symbol
- is_active: Currency status
- api_supported: Available via FX API
```

#### ExchangeRates
**Purpose**: Historical exchange rates to CHF
```sql
- rate_id: Primary key
- currency_code: Currency being converted
- rate_date: Rate effective date
- rate_to_chf: Conversion rate to CHF
- rate_source: Data source (manual/api/import)
- api_provider: Source API provider
- is_latest: Flag for current rate
```

**Key Features**:
- Historical rate tracking
- Multiple data sources
- Automatic rate updates via API
- CHF as base currency (rate = 1.0)

### Asset Management Tables

#### InstrumentGroups
**Purpose**: Asset class classification
```sql
- group_id: Primary key
- group_code: Short identifier (unique)
- group_name: Display name
- group_description: Detailed description
- sort_order: Display ordering
- include_in_portfolio: Portfolio inclusion flag
- is_active: Group status
```

**Standard Groups**:
- EQUITY: Individual stocks
- ETF: Exchange-traded funds
- BOND: Fixed income securities
- FUND: Mutual funds
- CRYPTO: Cryptocurrencies
- REIT: Real estate investment trusts
- CASH: Cash and money market

#### Instruments
**Purpose**: Individual financial instruments
```sql
- instrument_id: Primary key
- isin: International Securities ID (optional)
- ticker_symbol: Trading symbol
- instrument_name: Full name
- group_id: Asset classification
- currency: Trading currency
- country_code: Country of origin
- exchange_code: Trading exchange
- sector: Industry sector
- include_in_portfolio: Portfolio inclusion flag
- is_active: Instrument status
```

#### Portfolios
**Purpose**: Sub-portfolio definitions
```sql
- portfolio_id: Primary key
- portfolio_code: Short identifier
- portfolio_name: Display name
- portfolio_description: Detailed description
- is_default: Default portfolio flag
- include_in_total: Include in total calculations
- sort_order: Display ordering
```

#### PortfolioInstruments
**Purpose**: Many-to-many portfolio assignments
```sql
- portfolio_id: Portfolio reference
- instrument_id: Instrument reference
- assigned_date: Assignment date
- target_allocation_percent: Target weight
```

### Transaction Management Tables

#### Accounts
**Purpose**: Financial institution accounts
```sql
- account_id: Primary key
- account_number: Account identifier
- account_name: Display name
- institution_name: Financial institution
- institution_bic: Bank identifier code
- account_type: Account category
- currency: Account base currency
- is_active: Account status
- include_in_portfolio: Portfolio inclusion
- opening_date: Account opening date
- closing_date: Account closure date
```

**Account Types**:
- BANK: Regular bank account
- CUSTODY: Securities custody account
- CRYPTO: Cryptocurrency wallet
- PENSION: Retirement account
- CASH: Cash management account

#### TransactionTypes
**Purpose**: Transaction categorization
```sql
- transaction_type_id: Primary key
- type_code: Short identifier
- type_name: Display name
- type_description: Detailed description
- affects_position: Changes security holdings
- affects_cash: Changes cash balance
- is_income: Income transaction flag
- sort_order: Display ordering
```

#### Transactions
**Purpose**: Core financial transaction records
```sql
- transaction_id: Primary key
- account_id: Source account
- instrument_id: Affected instrument (nullable for cash)
- transaction_type_id: Transaction category
- portfolio_id: Portfolio assignment (optional)
- transaction_date: Transaction date
- value_date: Settlement date
- booking_date: Accounting date
- quantity: Number of units
- price: Price per unit
- gross_amount: Gross transaction value
- fee: Transaction fees
- tax: Applicable taxes
- net_amount: Net cash impact
- transaction_currency: Transaction currency
- exchange_rate_to_chf: CHF conversion rate
- amount_chf: Amount in CHF
- import_source: Data source
- external_reference: Bank reference
- description: Transaction description
```

#### ImportSessions
**Purpose**: File import tracking and duplicate detection
```sql
- import_session_id: Primary key
- session_name: Import session name
- file_name: Source file name
- file_path: File location
- file_type: File format (CSV/XLSX/PDF)
- file_size: File size in bytes
- file_hash: SHA-256 hash used for duplicate detection (not unique)
- institution_id: Source institution
- import_status: Processing status
- total_rows: Total records processed
- successful_rows: Successfully imported
- failed_rows: Import failures
- error_log: Error details
```

#### PositionReports
**Purpose**: Stores uploaded position snapshots
```sql
- position_id: Primary key
- import_session_id: Related import session
- account_id: Account containing the position
- instrument_id: Instrument identifier
- quantity: Units held
- purchase_price: Original price paid per unit
- current_price: Current market price per unit
- report_date: Statement's report date
- uploaded_at: Timestamp when imported
```

## Relationships & Constraints

### Primary Relationships

```
Configuration ←→ System Settings
Currencies ←→ ExchangeRates (1:N)
InstrumentGroups ←→ Instruments (1:N)
Portfolios ←→ PortfolioInstruments ←→ Instruments (N:M)
Accounts ←→ Transactions (1:N)
Instruments ←→ Transactions (1:N)
TransactionTypes ←→ Transactions (1:N)
```

### Key Constraints

#### Foreign Key Constraints
- All references maintain referential integrity
- Cascade deletes where appropriate
- Null handling for optional relationships

#### Check Constraints
- Exchange rates must be positive
- Transaction dates must be valid
- Account types restricted to enum values
- Import status restricted to valid states

#### Unique Constraints
- Currency codes are unique
- ISIN codes are unique per instrument
- Portfolio codes are unique
- Account numbers are unique
- Import file hashes prevent duplicates

### Data Validation

#### Automatic Validations
- Currency code validation via foreign keys
- Transaction type validation
- Date format validation
- Numeric range validation

#### Business Rule Validations
- CHF exchange rate always equals 1.0
- Transaction amounts must balance
- Portfolio inclusion flags are respected
- As-of-date filtering in calculations

## Views & Calculations

### Positions View
**Purpose**: Real-time portfolio positions
**Key Features**:
- Respects "as of date" configuration
- Applies inclusion/exclusion flags
- Calculates average cost basis
- Provides comprehensive position metrics
- Groups by portfolio and account

**Calculations**:
- Position quantity = BUY - SELL transactions
- Average cost = Total invested ÷ Total shares bought
- Total invested = Sum of purchase amounts (CHF)
- Dividends received = Sum of dividend payments
- Transaction count = Number of transactions per holding

### PortfolioSummary View
**Purpose**: Aggregated portfolio performance
**Key Features**:
- Groups by portfolio and instrument group
- Calculates unrealized returns
- Provides dividend yield analysis
- Counts instruments and transactions

**Calculations**:
- Market value = Quantity × Average cost basis
- Unrealized return % = (Market value - Invested + Sold) ÷ Invested × 100
- Dividend yield % = Dividends ÷ Invested × 100

### AccountSummary View
**Purpose**: Account-level financial summary
**Key Features**:
- Cash flow analysis per account
- Transaction counting and dating
- Multi-currency handling with CHF conversion

### InstrumentPerformance View
**Purpose**: Individual instrument analysis
**Key Features**:
- Per-instrument position and performance
- Cost basis calculation
- Transaction history summary
- Income tracking (dividends/interest)

### LatestExchangeRates View
**Purpose**: Current FX rates for all currencies
**Key Features**:
- Most recent rate per currency
- Fallback to 1.0 for missing rates
- Rate source identification

### DataIntegrityCheck View
**Purpose**: Data quality monitoring
**Key Features**:
- Missing FX rate detection
- Unassigned instrument identification
- Negative position alerts
- Missing CHF amount warnings

## Implementation Guidelines

### Database Creation Process

1. **Initial Setup**
   ```bash
   sqlite3 dragonshield.db < create_schema.sql
   ```

2. **Configuration**
   ```sql
   UPDATE Configuration SET value = 'CHF' WHERE key = 'base_currency';
   UPDATE Configuration SET value = CURRENT_DATE WHERE key = 'as_of_date';
   ```

3. **Reference Data Loading**
   - Load currency definitions
   - Insert standard instrument groups
   - Create default portfolios
   - Set up standard transaction types

4. **FX Rate Initialization**
   ```sql
   INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source)
   VALUES ('CHF', CURRENT_DATE, 1.0, 'system');
   ```

### Data Migration Strategy

Since this is a fresh schema implementation:

1. **Data Export** (if migrating)
   - Export existing transaction data
   - Export instrument definitions
   - Export account information

2. **Data Transformation**
   - Map to new schema structure
   - Add required fields with defaults
   - Validate data consistency

3. **Data Import**
   - Load instruments and portfolios
   - Create accounts
   - Import transactions with automatic CHF conversion

### Performance Optimization

#### Index Strategy
```sql
-- High-frequency query indexes
CREATE INDEX idx_transactions_date ON Transactions(transaction_date);
CREATE INDEX idx_transactions_account ON Transactions(account_id);
CREATE INDEX idx_exchange_rates_latest ON ExchangeRates(currency_code, is_latest);

-- Composite indexes for complex queries
CREATE INDEX idx_transactions_portfolio_date ON Transactions(portfolio_id, transaction_date);
CREATE INDEX idx_instruments_group_active ON Instruments(group_id, is_active);
```

#### Query Optimization
- Use parameterized queries
- Leverage views for complex calculations
- Implement pagination for large result sets
- Cache frequently accessed configuration values

### Security Considerations

#### Database Security
- Enable SQLite encryption at rest
- Use WAL mode for concurrent access
- Implement backup encryption
- Secure file permissions

#### Data Privacy
- No external data transmission (privacy-first)
- Local-only storage
- Optional encrypted cloud backup
- User-controlled data export

## Usage Examples

### Basic Operations

#### Adding a New Currency
```sql
INSERT INTO Currencies (currency_code, currency_name, currency_symbol, api_supported)
VALUES ('KRW', 'Korean Won', '₩', TRUE);

INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source)
VALUES ('KRW', CURRENT_DATE, 0.00067, 'manual');
```

#### Creating a New Portfolio
```sql
INSERT INTO Portfolios (portfolio_code, portfolio_name, portfolio_description, sort_order)
VALUES ('TECH', 'Technology Portfolio', 'Technology sector investments', 6);

-- Assign technology stocks to the portfolio
INSERT INTO PortfolioInstruments (portfolio_id, instrument_id)
SELECT 6, instrument_id 
FROM Instruments 
WHERE sector = 'Technology';
```

#### Recording a Transaction
```sql
INSERT INTO Transactions (
    account_id, instrument_id, transaction_type_id, portfolio_id,
    transaction_date, quantity, price, net_amount, transaction_currency,
    description
) VALUES (
    1, 5, 1, 1,
    '2025-05-24', 10, 189.50, -1895.00, 'USD',
    'Buy 10 Apple shares'
);
```

### Advanced Queries

#### Portfolio Performance Analysis
```sql
SELECT 
    portfolio_name,
    instrument_group,
    instrument_count,
    total_invested_chf,
    current_market_value_chf,
    unrealized_return_percent,
    dividend_yield_percent
FROM PortfolioSummary
WHERE portfolio_name = 'Main Portfolio'
ORDER BY current_market_value_chf DESC;
```

#### FX Rate Management
```sql
-- Get currencies needing rate updates
SELECT c.currency_code, c.currency_name
FROM Currencies c
LEFT JOIN ExchangeRates er ON c.currency_code = er.currency_code 
    AND er.rate_date = CURRENT_DATE
WHERE c.api_supported = TRUE 
  AND er.rate_id IS NULL;

-- Update FX rate
INSERT OR REPLACE INTO ExchangeRates 
(currency_code, rate_date, rate_to_chf, rate_source, api_provider)
VALUES ('EUR', CURRENT_DATE, 0.9150, 'api', 'exchangerate-api');
```

#### Data Quality Checks
```sql
-- Check for data integrity issues
SELECT issue_type, issue_description, occurrence_count
FROM DataIntegrityCheck
WHERE occurrence_count > 0;

-- Verify portfolio totals
SELECT 
    portfolio_name,
    SUM(current_market_value_chf) as total_value,
    COUNT(DISTINCT instrument_id) as unique_instruments
FROM PortfolioSummary
GROUP BY portfolio_name;
```

### Configuration Management

#### Updating System Settings
```sql
-- Change base currency (careful - affects all calculations)
UPDATE Configuration SET value = 'EUR' WHERE key = 'base_currency';

-- Update as-of date for historical analysis
UPDATE Configuration SET value = '2024-12-31' WHERE key = 'as_of_date';

-- Enable automatic FX updates
UPDATE Configuration SET value = 'true' WHERE key = 'auto_fx_update';
```

#### Retrieving Configuration
```sql
-- Get current configuration
SELECT key, value, data_type, description
FROM Configuration
ORDER BY key;

-- Get specific setting
SELECT value FROM Configuration WHERE key = 'as_of_date';
```

This comprehensive schema provides a robust foundation for the Dragon Shield personal asset management platform, balancing functionality, performance, and data integrity while maintaining the privacy-first design principles.