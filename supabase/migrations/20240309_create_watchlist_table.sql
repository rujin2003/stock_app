-- Create watchlist table
CREATE TABLE IF NOT EXISTS watchlist (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  exchange TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  UNIQUE(code, user_id)
);

-- Enable RLS
ALTER TABLE watchlist ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view their own watchlist"
  ON watchlist
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert into their own watchlist"
  ON watchlist
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own watchlist"
  ON watchlist
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete from their own watchlist"
  ON watchlist
  FOR DELETE
  USING (auth.uid() = user_id); 