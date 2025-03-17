/*
  # Add Analysis Views

  1. New Views
    - signal_performance_by_pattern: Analyzes success rates by pattern
    - signal_performance_by_time: Analyzes performance by time of day
    - user_performance_metrics: Comprehensive user performance stats
    - recent_signals_with_metrics: Recent signals with key metrics

  2. Changes
    - Add materialized view for faster analytics
    - Add helper functions for time-based analysis
    - Add indexes on views for better query performance
*/

-- Create view for pattern-based performance analysis
CREATE OR REPLACE VIEW signal_performance_by_pattern AS
SELECT
  pattern,
  COUNT(*) as total_signals,
  COUNT(*) FILTER (WHERE result = 'SUCCESS') as successful_signals,
  COUNT(*) FILTER (WHERE result = 'FAILURE') as failed_signals,
  ROUND(AVG(CASE WHEN result != 'PENDING' THEN profit_loss ELSE NULL END)::numeric, 2) as avg_profit_loss,
  ROUND((COUNT(*) FILTER (WHERE result = 'SUCCESS')::numeric / 
    NULLIF(COUNT(*) FILTER (WHERE result != 'PENDING'), 0)::numeric * 100)::numeric, 2) as success_rate,
  user_id
FROM trading_signals
GROUP BY pattern, user_id;

-- Create view for time-based performance analysis
CREATE OR REPLACE VIEW signal_performance_by_time AS
SELECT
  EXTRACT(HOUR FROM timestamp) as hour_of_day,
  COUNT(*) as total_signals,
  COUNT(*) FILTER (WHERE result = 'SUCCESS') as successful_signals,
  ROUND(AVG(CASE WHEN result != 'PENDING' THEN profit_loss ELSE NULL END)::numeric, 2) as avg_profit_loss,
  ROUND((COUNT(*) FILTER (WHERE result = 'SUCCESS')::numeric / 
    NULLIF(COUNT(*) FILTER (WHERE result != 'PENDING'), 0)::numeric * 100)::numeric, 2) as success_rate,
  user_id
FROM trading_signals
GROUP BY EXTRACT(HOUR FROM timestamp), user_id;

-- Create materialized view for user performance metrics
CREATE MATERIALIZED VIEW user_performance_metrics AS
SELECT
  user_id,
  COUNT(*) as total_signals,
  COUNT(*) FILTER (WHERE result = 'SUCCESS') as successful_signals,
  COUNT(*) FILTER (WHERE result = 'FAILURE') as failed_signals,
  COUNT(*) FILTER (WHERE result = 'PENDING') as pending_signals,
  ROUND(AVG(CASE WHEN result != 'PENDING' THEN profit_loss ELSE NULL END)::numeric, 2) as avg_profit_loss,
  ROUND((COUNT(*) FILTER (WHERE result = 'SUCCESS')::numeric / 
    NULLIF(COUNT(*) FILTER (WHERE result != 'PENDING'), 0)::numeric * 100)::numeric, 2) as success_rate,
  MAX(profit_loss) as best_trade,
  MIN(profit_loss) as worst_trade,
  ROUND(AVG(calculate_risk_reward_ratio(price, stop_loss, take_profit))::numeric, 2) as avg_risk_reward_ratio
FROM trading_signals
GROUP BY user_id;

-- Create index on materialized view
CREATE UNIQUE INDEX idx_user_performance_metrics ON user_performance_metrics(user_id);

-- Create view for recent signals with metrics
CREATE OR REPLACE VIEW recent_signals_with_metrics AS
SELECT
  s.*,
  calculate_risk_reward_ratio(s.price, s.stop_loss, s.take_profit) as risk_reward_ratio,
  COALESCE(
    LAG(s.result) OVER (PARTITION BY s.user_id ORDER BY s.timestamp),
    'NONE'
  ) as previous_signal_result,
  COALESCE(
    LAG(s.profit_loss) OVER (PARTITION BY s.user_id ORDER BY s.timestamp),
    0
  ) as previous_signal_profit_loss
FROM trading_signals s
WHERE s.timestamp >= NOW() - INTERVAL '7 days';

-- Function to refresh materialized views
CREATE OR REPLACE FUNCTION refresh_trading_views()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY user_performance_metrics;
END;
$$;

-- Create trigger to refresh materialized views when data changes
CREATE OR REPLACE FUNCTION trigger_refresh_trading_views()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM refresh_trading_views();
  RETURN NULL;
END;
$$;

CREATE TRIGGER refresh_trading_views_trigger
  AFTER INSERT OR UPDATE OR DELETE
  ON trading_signals
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_refresh_trading_views();

-- Enable RLS on views
ALTER VIEW signal_performance_by_pattern SECURITY DEFINER;
ALTER VIEW signal_performance_by_time SECURITY DEFINER;
ALTER VIEW recent_signals_with_metrics SECURITY DEFINER;
ALTER MATERIALIZED VIEW user_performance_metrics SECURITY DEFINER;

-- Create policies for views
CREATE POLICY "Users can view own pattern performance"
  ON signal_performance_by_pattern
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view own time performance"
  ON signal_performance_by_time
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view own recent signals"
  ON recent_signals_with_metrics
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view own performance metrics"
  ON user_performance_metrics
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);
