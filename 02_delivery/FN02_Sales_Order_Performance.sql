/* FR-2  Sales Channel & Order Funnel Performance                         

	Compare how Dealer, Retail and Online actually perform, and trace the order lifecycle from
	placement to delivery or cancellation.
*/



-- BQ01 - Order-status funnel — what share of orders reach Confirmed, Shipped, and Delivered, AND what share end in Cancelled?
WITH order_counts AS (
SELECT 
	count(*) total_orders, 
	count(order_id) FILTER(WHERE order_status IN ('Confirmed', 'Shipped', 'Delivered')) confirmed_orders, 
	count(order_id) FILTER(WHERE order_status IN ('Shipped', 'Delivered')) shipped_orders, 
	count(order_id) FILTER(WHERE order_status = 'Delivered') delivered_orders,
	count(order_id) FILTER(WHERE order_status = 'Cancelled') cancelled_orders
FROM sales_orders so
) 
SELECT
	metrics.total_orders ,
	metrics.order_count ,
	metrics.share_percentage 
FROM order_counts oc
CROSS JOIN LATERAL (
	VALUES
		('Total Orders', total_orders, 100.0),
		('Confirmed Orders', confirmed_orders, round(confirmed_orders * 100.0 / total_orders ,2)),
		('Shipped Orders', shipped_orders, round(shipped_orders * 100.0 / total_orders , 2)),
		('Delivered Orders', delivered_orders, round(delivered_orders * 100.0 / total_orders , 2)),
		('Cancelled Orders', cancelled_orders, round(cancelled_orders * 100.0 / total_orders , 2))
	)
	AS metrics (total_orders, order_count, share_percentage)	
;


-- BQ02 - Average order-to-ship and order-to-delivery cycle time by channel, from shipments.
WITH ship_cycle AS (
	SELECT 
		so.order_id,
		so.channel, 
		so.order_date ::date,
		s.ship_date ::date,
		s.ship_date - so.order_date ::date no_of_days_to_ship 
	FROM sales_orders so 
	LEFT JOIN shipments s 
	ON so.order_id = s.order_id
	WHERE s.ship_date IS NOT NULL 
	ORDER BY order_id 
), 
delivery_cycle AS (
	SELECT 
		so.order_id,
		so.channel, 
		so.order_date ::date,
		s.delivery_date ::date,
		s.delivery_date - so.order_date ::date no_of_days_to_deliver 
	FROM sales_orders so 
	LEFT JOIN shipments s 
	ON so.order_id = s.order_id
	WHERE s.delivery_date IS NOT NULL 
)
SELECT 
	sc.channel,
	round(avg(sc.no_of_days_to_ship), 2) avg_shipping_cycle,
	percentile_cont(0.5) WITHIN GROUP (ORDER BY sc.no_of_days_to_ship) median_shipping_cycle,
	round(avg(dc.no_of_days_to_deliver),2) avg_delivery_cycle,
	percentile_cont(0.5) WITHIN GROUP (ORDER BY dc.no_of_days_to_deliver) median_delivery_cycle
FROM ship_cycle sc 
LEFT JOIN delivery_cycle dc
ON sc.order_id = dc.order_id 
GROUP BY sc.channel ;


--BQ03 - Shipment status distribution (Delayed / Returned) and its relationship to channel AND region.
WITH shipping_table AS (
	SELECT 
		so.channel ,
		coalesce(d.region, rc.region) region,
		s.shipment_status 
	FROM sales_orders so
	LEFT JOIN dealers d 
		ON so.dealer_id = d.dealer_id 
	LEFT JOIN retail_customers rc 
		ON so.customer_id  = rc.customer_id
	LEFT JOIN shipments s
		ON s.order_id = so.order_id 
	WHERE so.order_status IN ('Delivered', 'Shipped')
) 
SELECT
	channel,
	region,
	count(*) qualified_orders,
	count(*) FILTER (WHERE shipment_status = 'Delayed') delayed_orders,
	round(count(*) FILTER (WHERE shipment_status = 'Delayed') * 100.0 / count(*) ,2) delayed_pct,
	count(*) FILTER (WHERE shipment_status = 'Returned') Returned_orders,
	round(count(*) FILTER (WHERE shipment_status = 'Returned') * 100.0 / count(*) ,2) Returned_pct
FROM shipping_table 
GROUP BY channel, region;

-- BQ04 - Channel-wise order conversion & cancellation rate.
SELECT 
	channel,
	count(*) FILTER (WHERE order_status IN ('Confirmed', 'Shipped', 'Delivered')) converted_orders,
	round(count(*) FILTER (WHERE order_status IN ('Confirmed', 'Shipped', 'Delivered')) * 100.0 / count(*),2) conversion_rate,
	count(*) FILTER (WHERE order_status = 'Cancelled') cancelled_orders,
	round(count(*) FILTER (WHERE order_status = 'Cancelled') * 100.0 / count(*),2) cancelled_rate
FROM sales_orders so 
GROUP BY channel;