/**
 * Supabase Edge Function: bachs-webhook
 * 
 * Receives Bachs webhook POST events (collection.succeeded, payout.paid, payout.failed)
 * and updates the corresponding Supabase records in real time.
 * 
 * Deploy: supabase functions deploy bachs-webhook
 * Bachs webhook URL: https://<project-ref>.supabase.co/functions/v1/bachs-webhook
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const BACHS_WEBHOOK_SECRET = Deno.env.get('BACHS_WEBHOOK_SECRET') ?? '';

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return new Response('Invalid JSON body', { status: 400 });
  }

  const eventType = payload?.type as string | undefined;
  const data = (payload?.data ?? {}) as Record<string, unknown>;

  if (!eventType) {
    return new Response('Missing event type', { status: 400 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  try {
    if (eventType === 'collection.succeeded') {
      // Mark order as paid and store payment reference
      const checkoutId = (data.checkout_id ?? data.id) as string;
      const amount = data.amount as string;
      const currency = data.currency as string;

      await supabase
        .from('orders')
        .update({
          status: 'paid',
          paid_at: new Date().toISOString(),
          bachs_checkout_id: checkoutId,
          amount_paid: amount,
          currency,
        })
        .eq('bachs_checkout_id', checkoutId);

      console.log(`[bachs-webhook] Order fulfilled: ${checkoutId} — ${currency} ${amount}`);

    } else if (eventType === 'payout.paid') {
      // Mark payout as completed
      const payoutId = data.id as string;

      await supabase
        .from('payouts')
        .update({ status: 'completed', settled_at: new Date().toISOString() })
        .eq('bachs_payout_id', payoutId);

      console.log(`[bachs-webhook] Payout settled: ${payoutId}`);

    } else if (eventType === 'payout.failed') {
      // Mark payout as failed with recorded reason
      const payoutId = data.id as string;
      const failReason = (data.reason as string) ?? 'payout_rejected';

      await supabase
        .from('payouts')
        .update({ status: 'failed', fail_reason: failReason })
        .eq('bachs_payout_id', payoutId);

      console.log(`[bachs-webhook] Payout failed: ${payoutId} — ${failReason}`);

    } else {
      console.log(`[bachs-webhook] Unhandled event type: ${eventType}`);
    }

    return new Response(JSON.stringify({ received: true, event: eventType }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });

  } catch (err) {
    console.error(`[bachs-webhook] Error processing ${eventType}:`, err);
    return new Response(
      JSON.stringify({ error: 'Internal error', event: eventType }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
});
