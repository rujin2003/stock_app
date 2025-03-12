-- Drop the existing stored procedure
DROP FUNCTION IF EXISTS create_transaction(
    transaction_id UUID,
    user_id_param UUID,
    transaction_type TEXT,
    amount NUMERIC,
    description TEXT,
    related_trade_id UUID,
    created_at TIMESTAMP WITH TIME ZONE
);

-- Create a new version that accepts numeric IDs
CREATE OR REPLACE FUNCTION create_transaction(
    transaction_id TEXT,
    user_id_param UUID,
    transaction_type TEXT,
    amount NUMERIC,
    description TEXT,
    related_trade_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) RETURNS JSONB AS $$
DECLARE
    v_balance NUMERIC;
    v_new_balance NUMERIC;
BEGIN
    -- Insert the transaction
    INSERT INTO transactions (
        id,
        user_id,
        type,
        amount,
        description,
        related_trade_id,
        created_at
    ) VALUES (
        transaction_id,
        user_id_param,
        transaction_type,
        amount,
        description,
        related_trade_id,
        created_at
    );

    -- Get current balance
    SELECT balance INTO v_balance
    FROM account_balances
    WHERE user_id = user_id_param;

    -- Calculate new balance based on transaction type
    IF transaction_type IN ('deposit', 'profit', 'credit') THEN
        v_new_balance := v_balance + amount;
    ELSE
        v_new_balance := v_balance - amount;
    END IF;

    -- Update account balance
    UPDATE account_balances
    SET 
        balance = v_new_balance,
        equity = v_new_balance, -- This is simplified, in reality equity would include open positions
        free_margin = v_new_balance - margin, -- Simplified
        updated_at = NOW()
    WHERE user_id = user_id_param;

    -- Return the transaction data
    RETURN (
        SELECT row_to_json(t)::jsonb
        FROM (
            SELECT * FROM transactions WHERE id = transaction_id
        ) t
    );
END;
$$ LANGUAGE plpgsql;
