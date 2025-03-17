/*
  # Add Trading Signal Triggers

  1. New Functions & Triggers
    - auto_update_signal_result: Updates signal result based on price targets
    - calculate_profit_loss: Calculates P&L when result changes
    - log_signal_updates: Maintains an audit trail of signal changes

  2. Changes
    - Add trigger to automatically update signal results
    - Add trigger to calculate profit/loss
    - Add trigger for audit logging
*/

-- Create audit table for signal updates
CREATE TABLE IF NOT EXISTS trading_signal_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  signal_id uuid REFERENCES trading_signals(id),
  user_id uuid REFERENCES auth.users(id),
  old_result text,
  new_result text,
  old_profit_loss numeric,
  new_profit_loss numeric,
  changed_at timestamptz DEFAULT now(),
  reason text
);

-- Enable RLS on audit table
ALTER TABLE trading_signal_logs ENABLE ROW LEVEL SECURITY;

-- Create policy for audit logs
CREATE POLICY "Users can read own signal logs"
  ON trading_signal_logs
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Function to update signal result based on current price
CREATE OR REPLACE FUNCTION auto_update_signal_result()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only process ENTRY signals that are PENDING
  IF NEW.type = 'ENTRY' AND NEW.result = 'PENDING' THEN
    -- Check if take profit was hit
    IF NEW.price >= NEW.take_profit THEN
      NEW.result := 'SUCCESS';
    -- Check if stop loss was hit
    ELSIF NEW.price <= NEW.stop_loss THEN
      NEW.result := 'FAILURE';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Function to calculate profit/loss when result changes
CREATE OR REPLACE FUNCTION calculate_profit_loss()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only calculate P&L when result changes from PENDING
  IF NEW.result != 'PENDING' AND OLD.result = 'PENDING' THEN
    IF NEW.result = 'SUCCESS' THEN
      -- Calculate profit percentage
      NEW.profit_loss := ((NEW.take_profit - NEW.price) / NEW.price) * 100;
    ELSIF NEW.result = 'FAILURE' THEN
      -- Calculate loss percentage
      NEW.profit_loss := ((NEW.stop_loss - NEW.price) / NEW.price) * 100;
    END IF;
  END IF;

  -- Log the change
  INSERT INTO trading_signal_logs (
    signal_id,
    user_id,
    old_result,
    new_result,
    old_profit_loss,
    new_profit_loss,
    reason
  ) VALUES (
    NEW.id,
    NEW.user_id,
    OLD.result,
    NEW.result,
    OLD.profit_loss,
    NEW.profit_loss,
    CASE 
      WHEN NEW.result = 'SUCCESS' THEN 'Take profit target reached'
      WHEN NEW.result = 'FAILURE' THEN 'Stop loss triggered'
      ELSE 'Manual update'
    END
  );
  
  RETURN NEW;
END;
$$;

-- Create triggers
CREATE TRIGGER trigger_auto_update_signal_result
  BEFORE UPDATE OF price
  ON trading_signals
  FOR EACH ROW
  EXECUTE FUNCTION auto_update_signal_result();

CREATE TRIGGER trigger_calculate_profit_loss
  BEFORE UPDATE OF result
  ON trading_signals
  FOR EACH ROW
  WHEN (OLD.result IS DISTINCT FROM NEW.result)
  EXECUTE FUNCTION calculate_profit_loss();

-- Create indexes for audit logs
CREATE INDEX IF NOT EXISTS idx_trading_signal_logs_signal_id ON trading_signal_logs(signal_id);
CREATE INDEX IF NOT EXISTS idx_trading_signal_logs_user_id ON trading_signal_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_trading_signal_logs_changed_at ON trading_signal_logs(changed_at);
