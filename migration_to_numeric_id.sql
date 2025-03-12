-- Create sequences for generating 10-digit IDs
CREATE SEQUENCE trade_id_seq START WITH 1000000000;
CREATE SEQUENCE transaction_id_seq START WITH 2000000000;

-- Add a new numeric_id column to trades table
ALTER TABLE trades ADD COLUMN numeric_id BIGINT DEFAULT nextval('trade_id_seq');

-- Add a new numeric_id column to transactions table
ALTER TABLE transactions ADD COLUMN numeric_id BIGINT DEFAULT nextval('transaction_id_seq');

-- Add a new related_trade_numeric_id column to transactions table
ALTER TABLE transactions ADD COLUMN related_trade_numeric_id BIGINT;

-- Update the related_trade_numeric_id in transactions to match the corresponding numeric_id in trades
UPDATE transactions t
SET related_trade_numeric_id = tr.numeric_id
FROM trades tr
WHERE t.related_trade_id = tr.id;

-- Drop the foreign key constraint from transactions to trades
ALTER TABLE transactions DROP CONSTRAINT transactions_related_trade_id_fkey;

-- Make numeric_id the primary key in trades
ALTER TABLE trades DROP CONSTRAINT trades_pkey;
ALTER TABLE trades ADD PRIMARY KEY (numeric_id);

-- Make numeric_id the primary key in transactions
ALTER TABLE transactions DROP CONSTRAINT transactions_pkey;
ALTER TABLE transactions ADD PRIMARY KEY (numeric_id);

-- Add a foreign key from transactions to trades using the new numeric ID
ALTER TABLE transactions ADD CONSTRAINT transactions_related_trade_numeric_id_fkey
FOREIGN KEY (related_trade_numeric_id) REFERENCES trades(numeric_id);

-- Drop the old UUID columns
ALTER TABLE trades DROP COLUMN id;
ALTER TABLE transactions DROP COLUMN id;
ALTER TABLE transactions DROP COLUMN related_trade_id;

-- Rename the new columns to the original names
ALTER TABLE trades RENAME COLUMN numeric_id TO id;
ALTER TABLE transactions RENAME COLUMN numeric_id TO id;
ALTER TABLE transactions RENAME COLUMN related_trade_numeric_id TO related_trade_id;
