/*
  # Create Trading Signals Schema

  1. New Tables
    - `trading_signals`
      - `id` (uuid, primary key)
      - `type` (text) - ENTRY or EXIT
      - `pattern` (text) - ASCENDING_TRIANGLE or BULL_FLAG
      - `price` (numeric) - Entry/Exit price
      - `stop_loss` (numeric) - Stop loss level
      - `take_profit` (numeric) - Take profit target
      - `timestamp` (timestamptz) - Signal creation time
      - `description` (text) - Signal description
      - `volume_ratio` (numeric) - Volume compared to MA
      - `rsi` (numeric) - RSI value
      - `macd_value` (numeric) - MACD line value
      - `macd_signal` (numeric) - Signal line value
      - `macd_histogram` (numeric) - MACD histogram
      - `result` (text) - SUCCESS, FAILURE, or PENDING
      - `profit_loss` (numeric) - Realized profit/loss percentage
      - `user_id` (uuid) - Reference to auth.users
      - `created_at` (timestamptz) - Record creation timestamp

  2. Security
    - Enable RLS on trading_signals table
    - Add policies for:
      - Users can read their own signals
      - Users can create new signals
      - Users can update their own signals
*/

-- Create trading signals table
CREATE TABLE IF NOT EXISTS trading_signals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text NOT NULL CHECK (type IN ('ENTRY', 'EXIT')),
  pattern text NOT NULL CHECK (pattern IN ('ASCENDING_TRIANGLE', 'BULL_FLAG')),
  price numeric NOT NULL,
  stop_loss numeric NOT NULL,
  take_profit numeric NOT NULL,
  timestamp timestamptz NOT NULL DEFAULT now(),
  description text NOT NULL,
  volume_ratio numeric NOT NULL,
  rsi numeric NOT NULL,
  macd_value numeric NOT NULL DEFAULT 0,
  macd_signal numeric NOT NULL DEFAULT 0,
  macd_histogram numeric NOT NULL DEFAULT 0,
  result text NOT NULL DEFAULT 'PENDING' CHECK (result IN ('SUCCESS', 'FAILURE', 'PENDING')),
  profit_loss numeric,
  user_id uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE trading_signals ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Users can read own signals" ON trading_signals;
  DROP POLICY IF EXISTS "Users can create signals" ON trading_signals;
  DROP POLICY IF EXISTS "Users can update own signals" ON trading_signals;
END $$;

-- Create policies
CREATE POLICY "Users can read own signals"
  ON trading_signals
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create signals"
  ON trading_signals
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own signals"
  ON trading_signals
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_trading_signals_user_id ON trading_signals(user_id);
CREATE INDEX IF NOT EXISTS idx_trading_signals_timestamp ON trading_signals(timestamp);
CREATE INDEX IF NOT EXISTS idx_trading_signals_type ON trading_signals(type);
CREATE INDEX IF NOT EXISTS idx_trading_signals_pattern ON trading_signals(pattern);
