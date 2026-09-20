USE bingeplay;

-- Calculate Active Subscriptions & MRR
SELECT 
    COUNT(*) AS active_subscriptions_count,
    SUM(monthly_price_inr) AS total_monthly_revenue_inr
FROM subscriptions
WHERE status = 'active'
  AND (end_date IS NULL OR end_date > '2024-06-30');
  
  -- Find Peak Signup Month
  SELECT 
    MONTH(signup_date) AS month,
    MONTHNAME(signup_date) AS month_name,
    COUNT(user_id) AS signup_count
FROM users
WHERE YEAR(signup_date) = 2024
GROUP BY MONTH(signup_date), MONTHNAME(signup_date)
ORDER BY signup_count DESC
LIMIT 1;

-- Analyze Device Usage
SELECT 
    device_type,
    COUNT(session_id) AS total_sessions,
    SUM(watch_minutes) AS total_watch_minutes,
    ROUND(AVG(watch_minutes), 2) AS avg_watch_minutes_per_session,
    ROUND(SUM(completed) * 100.0 / COUNT(session_id), 2) AS completion_rate_pct
FROM watch_sessions
WHERE user_id IS NOT NULL
GROUP BY device_type
ORDER BY device_type;

-- Evaluate Rating Distribution
SELECT 
    stars,
    COUNT(rating_id) AS rating_count,
    ROUND(COUNT(rating_id) * 100.0 / (SELECT COUNT(*) FROM ratings), 2) AS percentage
FROM ratings
GROUP BY stars
ORDER BY stars;

-- Compare Originals vs. Acquired Content
SELECT 
    CASE WHEN is_original = 1 THEN 'BingePlay Originals' ELSE 'Acquired Content' END AS group_type,
    COUNT(show_id) AS number_of_shows,
    ROUND(AVG(imdb_rating), 2) AS avg_imdb_rating,
    ROUND(AVG(release_year), 2) AS avg_release_year
FROM shows
GROUP BY is_original;

-- Detect Binge Days in Q2 2024
WITH binge_days AS (
    SELECT 
        user_id,
        show_id,
        session_date,
        COUNT(session_id) AS session_count
    FROM watch_sessions
    WHERE session_date BETWEEN '2024-04-01' AND '2024-06-30'
      AND user_id IS NOT NULL
    GROUP BY user_id, show_id, session_date
    HAVING COUNT(session_id) >= 5
)
SELECT 
    (SELECT COUNT(*) FROM binge_days) AS total_binge_days,
    user_id AS top_user_id,
    COUNT(*) AS user_binge_days
FROM binge_days
GROUP BY user_id
ORDER BY user_binge_days DESC
LIMIT 1;

-- Identify Inactive Q1 Signups (Zero Watch Sessions)
SELECT 
    COUNT(u.user_id) AS total_q1_signups,
    SUM(CASE WHEN NOT EXISTS (
        SELECT 1 FROM watch_sessions ws WHERE ws.user_id = u.user_id
    ) THEN 1 ELSE 0 END) AS never_watched_count
FROM users u
WHERE u.signup_date BETWEEN '2024-01-01' AND '2024-03-31';

-- Identify Overpaying Users (Premium/Family Plan watching Basic Content)
WITH current_subs AS (
    SELECT user_id, plan
    FROM (
        SELECT user_id, plan,
               ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY start_date DESC) AS rn
        FROM subscriptions
        WHERE status = 'active'
          AND (end_date IS NULL OR end_date > '2024-06-30')
    ) t
    WHERE rn = 1
)
SELECT COUNT(cs.user_id) AS overpaying_users_count
FROM current_subs cs
WHERE cs.plan IN ('Premium', 'Family')
  AND EXISTS (
      SELECT 1 FROM watch_sessions ws WHERE ws.user_id = cs.user_id
  )
  AND NOT EXISTS (
      SELECT 1 
      FROM watch_sessions ws
      JOIN shows s ON ws.show_id = s.show_id
      WHERE ws.user_id = cs.user_id
        AND s.min_plan IN ('Premium', 'Family')
  );
  
  -- Track January Signup Upgrades
  WITH user_orders AS (
    SELECT 
        s.user_id,
        u.signup_date,
        s.plan,
        s.start_date,
        ROW_NUMBER() OVER (PARTITION BY s.user_id ORDER BY s.start_date ASC) AS sub_order
    FROM subscriptions s
    JOIN users u ON s.user_id = u.user_id
    WHERE u.signup_date BETWEEN '2024-01-01' AND '2024-01-31'
),
first_subs AS (
    SELECT user_id, signup_date, plan AS initial_plan
    FROM user_orders
    WHERE sub_order = 1 AND plan = 'Basic'
),
upgrades AS (
    SELECT 
        fs.user_id,
        fs.signup_date,
        MIN(uo.start_date) AS first_upgrade_date
    FROM first_subs fs
    JOIN user_orders uo ON fs.user_id = uo.user_id
    WHERE uo.plan IN ('Premium', 'Family') AND uo.sub_order > 1
    GROUP BY fs.user_id, fs.signup_date
),
active_as_of_june AS (
    SELECT DISTINCT user_id
    FROM subscriptions
    WHERE status = 'active'
      AND (end_date IS NULL OR end_date > '2024-06-30')
)
SELECT 
    COUNT(up.user_id) AS upgraded_active_users_count,
    ROUND(AVG(DATEDIFF(up.first_upgrade_date, up.signup_date)), 2) AS avg_days_to_first_upgrade
FROM upgrades up
JOIN active_as_of_june a ON up.user_id = a.user_id;

-- Track Cliffhanger Comebacks (1-7 Day Re-engagement)
WITH comebacks AS (
    SELECT DISTINCT
        ws1.user_id,
        ws1.show_id,
        ws1.session_date AS incomplete_date
    FROM watch_sessions ws1
    JOIN watch_sessions ws2 
      ON ws1.user_id = ws2.user_id 
     AND ws1.show_id = ws2.show_id
    WHERE ws1.completed = 0
      AND ws2.session_date BETWEEN DATE_ADD(ws1.session_date, INTERVAL 1 DAY) 
                               AND DATE_ADD(ws1.session_date, INTERVAL 7 DAY)
)
SELECT 
    (SELECT COUNT(*) FROM comebacks) AS total_cliffhanger_comeback_events,
    c.show_id AS top_show_id,
    s.title AS show_title,
    COUNT(*) AS comeback_count
FROM comebacks c
JOIN shows s ON c.show_id = s.show_id
GROUP BY c.show_id, s.title
ORDER BY comeback_count DESC
LIMIT 1;

-- Calculate Weekly Streaks (Gaps and Islands)
WITH user_weeks AS (
    SELECT DISTINCT 
        user_id,
        YEAR(session_date) AS yr,
        WEEK(session_date, 3) AS week_num,
        (YEAR(session_date) * 52 + WEEK(session_date, 3)) AS week_seq
    FROM watch_sessions
    WHERE user_id IS NOT NULL
),
streaks AS (
    SELECT 
        user_id,
        week_seq,
        week_seq - ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY week_seq) AS island_id
    FROM user_weeks
),
streak_lengths AS (
    SELECT 
        user_id,
        COUNT(*) AS streak_weeks
    FROM streaks
    GROUP BY user_id, island_id
)
SELECT 
    COUNT(DISTINCT CASE WHEN streak_weeks >= 4 THEN user_id END) AS users_with_4plus_week_streak,
    MAX(streak_weeks) AS longest_streak_weeks
FROM streak_lengths;

-- Detect Churn Signals (50%+ Drop May to June)
WITH monthly_watch AS (
    SELECT 
        user_id,
        SUM(CASE WHEN MONTH(session_date) = 5 THEN watch_minutes ELSE 0 END) AS may_mins,
        SUM(CASE WHEN MONTH(session_date) = 6 THEN watch_minutes ELSE 0 END) AS june_mins
    FROM watch_sessions
    WHERE user_id IS NOT NULL
      AND session_date BETWEEN '2024-05-01' AND '2024-06-30'
    GROUP BY user_id
)
SELECT 
    mw.user_id,
    u.name,
    mw.may_mins AS may_watch_minutes,
    mw.june_mins AS june_watch_minutes,
    ROUND((mw.may_mins - mw.june_mins) * 100.0 / mw.may_mins, 2) AS drop_percentage
FROM monthly_watch mw
JOIN users u ON mw.user_id = u.user_id
WHERE mw.may_mins > 0
  AND (mw.may_mins - mw.june_mins) * 1.0 / mw.may_mins >= 0.50
ORDER BY drop_percentage DESC;