-- 1. Who is the youngest author? Who is the oldest?
SELECT 
  authid
, first_name ||' '||last_name AS full_name
, birthday
FROM authors
WHERE birthday = (SELECT MAX(birthday) from authors) -- youngest
;
SELECT 
  authid
, first_name ||' '||last_name AS full_name
, birthday
FROM authors
WHERE birthday = (SELECT MIN (birthday) from authors) --oldest
;

-- 2. What is the youngest age at which an author has a book published? 
SELECT 
  b.bookid
, b.title
, a.authid
, a.first_name ||' '|| a.last_name AS full_name
, a.birthday
, e.publication_date
, DATEDIFF (day, a.birthday, e.publication_date) / 365 AS published_age -- CHOOSE 'DATE' instead OF 'YEAR' (/365)
FROM books b 
INNER JOIN edition e 
ON b.bookid = e.bookid 
INNER JOIN authors a 
ON b.authid = a.authid
WHERE e.publication_date IS NOT NULL
ORDER BY published_age ASC, a.authid -- YOUNGEST
LIMIT 1
;
 
-- 3. In which year are most books published? 
SELECT
  YEAR (e.publication_date) AS year_published
--, DATE_PART('year', e.publication_date) AS publish_year
, COUNT (DISTINCT e.bookid) AS total_books -- a book can be published multiple times in a year in different formats, so we use COUNT DISTINCT
FROM edition e
GROUP BY 1
ORDER BY 2 DESC 
LIMIT 1
;

-- 4. Who are the top ten authors that write the longest hours per day and have had their book(s) published before? 
-- How many pages did each of them write in total?
SELECT 
  a.authid
, a.first_name ||' '|| a.last_name AS full_name
, a.hrs_writing_per_day AS writing_hours
, b.title 
, b.bookid
, SUM (e.pages) AS total_pages
FROM authors a
LEFT JOIN books b  
  ON a.authid = b.authid 
INNER JOIN edition e  
  ON b.bookid = e.bookid 
GROUP BY 1,2,3,4,5
ORDER BY 3 DESC
LIMIT 10
;

-- 5.How would you calculate the sales price and add them in the sales tables, given that there is sometimes—but not always—a discount given at the time of sale?
-- sales = price * (1-discount) 
WITH sales AS 
(SELECT isbn, DISCOUNT
FROM SALES_Q1 q1
UNION ALL 
SELECT isbn, DISCOUNT 
FROM SALES_Q2 q2 
UNION ALL
SELECT isbn, DISCOUNT 
FROM SALES_Q3 q3 
UNION ALL 
SELECT isbn, DISCOUNT 
FROM SALES_Q4 q4) 
SELECT 
  sales.*
, e.price
, e.price * (1- COALESCE (sales.discount,0)) AS final_price --when discount IS NULL, then return zero
FROM sales
LEFT JOIN edition e 
ON e.isbn = sales.isbn
;

WITH total_sales AS (
    SELECT * FROM sales_q1
    UNION ALL
    SELECT * FROM sales_q2
    UNION ALL
    SELECT * FROM sales_q3
    UNION ALL 
    SELECT * FROM sales_q4
)
SELECT s.*
, e.price
, e.price * (1 - COALESCE(s.discount,0)) AS final_price --when discount IS NULL, then return zero
FROM total_sales s
LEFT JOIN edition e -- only keep the books that actually have made a sales, so total_sales is the LEFT table
    ON s.isbn = e.isbn 
 ;

-- 6. What books are the most popular?
-- by number of checkouts?
SELECT 
   b.bookid
 , b.title 
 , SUM (co.number_of_checkouts) AS total_checkouts
FROM books b 
INNER JOIN checkout co 
ON b.bookid = co.bookid
GROUP BY 1,2
ORDER BY 3 DESC
;
--by ratings?
SELECT 
   b.bookid
 , b.title 
 , AVG (r.rating) AS avergae_ratings 
FROM books b 
INNER JOIN rating r 
ON b.bookid = r.bookid
GROUP BY 1,2
ORDER BY 3 DESC
;
--by sales quantity?
WITH total_sales AS (
    SELECT * FROM sales_q1
    UNION ALL
    SELECT * FROM sales_q2
    UNION ALL
    SELECT * FROM sales_q3
    UNION ALL 
    SELECT * FROM sales_q4
)
SELECT 
  b.bookid
, b.title
, COUNT (total_sales.itemid) AS quantity 
FROM books b
FROM books b 
LEFT JOIN edition e 
ON b.bookid = e.bookid 
INNER JOIN total_sales 
ON e.isbn = total_sales.isbn
GROUP BY 1,2 
ORDER BY quantity DESC 
;
-- by sales amount ($)?
-- SUM final price
WITH total_sales AS (
    SELECT * FROM sales_q1
    UNION ALL
    SELECT * FROM sales_q2
    UNION ALL
    SELECT * FROM sales_q3
    UNION ALL 
    SELECT * FROM sales_q4
)
SELECT 
  b.bookid
, b.title
, e.price
, SUM(e.price * (1 - COALESCE(total_sales.discount,0))) AS total_sales -- to get the final correct price, then SUM them up as total_sales
FROM total_sales 
LEFT JOIN edition e 
    ON e.isbn = total_sales.isbn
LEFT JOIN books b
    ON e.bookid = b.bookid
GROUP BY 1, 2, 3
ORDER BY 4 DESC 
LIMIT 10
;

WITH total_sales AS (
    SELECT * FROM sales_q1
    UNION ALL
    SELECT * FROM sales_q2
    UNION ALL
    SELECT * FROM sales_q3
    UNION ALL 
    SELECT * FROM sales_q4
)
SELECT * 
FROM books b 
LEFT JOIN edition e ON b.bookid = e.bookid
LEFT JOIN total_sales 
ON e.isbn = total_sales.isbn
WHERE itemid IS NULL
;

--Method 2: calculate sales quantity for each book at different price & discount levels, them times with price
-- sum (quantity * final price)
WITH sales AS (
    SELECT * FROM sales_q1
    UNION ALL 
    SELECT * FROM sales_q2
    UNION ALL 
    SELECT * FROM sales_q3
    UNION ALL 
    SELECT * FROM sales_q4
),
sales_with_price AS (
    SELECT b.bookid
    , b.title
    , e.price
    , e.price * (1- COALESCE(s.discount,0)) AS final_price
    , COUNT(s.itemid) AS quantity --quantity of books sold at different levels of price and discount
    FROM books b 
    LEFT JOIN edition e 
    ON e.bookid = b.bookid 
    INNER JOIN sales s
    ON s.isbn = e.isbn 
    GROUP BY b.bookid, b.title, e.price, final_price
)
SELECT bookid 
, title 
, SUM(quantity * final_price) AS sales_amount 
FROM sales_with_price 
GROUP BY bookid, title 
ORDER BY sales_amount DESC 
;

-- 7. What's the return on investment for each Publishing House?  
-- ROI = Total Sales / Marketing Spend
WITH total_sales AS (
    SELECT * FROM sales_q1
    UNION ALL
    SELECT * FROM sales_q2
    UNION ALL
    SELECT * FROM sales_q3
    UNION ALL 
    SELECT * FROM sales_q4
)
SELECT 
  p.publishing_house
, p.pubid
, p.marketing_spend
, SUM(e.price * (1 - COALESCE(total_sales.discount,0))) AS sum_sales -- to get the final correct price, then SUM them up as total_sales
, sum_sales / p.marketing_spend AS ROI --not SUM(marketing_spend) as that will inflate the marketing_spend numbers
FROM publisher p 
LEFT JOIN edition e 
    ON p.pubid = e.pubid
INNER JOIN total_sales --inner join to keep only the editions that have actually made sales
    ON e.isbn = total_sales.isbn
GROUP BY 1,2,3
ORDER BY ROI DESC
; 
