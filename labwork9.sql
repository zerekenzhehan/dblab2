DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT oid::regprocedure AS sig
        FROM pg_proc
        WHERE pronamespace = 'public'::regnamespace
          AND proname IN ('inc', 'rental_days', 'member_rental_count',
                          'station_city', 'fee_with_discount', 'member_stats',
                          'apply_late_fee', 'fee_summary', 'total_fees',
                          'find_bikes', 'member_history', 'bike_list',
                          'station_board', 'fee_split', 'station_load',
                          'top_members', 'rental_invoice', 'city_report')
    LOOP
        EXECUTE 'DROP FUNCTION ' || r.sig;
    END LOOP;
END; $$;

-- Exercise 2.1
CREATE OR REPLACE FUNCTION rental_days(p_rental_id INT) RETURNS INT AS $$
DECLARE
    d INT;
BEGIN
    SELECT end_date - start_date INTO d
    FROM rentals
    WHERE rental_id = p_rental_id;
    RETURN d;
END; $$
LANGUAGE plpgsql;

SELECT rental_days(2);
SELECT rental_days(11);
SELECT rental_days(19);
SELECT rental_days(999);

-- Exercise 2.2
CREATE OR REPLACE FUNCTION member_rental_count(p_member_id INT) RETURNS INT AS $$
DECLARE
    n INT;
BEGIN
    SELECT COUNT(*) INTO n
    FROM rentals
    WHERE member_id = p_member_id;
    RETURN n;
END; $$
LANGUAGE plpgsql;

SELECT member_rental_count(1);
SELECT member_rental_count(5);
SELECT member_rental_count(6);
SELECT member_rental_count(99);

-- Exercise 2.3
CREATE OR REPLACE FUNCTION station_city(p_station_id INT) RETURNS VARCHAR AS $$
DECLARE
    c VARCHAR;
BEGIN
    SELECT city INTO c
    FROM stations
    WHERE station_id = p_station_id;
    RETURN c;
END; $$
LANGUAGE plpgsql;

SELECT station_city(30);
SELECT station_city(77);

-- Exercise 2.4
SELECT rental_id, member_id, rental_days(rental_id) AS days
FROM rentals
WHERE rental_days(rental_id) > 4
ORDER BY days DESC, rental_id;

-- Exercise 3.1
CREATE OR REPLACE FUNCTION fee_with_discount(p_fee NUMERIC, p_percent NUMERIC)
RETURNS NUMERIC AS $$
BEGIN
    RETURN ROUND(p_fee * (1 - p_percent / 100), 2);
END; $$
LANGUAGE plpgsql;

SELECT fee_with_discount(74.00, 15);

-- Exercise 3.2
CREATE OR REPLACE FUNCTION member_stats(
    p_member_id INT,
    OUT rental_cnt INT,
    OUT total_fee NUMERIC,
    OUT last_start DATE)
AS $$
BEGIN
    SELECT COUNT(*), COALESCE(SUM(fee), 0), MAX(start_date)
    INTO rental_cnt, total_fee, last_start
    FROM rentals
    WHERE member_id = p_member_id;
END; $$
LANGUAGE plpgsql;

SELECT member_stats(3);
SELECT * FROM member_stats(3);
SELECT * FROM member_stats(6);

-- Exercise 3.3
CREATE OR REPLACE FUNCTION apply_late_fee(INOUT p_fee NUMERIC) AS $$
BEGIN
    p_fee := p_fee + 5.00;
END; $$
LANGUAGE plpgsql;

SELECT apply_late_fee(fee) FROM rentals WHERE rental_id = 1;

-- Exercise 3.4
CREATE OR REPLACE FUNCTION fee_summary(
    VARIADIC p_fees NUMERIC[],
    OUT total NUMERIC,
    OUT average NUMERIC,
    OUT largest NUMERIC)
AS $$
BEGIN
    SELECT SUM(p_fees[i]), ROUND(AVG(p_fees[i]), 2), MAX(p_fees[i])
    INTO total, average, largest
    FROM generate_subscripts(p_fees, 1) g(i);
END; $$
LANGUAGE plpgsql;

SELECT * FROM fee_summary(13.50, 35.00, 18.50, 31.50);

DO $$
DECLARE
    v_hint TEXT;
BEGIN
    PERFORM * FROM fee_summary();
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    RAISE NOTICE 'ERROR:  %', SQLERRM;
    RAISE NOTICE 'HINT:  %', v_hint;
END; $$;

-- Exercise 4.1
CREATE OR REPLACE FUNCTION total_fees(p_member_id INT) RETURNS NUMERIC AS $$
DECLARE
    t NUMERIC;
BEGIN
    SELECT COALESCE(SUM(fee), 0) INTO t
    FROM rentals
    WHERE member_id = p_member_id;
    RETURN t;
END; $$
LANGUAGE plpgsql;

SELECT total_fees(1);
SELECT total_fees(6);

-- Exercise 4.2
CREATE OR REPLACE FUNCTION total_fees(p_member_id INT, p_from_date DATE)
RETURNS NUMERIC AS $$
DECLARE
    t NUMERIC;
BEGIN
    SELECT COALESCE(SUM(fee), 0) INTO t
    FROM rentals
    WHERE member_id = p_member_id
      AND start_date >= p_from_date;
    RETURN t;
END; $$
LANGUAGE plpgsql;

SELECT total_fees(1, DATE '2024-01-01');
SELECT total_fees(1, DATE '2025-01-01');

SELECT oid::regprocedure AS signature
FROM pg_proc
WHERE proname = 'total_fees'
ORDER BY 1::text;

-- Exercise 4.3
CREATE OR REPLACE FUNCTION total_fees(p_member_id INT,
                                      p_from_date DATE DEFAULT DATE '2025-01-01')
RETURNS NUMERIC AS $$
DECLARE
    t NUMERIC;
BEGIN
    SELECT COALESCE(SUM(fee), 0) INTO t
    FROM rentals
    WHERE member_id = p_member_id
      AND start_date >= p_from_date;
    RETURN t;
END; $$
LANGUAGE plpgsql;

DO $$
DECLARE
    v_hint TEXT;
BEGIN
    PERFORM total_fees(1);
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    RAISE NOTICE 'ERROR:  %', SQLERRM;
    RAISE NOTICE 'HINT:  %', v_hint;
END; $$;

-- Exercise 4.4
DROP FUNCTION total_fees(INTEGER);

SELECT total_fees(1);

-- Exercise 4.5
CREATE OR REPLACE FUNCTION total_fees(p_member_name VARCHAR) RETURNS NUMERIC AS $$
DECLARE
    t NUMERIC;
BEGIN
    SELECT COALESCE(SUM(r.fee), 0) INTO t
    FROM rentals r
    JOIN members m ON m.member_id = r.member_id
    WHERE m.full_name = p_member_name;
    RETURN t;
END; $$
LANGUAGE plpgsql;

SELECT total_fees('Aisha Nurlanova');
SELECT total_fees(1);

-- Exercise 5.1
CREATE OR REPLACE FUNCTION find_bikes(p_pattern VARCHAR)
RETURNS TABLE (found_id INT, found_model VARCHAR, found_rate NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT b.bike_id, b.model, b.daily_rate
    FROM bikes b
    WHERE b.model ILIKE p_pattern
    ORDER BY b.bike_id;
END; $$
LANGUAGE plpgsql;

SELECT * FROM find_bikes('%road%');
SELECT * FROM find_bikes('%Mini');
SELECT find_bikes('%road%');

-- Exercise 5.2
CREATE OR REPLACE FUNCTION member_history(p_member_id INT)
RETURNS TABLE (h_rental_id INT, h_model VARCHAR, h_station VARCHAR,
               h_days INT, h_fee NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT r.rental_id, b.model, s.station_name,
           (r.end_date - r.start_date), r.fee
    FROM rentals r
    JOIN bikes b    ON b.bike_id = r.bike_id
    JOIN stations s ON s.station_id = b.station_id
    WHERE r.member_id = p_member_id
    ORDER BY r.start_date;
END; $$
LANGUAGE plpgsql;

SELECT * FROM member_history(3);

-- Exercise 5.3
CREATE OR REPLACE FUNCTION bike_list(p_station_id INT)
RETURNS TABLE (bike_id INT, model VARCHAR) AS $$
BEGIN
    RETURN QUERY SELECT bike_id, model FROM bikes WHERE station_id = p_station_id;
END; $$ LANGUAGE plpgsql;

DO $$
DECLARE
    v_detail TEXT;
    v_hint   TEXT;
BEGIN
    PERFORM * FROM bike_list(10);
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_detail = PG_EXCEPTION_DETAIL,
                            v_hint   = PG_EXCEPTION_HINT;
    RAISE NOTICE 'ERROR:  %', SQLERRM;
    RAISE NOTICE 'DETAIL:  %', v_detail;
    RAISE NOTICE 'HINT:  %', v_hint;
END; $$;

DROP FUNCTION bike_list(INT);

CREATE FUNCTION bike_list(p_station_id INT)
RETURNS TABLE (out_bike_id INT, out_model VARCHAR) AS $$
BEGIN
    RETURN QUERY SELECT bike_id, model FROM bikes WHERE station_id = p_station_id;
END; $$ LANGUAGE plpgsql;

SELECT * FROM bike_list(10);

DROP FUNCTION bike_list(INT);

CREATE FUNCTION bike_list(p_station_id INT)
RETURNS TABLE (bike_id INT, model VARCHAR) AS $$
BEGIN
    RETURN QUERY SELECT b.bike_id, b.model FROM bikes b WHERE b.station_id = p_station_id;
END; $$ LANGUAGE plpgsql;

SELECT * FROM bike_list(10);

-- Exercise 5.4
CREATE OR REPLACE FUNCTION station_board(p_city VARCHAR)
RETURNS TABLE (s_name VARCHAR, s_bikes INT, s_free INT) AS $$
BEGIN
    RETURN QUERY
    SELECT st.station_name, COUNT(b.bike_id), st.capacity - COUNT(b.bike_id)
    FROM stations st
    LEFT JOIN bikes b ON b.station_id = st.station_id
    WHERE st.city = p_city
    GROUP BY st.station_id, st.station_name, st.capacity
    ORDER BY st.station_id;
END; $$
LANGUAGE plpgsql;

DO $$
DECLARE
    v_detail TEXT;
BEGIN
    PERFORM * FROM station_board('Almaty');
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_detail = PG_EXCEPTION_DETAIL;
    RAISE NOTICE 'ERROR:  %', SQLERRM;
    RAISE NOTICE 'DETAIL:  %', v_detail;
END; $$;

CREATE OR REPLACE FUNCTION station_board(p_city VARCHAR)
RETURNS TABLE (s_name VARCHAR, s_bikes INT, s_free INT) AS $$
BEGIN
    RETURN QUERY
    SELECT st.station_name,
           COUNT(b.bike_id)::INT,
           (st.capacity - COUNT(b.bike_id))::INT
    FROM stations st
    LEFT JOIN bikes b ON b.station_id = st.station_id
    WHERE st.city = p_city
    GROUP BY st.station_id, st.station_name, st.capacity
    ORDER BY st.station_id;
END; $$
LANGUAGE plpgsql;

SELECT * FROM station_board('Almaty');
SELECT * FROM station_board('Astana');

-- Exercise 6.1
DO $$
<<rental_report>>
DECLARE
    total_rentals INTEGER := 0;
BEGIN
    SELECT COUNT(*) INTO total_rentals FROM rentals;
    RAISE NOTICE 'The rentals table holds % rows.', total_rentals;
END rental_report $$;

DO $outer$
BEGIN
    EXECUTE $inner$
        DO $$
        <<rental_report>>
        BEGIN
            NULL;
        END wrong_label $$
    $inner$;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'ERROR:  %', SQLERRM;
END; $outer$;

-- Exercise 6.2
DO $$
<<rental_report>>
DECLARE
    total_rentals INTEGER := 0;
    fee_total NUMERIC;
BEGIN
    SELECT COUNT(*) INTO total_rentals FROM rentals;
    SELECT SUM(fee) INTO fee_total FROM rentals;
    RAISE NOTICE 'Outer fee_total before subblock: %', fee_total;

    DECLARE
        fee_total NUMERIC;
    BEGIN
        SELECT SUM(fee) INTO fee_total
        FROM rentals
        WHERE start_date >= DATE '2025-01-01';
        RAISE NOTICE 'Subblock fee_total (own variable): %', fee_total;
        RAISE NOTICE 'Outer fee_total reached via label: %', rental_report.fee_total;
    END;

    RAISE NOTICE 'Outer fee_total after subblock: %', fee_total;
END rental_report $$;

-- Exercise 6.3
DO $outer$
BEGIN
    EXECUTE $inner$
        DO $$
        BEGIN
            DECLARE
                first_val NUMERIC;
            BEGIN
                SELECT SUM(fee) INTO first_val FROM rentals;
            END;

            BEGIN
                RAISE NOTICE 'Second subblock sees: %', first_val;
            END;
        END $$
    $inner$;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'ERROR:  %', SQLERRM;
END; $outer$;

DO $$
DECLARE
    shared_val NUMERIC;
BEGIN
    BEGIN
        SELECT SUM(fee) INTO shared_val FROM rentals;
        RAISE NOTICE 'First subblock set it to: %', shared_val;
    END;

    BEGIN
        RAISE NOTICE 'Second subblock sees: %', shared_val;
    END;
END $$;

-- Exercise 6.4
CREATE OR REPLACE FUNCTION fee_split(
    p_from_date DATE,
    OUT before_total NUMERIC,
    OUT after_total NUMERIC)
AS $$
BEGIN
    SELECT COALESCE(SUM(fee) FILTER (WHERE start_date <  p_from_date), 0),
           COALESCE(SUM(fee) FILTER (WHERE start_date >= p_from_date), 0)
    INTO before_total, after_total
    FROM rentals;
END; $$
LANGUAGE plpgsql;

SELECT * FROM fee_split(DATE '2025-01-01');

SELECT before_total + after_total AS split_sum,
       (SELECT SUM(fee) FROM rentals) AS table_total,
       before_total + after_total = (SELECT SUM(fee) FROM rentals) AS ok
FROM fee_split(DATE '2025-01-01');

-- Exercise 7.1
CREATE OR REPLACE FUNCTION station_load(
    p_station_id INT,
    OUT bikes_parked INT,
    OUT capacity_pct NUMERIC)
AS $$
DECLARE
    cap INT;
BEGIN
    SELECT COUNT(*) INTO bikes_parked
    FROM bikes
    WHERE station_id = p_station_id;

    SELECT capacity INTO cap
    FROM stations
    WHERE station_id = p_station_id;

    capacity_pct := ROUND(100.0 * bikes_parked / NULLIF(cap, 0), 1);
END; $$
LANGUAGE plpgsql;

SELECT s.station_id, s.station_name, l.*
FROM stations s, LATERAL station_load(s.station_id) l
ORDER BY s.station_id;

-- Exercise 7.2
CREATE OR REPLACE FUNCTION top_members(p_limit INT DEFAULT 3)
RETURNS TABLE (t_name VARCHAR, t_rentals INT, t_spent NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT m.full_name,
           COUNT(r.rental_id)::INT,
           COALESCE(SUM(r.fee), 0)
    FROM members m
    LEFT JOIN rentals r ON r.member_id = m.member_id
    GROUP BY m.member_id, m.full_name
    ORDER BY COALESCE(SUM(r.fee), 0) DESC, m.member_id
    LIMIT p_limit;
END; $$
LANGUAGE plpgsql;

SELECT * FROM top_members();
SELECT * FROM top_members(6);

-- Exercise 7.3
CREATE OR REPLACE FUNCTION rental_invoice(p_rental_id INT)
RETURNS TABLE (inv_member VARCHAR, inv_model VARCHAR, inv_days INT,
               inv_amount NUMERIC, inv_status VARCHAR) AS $$
BEGIN
    RETURN QUERY
    SELECT m.full_name,
           b.model,
           (COALESCE(r.end_date, CURRENT_DATE) - r.start_date)::INT,
           ROUND((COALESCE(r.end_date, CURRENT_DATE) - r.start_date) * b.daily_rate, 2),
           (CASE WHEN r.end_date IS NULL THEN 'OPEN' ELSE 'CLOSED' END)::VARCHAR
    FROM rentals r
    JOIN members m ON m.member_id = r.member_id
    JOIN bikes b   ON b.bike_id = r.bike_id
    WHERE r.rental_id = p_rental_id;
END; $$
LANGUAGE plpgsql STABLE;

SELECT * FROM rental_invoice(11);
SELECT * FROM rental_invoice(19);

-- Exercise 7.4
CREATE OR REPLACE FUNCTION city_report(p_city VARCHAR)
RETURNS TABLE (c_members INT, c_rentals INT, c_revenue NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT COUNT(DISTINCT m.member_id)::INT,
           COUNT(r.rental_id)::INT,
           COALESCE(SUM(r.fee), 0)
    FROM members m
    LEFT JOIN rentals r ON r.member_id = m.member_id
    WHERE m.city = p_city;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION city_report(p_city VARCHAR, p_from_date DATE)
RETURNS TABLE (c_members INT, c_rentals INT, c_revenue NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT COUNT(DISTINCT m.member_id)::INT,
           COUNT(r.rental_id)::INT,
           COALESCE(SUM(r.fee), 0)
    FROM members m
    LEFT JOIN rentals r ON r.member_id = m.member_id
                       AND r.start_date >= p_from_date
    WHERE m.city = p_city;
END; $$
LANGUAGE plpgsql;

SELECT * FROM city_report('Almaty');
SELECT * FROM city_report('Almaty', DATE '2025-01-01');

SELECT COUNT(DISTINCT m.member_id) AS members_with_on
FROM members m
LEFT JOIN rentals r ON r.member_id = m.member_id
                   AND r.start_date >= DATE '2025-01-01'
WHERE m.city = 'Almaty';

SELECT COUNT(DISTINCT m.member_id) AS members_with_where
FROM members m
LEFT JOIN rentals r ON r.member_id = m.member_id
WHERE m.city = 'Almaty'
  AND r.start_date >= DATE '2025-01-01';