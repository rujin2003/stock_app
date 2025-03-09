// supabase/functions/fetch_market_prices/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ITICK_API_KEY = Deno.env.get("ITICK_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

serve(async (req) => {
  // Create a Supabase client with the service role key
  const supabase = createClient(
    SUPABASE_URL!,
    SUPABASE_SERVICE_ROLE_KEY!,
  );

  try {
    // Get all unique symbols from pending orders
    const { data: pendingOrders, error: ordersError } = await supabase
      .from("transactions")
      .select("symbol, order_type")
      .eq("status", "pending")
      .order("symbol");

    if (ordersError) throw ordersError;

    // Get unique symbols
    const symbols = [...new Set(pendingOrders.map((order) => order.symbol))];

    // Process each symbol
    const priceUpdates = [];

    for (const symbol of symbols) {
      // Determine market type based on symbol (simplified approach)
      let marketType = "stock";
      let region = "us";

      if (symbol.includes("USD") || symbol.endsWith("USDT")) {
        marketType = "crypto";
        region = "ba";
      } else if (symbol.includes("/")) {
        marketType = "forex";
        region = "gb";
      } else if (symbol.startsWith("^")) {
        marketType = "indices";
        region = "gb";
      }

      // Fetch current price from iTick API
      const endpoint = marketType === "stock" ? "stock" : marketType;
      const url =
        `https://api.itick.org/${endpoint}/quote?code=${symbol}&region=${region}`;

      try {
        const response = await fetch(url, {
          headers: {
            "token": ITICK_API_KEY!,
            "Content-Type": "application/json",
          },
        });

        if (response.ok) {
          const data = await response.json();
          if (data.code === 0 && data.data) {
            const price = data.data.ld || data.data.price || data.data.c;
            if (price) {
              // Update the price in the database
              const { error: updateError } = await supabase.rpc(
                "update_current_price",
                { p_symbol: symbol, p_price: price },
              );

              if (updateError) {
                console.error(
                  `Error updating price for ${symbol}: ${updateError.message}`,
                );
              } else {
                priceUpdates.push({ symbol, price, marketType });
              }
            }
          }
        }
      } catch (error) {
        console.error(`Error fetching price for ${symbol}: ${error.message}`);
      }
    }

    // Process pending orders
    let processResult = null;
    if (priceUpdates.length > 0) {
      const { data, error } = await supabase.rpc("process_pending_orders");
      if (error) {
        console.error(`Error processing orders: ${error.message}`);
      } else {
        processResult = data;
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        prices_updated: priceUpdates,
        orders_processed: processResult,
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
