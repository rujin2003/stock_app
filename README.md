# Stock Trading App

A Flutter application for tracking real-time stock, forex, indices, and cryptocurrency data.

## Features

- Real-time market data via WebSockets
- OHLC (Open, High, Low, Close) values with price change calculations
- Watchlist functionality
- Authentication with Supabase
- Responsive UI with mobile and desktop layouts
- Bottom tabs for mobile and top tabs for desktop

## Setup

1. Clone the repository
2. Copy `config.env.example` to `config.env` and fill in your credentials:
   ```
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ITICK_API_KEY=your_itick_api_key
   ```
3. Run `flutter pub get` to install dependencies
4. Run the app with `flutter run`

## UI Layout

The app features a responsive UI that adapts to different screen sizes:

### Mobile Layout
- Bottom navigation tabs for Watchlist, Charts, Trade, and History
- Compact display optimized for smaller screens
- MetaTrader-inspired design

### Desktop Layout
- Top navigation tabs for Watchlist, Charts, Trade, and History
- Expanded display taking advantage of larger screen real estate
- Trading platform-like experience

## WebSocket API

The app connects to the following WebSocket endpoints:

- Stocks: `wss://api.itick.org/sws`
- Forex: `wss://api.itick.org/fws`
- Indices: `wss://api.itick.org/iws`
- Crypto: `wss://api.itick.org/cws`

### Authentication

After connecting to a WebSocket, the app sends an authentication message:

```json
{
  "ac": "auth",
  "params": "ITICK_API_KEY"
}
```

### Subscribing to Symbols

To subscribe to a symbol:

```json
{
  "ac": "subscribe",
  "params": "SYMBOL_CODE",
  "types": "quote"
}
```

### Market Data Format

The WebSocket sends market data in the following format:

```json
{
  "code": 1,
  "data": {
    "s": "ETH_USDT",
    "ld": 3034,
    "o": 3000,
    "h": 3050,
    "l": 2980,
    "t": 1731690011321,
    "v": 0.6186,
    "tu": 1876.832564,
    "ts": 0,
    "type": "quote"
  }
}
```

Where:
- `s`: Symbol
- `ld`: Last price (Close)
- `o`: Open price
- `h`: High price
- `l`: Low price
- `t`: Timestamp
- `v`: Volume
- `type`: Data type

## OHLC Display

The app displays OHLC (Open, High, Low, Close) values for each symbol in the watchlist:

- Open: The opening price for the current period
- High: The highest price reached during the current period
- Low: The lowest price reached during the current period
- Close: The last price (current price)

Price changes are calculated as:
- Change Amount = Last Price - Open Price
- Change Percent = (Last Price - Open Price) / Open Price * 100
