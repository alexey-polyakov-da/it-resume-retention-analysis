
-- =========================================================
-- Проект: Анализ Retention платформы IT Resume
-- Файл: 04_early_learning_activity.sql
-- СУБД: PostgreSQL
-- =========================================================


-- ЗАПРОС 1. УЧЕБНАЯ АКТИВНОСТЬ ПО ДНЯМ
--
-- Цель:
-- Рассчитать количество пользователей с учебными
-- событиями в каждом из первых семи 24-часовых
-- интервалов после регистрации.
--
-- D0 = первые 24 часа, D1 = следующие 24 часа и т.д.
-- Один пользователь может присутствовать
-- сразу в нескольких днях.

WITH learning_events AS (
    SELECT user_id, created_at FROM public.coderun
    UNION ALL
    SELECT user_id, created_at FROM public.codesubmit
    UNION ALL
    SELECT user_id, created_at FROM public.teststart
    UNION ALL
    SELECT user_id, created_at FROM public.testresult
),

cohort AS (
    SELECT id, date_joined
    FROM public.users
    WHERE date_joined >= DATE '2021-11-01'
      AND date_joined < DATE '2022-03-26'
),

user_activity AS (
    SELECT DISTINCT
        c.id AS user_id,
        FLOOR(
            EXTRACT(EPOCH FROM (l.created_at - c.date_joined))
            / 86400
        )::integer AS day_number
    FROM cohort AS c
    JOIN learning_events AS l
        ON l.user_id = c.id
       AND l.created_at >= c.date_joined
       AND l.created_at < c.date_joined + INTERVAL '7 days'
)

SELECT
    day_number,
    COUNT(*) AS active_users,
    ROUND(
        100.0 * COUNT(*)
        / (SELECT COUNT(*) FROM cohort),
        2
    ) AS share_pct
FROM user_activity
GROUP BY day_number
ORDER BY day_number;


-- ЗАПРОС 2. ПОВТОРНОЕ ОБУЧЕНИЕ ПОСЛЕ D0
--
-- Цель:
-- Разделить пользователей, учившихся в D0,
-- на три непересекающиеся группы:
--
-- 1. Обучались также в D1.
-- 2. Пропустили D1, но вернулись в D2-D6.
-- 3. Не повторяли обучение в D1-D6.
--
-- Затем рассчитать Retention D30-D59
-- для каждой группы.

WITH learning AS (
    SELECT user_id, created_at FROM public.coderun
    UNION ALL
    SELECT user_id, created_at FROM public.codesubmit
    UNION ALL
    SELECT user_id, created_at FROM public.teststart
    UNION ALL
    SELECT user_id, created_at FROM public.testresult
),

events AS (
    SELECT user_id, entry_at AS ts FROM public.userentry
    UNION ALL
    SELECT user_id, created_at FROM learning
),

cohort AS (
    SELECT id, date_joined
    FROM public.users
    WHERE date_joined >= DATE '2021-11-01'
      AND date_joined < DATE '2022-03-26'
),

flags AS (
    SELECT
        c.id,
        c.date_joined,

        EXISTS (
            SELECT 1
            FROM learning AS l
            WHERE l.user_id = c.id
              AND l.created_at >= c.date_joined
              AND l.created_at < c.date_joined
                  + INTERVAL '1 day'
        ) AS d0,

        EXISTS (
            SELECT 1
            FROM learning AS l
            WHERE l.user_id = c.id
              AND l.created_at >= c.date_joined
                  + INTERVAL '1 day'
              AND l.created_at < c.date_joined
                  + INTERVAL '2 days'
        ) AS d1,

        EXISTS (
            SELECT 1
            FROM learning AS l
            WHERE l.user_id = c.id
              AND l.created_at >= c.date_joined
                  + INTERVAL '2 days'
              AND l.created_at < c.date_joined
                  + INTERVAL '7 days'
        ) AS d2_d6,

        EXISTS (
            SELECT 1
            FROM events AS e
            WHERE e.user_id = c.id
              AND e.ts >= c.date_joined
                  + INTERVAL '30 days'
              AND e.ts < c.date_joined
                  + INTERVAL '60 days'
        ) AS retained

    FROM cohort AS c
)

SELECT
    CASE
        WHEN d1 THEN 'D1'
        WHEN d2_d6 THEN 'D2-D6 после пропуска D1'
        ELSE 'Нет повторного обучения'
    END AS segment,

    COUNT(*) AS users_count,

    COUNT(*) FILTER (
        WHERE retained
    ) AS retained_users,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE retained)
        / NULLIF(COUNT(*), 0),
        2
    ) AS retention_pct

FROM flags
WHERE d0
GROUP BY 1
ORDER BY 1;
