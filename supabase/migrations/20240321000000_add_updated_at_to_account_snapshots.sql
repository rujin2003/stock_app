-- Add updated_at column to account_snapshots table
ALTER TABLE account_snapshots 
ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Update existing records to have updated_at equal to snapshot_date
UPDATE account_snapshots 
SET updated_at = snapshot_date::timestamp with time zone;

-- Make updated_at column NOT NULL after setting default values
ALTER TABLE account_snapshots 
ALTER COLUMN updated_at SET NOT NULL; 