-- ==============================================================================
-- TEMENIN AJAA - ATOMIC BALANCE MUTATION FUNCTIONS (POSTGRESQL / SUPABASE)
-- Eksekusi di Supabase Dashboard -> SQL Editor -> Run
-- ==============================================================================

-- 1. Atomic Balance Increment (Deposit / Trip Payout)
CREATE OR REPLACE FUNCTION public.increment_user_balance(
    p_user_id UUID,
    p_amount NUMERIC
) RETURNS NUMERIC AS $$
DECLARE
    v_new_balance NUMERIC;
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be greater than zero';
    END IF;

    UPDATE public.users
    SET balance = COALESCE(balance, 0) + p_amount,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_user_id
    RETURNING balance INTO v_new_balance;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    RETURN v_new_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Atomic Balance Deduction (Payment / Withdrawal)
CREATE OR REPLACE FUNCTION public.deduct_user_balance(
    p_user_id UUID,
    p_amount NUMERIC
) RETURNS NUMERIC AS $$
DECLARE
    v_new_balance NUMERIC;
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be greater than zero';
    END IF;

    UPDATE public.users
    SET balance = balance - p_amount,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_user_id AND balance >= p_amount
    RETURNING balance INTO v_new_balance;

    IF NOT FOUND THEN
        -- Check whether user exists or balance insufficient
        IF EXISTS (SELECT 1 FROM public.users WHERE id = p_user_id) THEN
            RAISE EXCEPTION 'INSUFFICIENT_BALANCE';
        ELSE
            RAISE EXCEPTION 'USER_NOT_FOUND';
        END IF;
    END IF;

    RETURN v_new_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Atomic Points Deduction (Redeem Rewards)
CREATE OR REPLACE FUNCTION public.deduct_user_points(
    p_user_id UUID,
    p_points INT
) RETURNS INT AS $$
DECLARE
    v_new_points INT;
BEGIN
    IF p_points <= 0 THEN
        RAISE EXCEPTION 'Points must be greater than zero';
    END IF;

    UPDATE public.users
    SET points = points - p_points,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_user_id AND points >= p_points
    RETURNING points INTO v_new_points;

    IF NOT FOUND THEN
        IF EXISTS (SELECT 1 FROM public.users WHERE id = p_user_id) THEN
            RAISE EXCEPTION 'INSUFFICIENT_POINTS';
        ELSE
            RAISE EXCEPTION 'USER_NOT_FOUND';
        END IF;
    END IF;

    RETURN v_new_points;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Atomic Points Increment (Earn Rewards)
CREATE OR REPLACE FUNCTION public.increment_user_points(
    p_user_id UUID,
    p_points INT
) RETURNS INT AS $$
DECLARE
    v_new_points INT;
BEGIN
    IF p_points <= 0 THEN
        RAISE EXCEPTION 'Points must be greater than zero';
    END IF;

    UPDATE public.users
    SET points = COALESCE(points, 0) + p_points,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_user_id
    RETURNING points INTO v_new_points;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    RETURN v_new_points;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

