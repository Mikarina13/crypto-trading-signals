/*
  # Seed Data for Trading Signals

  This file contains initial test data for the trading signals table.
  It includes a variety of signals with different patterns and states
  to help with testing and development.
*/

-- Insert test trading signals
INSERT INTO trading_signals (
  type,
  pattern,
  price,
  stop_loss,
  take_profit,
  timestamp,
  description,
  volume_ratio,
  rsi,
  macd_value,
  macd_signal,
  macd_histogram,
  result,
  profit_loss,
  user_id
) VALUES
-- Successful BULL_FLAG signal
(
  'ENTRY',
  'BULL_FLAG',
  45000.00,
  44000.00,
  47000.00,
  NOW() - INTERVAL '2 days',
  'Strong bullish continuation pattern with increasing volume',
  155.5,
  65.4,
  100.5,
  80.2,
  20.3,
  'SUCCESS',
  4.5,
  auth.uid()
),
-- Failed ASCENDING_TRIANGLE signal
(
  'ENTRY',
  'ASCENDING_TRIANGLE',
  42000.00,
  41500.00,
  43500.00,
  NOW() - INTERVAL '1 day',
  'Ascending triangle breakout with volume confirmation',
  142.8,
  58.2,
  50.4,
  45.6,
  4.8,
  'FAILURE',
  -1.2,
  auth.uid()
),
-- Pending BULL_FLAG signal
(
  'ENTRY',
  'BULL_FLAG',
  46500.00,
  45800.00,
  48000.00,
  NOW() - INTERVAL '2 hours',
  'Bull flag forming after strong upward movement',
  168.2,
  72.1,
  120.8,
  90.5,
  30.3,
  'PENDING',
  NULL,
  auth.uid()
),
-- Recent ASCENDING_TRIANGLE signal
(
  'ENTRY',
  'ASCENDING_TRIANGLE',
  47200.00,
  46800.00,
  48500.00,
  NOW() - INTERVAL '30 minutes',
  'Clear ascending triangle pattern with strong support',
  145.6,
  62.8,
  85.4,
  70.2,
  15.2,
  'PENDING',
  NULL,
  auth.uid()
);
