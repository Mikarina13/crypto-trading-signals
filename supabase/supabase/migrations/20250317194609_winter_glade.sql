/*
  # Add Trading Metrics Functions
  
  1. New Functions
    - calculate_win_rate: Calculates the win rate percentage for a user's signals
    - calculate_avg_profit: Calculates the average profit/loss percentage
    - calculate_risk_reward_ratio: Calculates the risk/reward ratio for a signal
    - get_user_statistics: Returns comprehensive trading statistics for a user

  2. Security
    - All functions are marked as SECURITY DEFINER to run with owner privileges
    - Access is controlled through RLS policies on the trading_signals table
*/

-- Calculate win rate for a user
CREATE OR REPLACE FUNCTION calculate_win_rate(user_id_param uuid)
RETURNS numeric
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  total_signals integer;
  winning_signals integer;
BEGIN
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE result = 'SUCCESS')
  INTO total_signals, winning_signals
  FROM trading_signals
  WHERE user_id = user_id_param
    AND result != 'PENDING';
    
  RETURN CASE 
    WHEN total_signals > 0 THEN 
      (winning_signals::numeric / total_signals::numeric) * 100
    ELSE 0 
  END;
END;
$$;

-- Calculate average profit/loss
CREATE OR REPLACE FUNCTION calculate_avg_profit(user_id_param uuid)
RETURNS numeric
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  avg_profit numeric;
BEGIN
  SELECT COALESCE(AVG(profit_loss), 0)
  INTO avg_profit
  FROM trading_signals
  WHERE user_id = user_id_param
    AND profit_loss IS NOT NULL;
    
  RETURN avg_profit;
END;
$$;

-- Calculate risk/reward ratio
CREATE OR REPLACE FUNCTION calculate_risk_reward_ratio(
  entry_price numeric,
  stop_loss numeric,
  take_profit numeric
)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN ABS(stop_loss - entry_price) = 0 THEN 0
    ELSE ABS(take_profit - entry_price) / ABS(stop_loss - entry_price)
  END;
$$;

-- Get comprehensive user statistics
CREATE OR REPLACE FUNCTION get_user_statistics(user_id_param uuid)
RETURNS TABLE (
  total_signals bigint,
  win_rate numeric,
  avg_profit numeric,
  best_pattern text,
  avg_risk_reward_ratio numeric,
  total_pnl numeric
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH pattern_stats AS (
    SELECT pattern,
      COUNT(*) as pattern_count,
      COUNT(*) FILTER (WHERE result = 'SUCCESS') as pattern_wins
    FROM trading_signals
    WHERE user_id = user_id_param
      AND result != 'PENDING'
    GROUP BY pattern
    ORDER BY pattern_wins DESC
    LIMIT 1
  )
  SELECT
    COUNT(*) as total_signals,
    calculate_win_rate(user_id_param) as win_rate,
    calculate_avg_profit(user_id_param) as avg_profit,
    (SELECT pattern FROM pattern_stats) as best_pattern,
    AVG(calculate_risk_reward_ratio(price, stop_loss, take_profit)) as avg_risk_reward_ratio,
    COALESCE(SUM(profit_loss), 0) as total_pnl
  FROM trading_signals
  WHERE user_id = user_id_param;
END;
$$;
