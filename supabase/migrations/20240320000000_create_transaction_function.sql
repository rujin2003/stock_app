-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS public.create_transaction;

-- Create the create_transaction function for trade-related transactions only
CREATE OR REPLACE FUNCTION public.create_transaction(
    transaction_id uuid,
    user_id_param uuid,
    transaction_type text,
    amount numeric,
    description text,
    related_trade_id bigint,
    created_at timestamp with time zone
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_balance numeric;
BEGIN
    -- Get current balance
    SELECT balance INTO v_new_balance
    FROM public.account_balances
    WHERE user_id = user_id_param;

    -- Calculate new balance based on transaction type
    IF transaction_type IN ('profit') THEN
        v_new_balance := v_new_balance + amount;
    ELSIF transaction_type IN ('loss', 'fee') THEN
        v_new_balance := v_new_balance - amount;
    END IF;

    -- Insert the transaction
    INSERT INTO public.transactions (
        id,
        user_id,
        type,
        amount,
        description,
        created_at,
        related_trade_id
    ) VALUES (
        transaction_id,
        user_id_param,
        transaction_type,
        amount,
        description,
        created_at,
        related_trade_id
    );

    -- Update account balance
    UPDATE public.account_balances
    SET 
        balance = v_new_balance,
        updated_at = NOW()
    WHERE user_id = user_id_param;

    -- Update appusers table with the new balance
    UPDATE public.appusers
    SET account_balance = v_new_balance
    WHERE user_id = user_id_param;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.create_transaction TO authenticated; 