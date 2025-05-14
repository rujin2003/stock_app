-- Drop the existing stored procedure
DROP FUNCTION IF EXISTS create_transaction(
    transaction_id TEXT,
    user_id_param UUID,
    transaction_type TEXT,
    amount NUMERIC,
    description TEXT,
    related_trade_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    payment_proof TEXT,
    user_current_balance NUMERIC,
    account_info_id UUID,
    admin_account_info_id UUID
);

-- Create a new version that accepts all fields
CREATE OR REPLACE FUNCTION create_transaction(
    transaction_id TEXT,
    user_id_param UUID,
    transaction_type TEXT,
    amount NUMERIC,
    description TEXT,
    related_trade_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    payment_proof TEXT DEFAULT NULL,
    user_current_balance NUMERIC DEFAULT NULL,
    account_info_id UUID DEFAULT NULL,
    admin_account_info_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_balance NUMERIC;
    v_new_balance NUMERIC;
    v_account_balance_id UUID;
BEGIN
    -- Get current balance
    SELECT balance, id INTO v_balance, v_account_balance_id
    FROM account_balances
    WHERE user_id = user_id_param;

    -- Calculate new balance based on transaction type
    IF transaction_type IN ('deposit', 'profit', 'credit') THEN
        v_new_balance := v_balance + amount;
    ELSE
        v_new_balance := v_balance - amount;
    END IF;

    -- Insert the transaction
    INSERT INTO account_transactions (
        id,
        user_id,
        transaction_type,
        amount,
        description,
        related_trade_id,
        created_at,
        payment_proof,
        user_current_balance,
        account_balance_id,
        account_info_id,
        admin_account_info_id,
        verified
    ) VALUES (
        transaction_id,
        user_id_param,
        transaction_type,
        amount,
        description,
        related_trade_id,
        created_at,
        payment_proof,
        user_current_balance,
        v_account_balance_id,
        account_info_id,
        admin_account_info_id,
        FALSE
    );

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
            SELECT * FROM account_transactions WHERE id = transaction_id
        ) t
    );
END;
$$ LANGUAGE plpgsql;
