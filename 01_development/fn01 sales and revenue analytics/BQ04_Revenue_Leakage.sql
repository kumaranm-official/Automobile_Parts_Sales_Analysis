SELECT * FROM sales_orders so;

/*
 * cancelled_pct = (cancelled / (booked + cancelled)) * 100
 * discount_pct = (discount amount / gross revenue) * 100
 * */

WITH calc_table AS (
	SELECT 
		date_trunc('month', so.order_date) ::date AS month_start,
		sum(so.total_amount) FILTER (WHERE so.order_status = 'Delivered') booked_revenue,
		sum(so.total_amount) FILTER (WHERE so.order_status = 'Cancelled') cancelled_revenue,
		sum(so.discount_amount) FILTER (WHERE so.order_status = 'Delivered') discounted_amount,
		sum(so.subtotal) FILTER (WHERE so.order_status = 'Delivered') gross_amount
	FROM sales_orders so
		GROUP BY 
			month_start  
)
SELECT 
	month_start,
	booked_revenue,
	cancelled_revenue,
	round((cancelled_revenue / (booked_revenue + cancelled_revenue)) * 100, 2) cancelled_pct,
	discounted_amount,
	round((discounted_amount / gross_amount) * 100, 2) discounted_pct
FROM calc_table 
	ORDER BY month_start;